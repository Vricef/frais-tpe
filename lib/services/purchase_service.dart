import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement.dart';

/// Identifiants du produit « déblocage complet », côté boutiques.
///
/// Ils diffèrent d'une plateforme à l'autre : App Store Connect impose un
/// identifiant unique à l'échelle de la boutique, d'où le préfixe inverse
/// du bundle ; Play Console le porte déjà par l'application.
class IdentifiantsProduit {
  const IdentifiantsProduit._();

  static const ios = 'com.fraistpe.app.unlock_full';
  static const android = 'unlock_full';

  /// L'identifiant de la plateforme courante.
  ///
  /// Hors iOS et Android il n'y a pas de boutique : le service se
  /// déclarera indisponible avant d'utiliser cette valeur.
  static String get courant => Platform.isIOS ? ios : android;
}

/// Ce que l'app attend d'une boutique.
///
/// `in_app_purchase` ne s'exécute que sur un appareil relié à une
/// boutique réelle. Passer par cette interface permet d'éprouver toute la
/// mécanique — succès, annulation, panne réseau, produit absent — sans
/// laquelle ces chemins ne se testeraient qu'à la main, sur un compte de
/// test, une fois l'app publiée.
abstract class Boutique {
  Future<bool> estDisponible();
  Stream<List<PurchaseDetails>> get flux;
  Future<ProductDetailsResponse> produits(Set<String> identifiants);
  Future<void> acheter(PurchaseParam parametres);
  Future<void> restaurer();
  Future<void> finaliser(PurchaseDetails achat);
}

/// La vraie boutique de la plateforme.
class BoutiquePlateforme implements Boutique {
  BoutiquePlateforme([InAppPurchase? instance])
      : _iap = instance ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> estDisponible() => _iap.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get flux => _iap.purchaseStream;

  @override
  Future<ProductDetailsResponse> produits(Set<String> identifiants) =>
      _iap.queryProductDetails(identifiants);

  @override
  Future<void> acheter(PurchaseParam parametres) =>
      // Non consommable : le déblocage s'achète une fois et pour de bon.
      _iap.buyNonConsumable(purchaseParam: parametres);

  @override
  Future<void> restaurer() => _iap.restorePurchases();

  @override
  Future<void> finaliser(PurchaseDetails achat) => _iap.completePurchase(achat);
}

/// Ce que l'écran de paiement doit montrer à l'instant t.
enum EtatAchat {
  /// Interrogation de la boutique en cours.
  chargement,

  /// Produit connu, prix affichable, achat possible.
  pret,

  /// Achat ou restauration en cours : la boutique a la main.
  enCours,

  /// Rien à vendre ici : boutique injoignable, ou produit non publié.
  indisponible,
}

/// Branche l'achat unique des boutiques sur [Entitlement].
///
/// Le service ne décide de rien : il traduit ce que dit la boutique, et
/// le seul effet durable — le déblocage — passe par [Entitlement].
class PurchaseService extends ChangeNotifier {
  PurchaseService({
    required this.entitlement,
    Boutique? boutique,
    this.delaiRestauration = const Duration(seconds: 10),
  }) : _boutique = boutique ?? BoutiquePlateforme();

  final Entitlement entitlement;
  final Boutique _boutique;

  StreamSubscription<List<PurchaseDetails>>? _abonnement;
  ProductDetails? _produit;
  EtatAchat _etat = EtatAchat.chargement;
  String? _erreur;

  EtatAchat get etat => _etat;
  ProductDetails? get produit => _produit;

  /// Dernier échec à montrer à l'utilisateur, effacé par [oublierErreur].
  /// Une annulation n'en produit pas : elle est déjà comprise.
  String? get erreur => _erreur;

  /// Prix formaté par la boutique, dans la devise et la langue du compte.
  /// Le prix affiché doit venir de là : un montant codé en dur devient
  /// faux dès qu'un pays ou une taxe change.
  String? get prix => _produit?.price;

  bool get peutAcheter => _etat == EtatAchat.pret && !entitlement.estDebloque;

  /// À appeler une fois au démarrage.
  ///
  /// L'écoute du flux est posée avant toute requête : un achat interrompu
  /// à la session précédente — paiement validé pendant que l'app était
  /// fermée — est rejoué par la boutique dès l'abonnement, et serait
  /// perdu si on l'écoutait plus tard.
  Future<void> demarrer() async {
    _abonnement ??= _boutique.flux.listen(
      _traiter,
      onError: (Object e) {
        debugPrint('Flux d\'achats en erreur : $e');
        _erreur = "La boutique a interrompu l'opération.";
        notifyListeners();
      },
    );

    bool disponible;
    try {
      disponible = await _boutique.estDisponible();
    } catch (e) {
      debugPrint('Boutique injoignable : $e');
      disponible = false;
    }
    if (!disponible) {
      _passerA(EtatAchat.indisponible);
      return;
    }

    try {
      final reponse = await _boutique.produits({IdentifiantsProduit.courant});
      _produit = reponse.productDetails.isEmpty ? null : reponse.productDetails.first;
      // Produit introuvable : il n'est pas encore publié, ou l'identifiant
      // ne correspond pas. Mieux vaut masquer l'achat que proposer un
      // bouton qui échouera.
      _passerA(_produit == null ? EtatAchat.indisponible : EtatAchat.pret);
    } catch (e) {
      debugPrint('Produit non récupéré : $e');
      _passerA(EtatAchat.indisponible);
    }
  }

  Future<void> acheter() async {
    final produit = _produit;
    if (produit == null || _etat == EtatAchat.enCours) return;
    _erreur = null;
    _passerA(EtatAchat.enCours);
    try {
      await _boutique.acheter(PurchaseParam(productDetails: produit));
    } catch (e) {
      debugPrint('Achat refusé : $e');
      _erreur = "Le paiement n'a pas pu être lancé. Réessayez.";
      _passerA(EtatAchat.pret);
    }
  }

  /// Combien de temps attendre la réponse de la boutique à une
  /// restauration. Elle passe par le flux, pas par la valeur de retour.
  /// Réglable pour que les tests n'attendent pas dix secondes.
  final Duration delaiRestauration;

  Completer<void>? _restauration;

  /// Obligatoire sur iOS, et utile partout : un changement d'appareil ne
  /// doit pas faire repayer un achat définitif.
  Future<void> restaurer() async {
    if (_etat == EtatAchat.enCours) return;
    _erreur = null;
    final precedent = _etat;
    _passerA(EtatAchat.enCours);
    try {
      // `restorePurchases()` rend la main tout de suite ; les achats
      // arrivent ensuite par le flux. Conclure à son retour annonçait
      // « aucun achat » une fraction de seconde avant de débloquer.
      final attente = _restauration = Completer<void>();
      await _boutique.restaurer();
      await attente.future.timeout(delaiRestauration, onTimeout: () {});
      if (!entitlement.estDebloque) {
        _erreur = 'Aucun achat à restaurer sur ce compte.';
      }
    } catch (e) {
      debugPrint('Restauration impossible : $e');
      _erreur = 'La restauration a échoué. Vérifiez votre connexion.';
    } finally {
      _restauration = null;
    }
    _passerA(entitlement.estDebloque ? EtatAchat.pret : precedent);
  }

  Future<void> _traiter(List<PurchaseDetails> achats) async {
    for (final achat in achats) {
      switch (achat.status) {
        case PurchaseStatus.pending:
          _passerA(EtatAchat.enCours);
          continue;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (achat.productID == IdentifiantsProduit.courant) {
            await entitlement.debloquer();
          }
          _terminerRestauration();

        case PurchaseStatus.error:
          debugPrint('Achat en erreur : ${achat.error}');
          _erreur = "Le paiement n'a pas abouti. Vous n'avez pas été débité.";

        case PurchaseStatus.canceled:
          // Volontaire : rien à expliquer à quelqu'un qui vient de
          // renoncer. Un message d'erreur se lirait comme un reproche.
          break;
      }

      // Sans finalisation, iOS represente l'achat à chaque lancement et
      // Play finit par le rembourser.
      if (achat.pendingCompletePurchase) {
        try {
          await _boutique.finaliser(achat);
        } catch (e) {
          debugPrint('Finalisation impossible : $e');
        }
      }
      _passerA(_produit == null ? EtatAchat.indisponible : EtatAchat.pret);
    }
  }

  /// Débloque l'attente de [restaurer] dès que la boutique a répondu.
  void _terminerRestauration() {
    final attente = _restauration;
    if (attente != null && !attente.isCompleted) attente.complete();
  }

  void oublierErreur() {
    if (_erreur == null) return;
    _erreur = null;
    notifyListeners();
  }

  void _passerA(EtatAchat etat) {
    _etat = etat;
    notifyListeners();
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }
}

/// Rend le service d'achat accessible aux écrans sans le faire traverser
/// tous ceux qui les séparent.
///
/// Il doit envelopper `MaterialApp` : l'écran de paiement est poussé par
/// le Navigator, dont les routes se construisent sous lui.
class FournisseurAchats extends InheritedWidget {
  const FournisseurAchats({
    super.key,
    required this.service,
    required super.child,
  });

  /// `null` là où il n'y a pas de boutique : tests, aperçu, bureau.
  final PurchaseService? service;

  /// Lecture sans abonnement : le service ne change jamais de la vie de
  /// l'app, et `dependOnInheritedWidgetOfExactType` est interdit depuis
  /// `initState`, d'où l'écran de paiement le récupère.
  static PurchaseService? lireDe(BuildContext context) => context
      .getInheritedWidgetOfExactType<FournisseurAchats>()
      ?.service;

  @override
  bool updateShouldNotify(FournisseurAchats ancien) =>
      service != ancien.service;
}

/// Vrai là où `in_app_purchase` a une boutique en face.
bool get boutiqueSupportee =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

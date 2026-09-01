import 'dart:async';

import 'package:frais_tpe/services/purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Une boutique pilotable, pour éprouver les chemins d'achat sans App
/// Store ni Play Console.
///
/// Sans elle, l'annulation, la panne réseau et le produit absent ne se
/// vérifieraient qu'à la main, sur un compte de test, après publication.
class BoutiqueFactice implements Boutique {
  BoutiqueFactice({
    this.disponible = true,
    this.produitPublie = true,
    this.echecAuLancement = false,
    this.echecALaRestauration = false,
  });

  bool disponible;
  bool produitPublie;

  /// L'appel d'achat lui-même échoue (boutique injoignable au moment du
  /// clic), par opposition à un achat qui part et revient en erreur.
  bool echecAuLancement;
  bool echecALaRestauration;

  final _controleur = StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> finalises = [];
  int achatsLances = 0;
  int restaurations = 0;

  static ProductDetails illimite() => ProductDetails(
        id: IdentifiantsProduit.illimiteAndroid,
        title: 'Tout débloquer',
        description: 'Toutes vos comparaisons, à vie',
        price: '4,99 €',
        rawPrice: 4.99,
        currencyCode: 'EUR',
      );

  static ProductDetails rapport() => ProductDetails(
        id: IdentifiantsProduit.rapportAndroid,
        title: 'Ce rapport',
        description: 'Une comparaison',
        price: '0,99 €',
        rawPrice: 0.99,
        currencyCode: 'EUR',
      );

  /// Fabrique une notification d'achat telle que la boutique en envoie.
  static PurchaseDetails achat(
    PurchaseStatus statut, {
    String? produit,
    bool aFinaliser = true,
  }) =>
      PurchaseDetails(
        purchaseID: 'achat-1',
        productID: produit ?? IdentifiantsProduit.illimiteAndroid,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'factice',
        ),
        transactionDate: '0',
        status: statut,
      )..pendingCompletePurchase = aFinaliser;

  /// Simule ce que la boutique renvoie après un achat ou une restauration.
  void emettre(List<PurchaseDetails> achats) => _controleur.add(achats);

  void emettreErreurDeFlux(Object erreur) => _controleur.addError(erreur);

  @override
  Future<bool> estDisponible() async => disponible;

  @override
  Stream<List<PurchaseDetails>> get flux => _controleur.stream;

  /// Les produits publiés. Par défaut les deux ; `produitPublie: false`
  /// simule une boutique qui n'en connaît aucun.
  @override
  Future<ProductDetailsResponse> produits(Set<String> identifiants) async {
    final publies = produitPublie
        ? [illimite(), rapport()].where((p) => identifiants.contains(p.id)).toList()
        : <ProductDetails>[];
    return ProductDetailsResponse(
      productDetails: publies,
      notFoundIDs: identifiants
          .where((id) => publies.every((p) => p.id != id))
          .toList(),
    );
  }

  int consommablesLances = 0;

  @override
  Future<void> acheter(PurchaseParam parametres) async {
    achatsLances++;
    if (echecAuLancement) throw Exception('boutique injoignable');
  }

  @override
  Future<void> acheterConsommable(PurchaseParam parametres) async {
    consommablesLances++;
    if (echecAuLancement) throw Exception('boutique injoignable');
  }

  @override
  Future<void> restaurer() async {
    restaurations++;
    if (echecALaRestauration) throw Exception('réseau indisponible');
  }

  @override
  Future<void> finaliser(PurchaseDetails achat) async => finalises.add(achat);

  Future<void> fermer() => _controleur.close();
}

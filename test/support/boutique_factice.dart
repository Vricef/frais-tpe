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

  static ProductDetails details() => ProductDetails(
        id: IdentifiantsProduit.android,
        title: 'Déblocage complet',
        description: 'Comparaison complète, PDF et sauvegarde',
        price: '2,99 €',
        rawPrice: 2.99,
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
        productID: produit ?? IdentifiantsProduit.android,
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

  @override
  Future<ProductDetailsResponse> produits(Set<String> identifiants) async =>
      ProductDetailsResponse(
        productDetails: produitPublie ? [details()] : const [],
        notFoundIDs: produitPublie ? const [] : identifiants.toList(),
      );

  @override
  Future<void> acheter(PurchaseParam parametres) async {
    achatsLances++;
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

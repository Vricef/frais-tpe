import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/screens/paywall_screen.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/purchase_service.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/boutique_factice.dart';

/// Stockage en mémoire : les tests d'état ne doivent pas dépendre du
/// stockage du système, ni le test suivant hériter du précédent.
class _StockageMemoire implements StockageEntitlement {
  _StockageMemoire([this.valeur = false]);
  bool valeur;
  bool echoue = false;

  @override
  Future<bool> lire() async {
    if (echoue) throw Exception('stockage illisible');
    return valeur;
  }

  @override
  Future<void> ecrire(bool debloque) async {
    if (echoue) throw Exception('stockage inscriptible');
    valeur = debloque;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('service d\'achat', () {
    late BoutiqueFactice boutique;
    late Entitlement entitlement;
    late PurchaseService service;
    late _StockageMemoire stockage;

    setUp(() {
      boutique = BoutiqueFactice();
      stockage = _StockageMemoire();
      entitlement = Entitlement(stockage: stockage);
      service = PurchaseService(
        entitlement: entitlement,
        boutique: boutique,
        delaiRestauration: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      service.dispose();
      await boutique.fermer();
    });

    test('au démarrage, le produit est interrogé et le prix vient du store', () async {
      await service.demarrer();

      expect(service.etat, EtatAchat.pret);
      // Le prix affiché doit venir de la boutique : un montant codé en
      // dur devient faux dès qu'un pays ou une taxe change.
      expect(service.prix, '3,99 €');
      expect(service.peutAcheter, isTrue);
    });

    test('boutique injoignable : rien à vendre, pas de plantage', () async {
      boutique.disponible = false;
      await service.demarrer();

      expect(service.etat, EtatAchat.indisponible);
      expect(service.peutAcheter, isFalse);
    });

    test('produit non publié : l\'achat est masqué plutôt que cassé', () async {
      boutique.produitPublie = false;
      await service.demarrer();

      // C'est l'état de Play tant que le produit n'est pas créé : mieux
      // vaut masquer l'achat que proposer un bouton qui échouera.
      expect(service.etat, EtatAchat.indisponible);
      expect(service.prix, isNull);
    });

    test('un achat réussi débloque et se finalise', () async {
      await service.demarrer();
      await service.acheter();
      expect(boutique.achatsLances, 1);

      boutique.emettre([BoutiqueFactice.achat(PurchaseStatus.purchased)]);
      await Future<void>.delayed(Duration.zero);

      expect(entitlement.estDebloque, isTrue);
      expect(stockage.valeur, isTrue, reason: 'le déblocage doit survivre au redémarrage');
      // Sans finalisation, iOS represente l'achat à chaque lancement et
      // Play finit par le rembourser.
      expect(boutique.finalises, hasLength(1));
    });

    test('un achat annulé ne débloque rien et ne dit rien', () async {
      await service.demarrer();
      await service.acheter();

      boutique.emettre([BoutiqueFactice.achat(PurchaseStatus.canceled)]);
      await Future<void>.delayed(Duration.zero);

      expect(entitlement.estDebloque, isFalse);
      // Un message d'erreur se lirait comme un reproche à quelqu'un qui
      // vient simplement de renoncer.
      expect(service.erreur, isNull);
      expect(service.etat, EtatAchat.pret);
    });

    test('un achat en erreur est expliqué sans plantage', () async {
      await service.demarrer();
      await service.acheter();

      boutique.emettre([BoutiqueFactice.achat(PurchaseStatus.error)]);
      await Future<void>.delayed(Duration.zero);

      expect(entitlement.estDebloque, isFalse);
      expect(service.erreur, contains('pas été débité'));
      expect(service.etat, EtatAchat.pret);
    });

    test('un achat qui ne part pas laisse l\'écran utilisable', () async {
      await service.demarrer();
      boutique.echecAuLancement = true;
      await service.acheter();

      expect(service.erreur, isNotNull);
      // L'écran ne doit pas rester bloqué sur un spinner éternel.
      expect(service.etat, EtatAchat.pret);
    });

    test('une erreur du flux ne fait pas tomber l\'app', () async {
      await service.demarrer();
      boutique.emettreErreurDeFlux(Exception('flux rompu'));
      await Future<void>.delayed(Duration.zero);

      expect(service.erreur, isNotNull);
      expect(entitlement.estDebloque, isFalse);
    });

    test('la restauration rend un achat fait sur un autre appareil', () async {
      await service.demarrer();
      final futur = service.restaurer();
      boutique.emettre([BoutiqueFactice.achat(PurchaseStatus.restored)]);
      await futur;

      expect(boutique.restaurations, 1);
      expect(entitlement.estDebloque, isTrue);
      expect(stockage.valeur, isTrue);
    });

    test('restaurer sans achat le dit, sans rien débloquer', () async {
      await service.demarrer();
      await service.restaurer();

      expect(entitlement.estDebloque, isFalse);
      expect(service.erreur, contains('Aucun achat'));
    });

    test('une restauration qui échoue est expliquée', () async {
      boutique.echecALaRestauration = true;
      await service.demarrer();
      await service.restaurer();

      expect(service.erreur, contains('connexion'));
      expect(entitlement.estDebloque, isFalse);
    });

    test('un achat d\'un autre produit ne débloque pas', () async {
      await service.demarrer();
      boutique.emettre([
        BoutiqueFactice.achat(PurchaseStatus.purchased, produit: 'autre_chose'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(entitlement.estDebloque, isFalse);
    });
  });

  group('persistance du déblocage', () {
    test('il est relu au démarrage suivant', () async {
      final entitlement = Entitlement(stockage: _StockageMemoire(true));
      expect(entitlement.estDebloque, isFalse);
      await entitlement.charger();
      expect(entitlement.estDebloque, isTrue);
    });

    test('un stockage illisible laisse l\'app verrouillée', () async {
      final stockage = _StockageMemoire(true)..echoue = true;
      final entitlement = Entitlement(stockage: stockage);
      await entitlement.charger();

      // Verrouillé plutôt que débloqué : la restauration reste ouverte à
      // l'utilisateur, alors qu'un déblocage indu serait invisible.
      expect(entitlement.estDebloque, isFalse);
    });

    test('une écriture qui échoue ne perd pas l\'achat de la session', () async {
      final stockage = _StockageMemoire()..echoue = true;
      final entitlement = Entitlement(stockage: stockage);
      await entitlement.debloquer();

      expect(entitlement.estDebloque, isTrue);
    });
  });

  group('écran de paiement', () {
    Widget ecran(PurchaseService service, Entitlement entitlement) => MaterialApp(
          theme: AppTheme.light,
          home: PaywallScreen(entitlement: entitlement, achats: service),
        );

    testWidgets('le prix du store remplace celui codé en dur', (tester) async {
      final boutique = BoutiqueFactice();
      final entitlement = Entitlement(stockage: _StockageMemoire());
      final service =
          PurchaseService(entitlement: entitlement, boutique: boutique);
      await service.demarrer();

      await tester.pumpWidget(ecran(service, entitlement));
      await tester.pumpAndSettle();

      expect(find.text('Débloquer pour 3,99 €'), findsOneWidget);
      expect(find.text('Restaurer mes achats'), findsOneWidget);

      service.dispose();
      await boutique.fermer();
    });

    testWidgets('sans boutique, aucun bouton d\'achat n\'est proposé', (
      tester,
    ) async {
      final boutique = BoutiqueFactice(disponible: false);
      final entitlement = Entitlement(stockage: _StockageMemoire());
      final service =
          PurchaseService(entitlement: entitlement, boutique: boutique);
      await service.demarrer();

      await tester.pumpWidget(ecran(service, entitlement));
      await tester.pumpAndSettle();

      expect(find.textContaining('Débloquer pour'), findsNothing);
      expect(find.textContaining("n'est pas disponible"), findsOneWidget);
      // La restauration reste offerte : c'est le seul recours de qui a
      // déjà payé sur un autre appareil.
      expect(find.text('Restaurer mes achats'), findsOneWidget);

      service.dispose();
      await boutique.fermer();
    });

    testWidgets('appuyer sur le bouton lance l\'achat', (tester) async {
      final boutique = BoutiqueFactice();
      final entitlement = Entitlement(stockage: _StockageMemoire());
      final service =
          PurchaseService(entitlement: entitlement, boutique: boutique);
      await service.demarrer();

      await tester.pumpWidget(ecran(service, entitlement));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Débloquer pour 3,99 €'));
      await tester.pump();

      expect(boutique.achatsLances, 1);

      service.dispose();
      await boutique.fermer();
    });
  });
}

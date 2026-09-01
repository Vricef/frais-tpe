import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'support/boutique_factice.dart';

class _Stockage implements StockageEntitlement {
  bool illimite = false;
  Set<String> comparaisons = {};

  @override
  Future<bool> lireIllimite() async => illimite;
  @override
  Future<void> ecrireIllimite(bool v) async => illimite = v;
  @override
  Future<Set<String>> lireComparaisons() async => comparaisons;
  @override
  Future<void> ecrireComparaisons(Set<String> v) async => comparaisons = {...v};
}

String _cle({double volume = 4200, double? panier, String provider = 'zettle'}) =>
    Entitlement.cleDe(
      volumeMensuel: volume,
      panierMoyen: panier,
      providerActuelId: provider,
    );

void main() {
  late BoutiqueFactice boutique;
  late _Stockage stockage;
  late Entitlement entitlement;
  late PurchaseService service;

  setUp(() async {
    boutique = BoutiqueFactice();
    stockage = _Stockage();
    entitlement = Entitlement(stockage: stockage);
    service = PurchaseService(
      entitlement: entitlement,
      boutique: boutique,
      delaiRestauration: const Duration(milliseconds: 50),
    );
    await service.demarrer();
  });

  tearDown(() async {
    service.dispose();
    await boutique.fermer();
  });

  Future<void> jouer(PurchaseDetails achat) async {
    boutique.emettre([achat]);
    await Future<void>.delayed(Duration.zero);
  }

  group('le rapport à l\'unité', () {
    test('passe par un achat consommable', () async {
      entitlement.comparaisonCourante = _cle();
      await service.acheterRapport();

      // Sans consommation, Play refuserait tout rachat du même produit :
      // le deuxième rapport serait impossible à vendre.
      expect(boutique.consommablesLances, 1);
      expect(boutique.achatsLances, 0);
    });

    test('n\'ouvre que la comparaison affichée au moment de l\'achat', () async {
      entitlement.comparaisonCourante = _cle(volume: 4200);
      await jouer(BoutiqueFactice.achat(
        PurchaseStatus.purchased,
        produit: IdentifiantsProduit.rapportAndroid,
      ));

      expect(entitlement.estDebloque, isTrue);
      expect(entitlement.estIllimite, isFalse,
          reason: 'un rapport ne vaut pas le déblocage définitif');

      // Changer le volume, c'est une autre comparaison : sinon l'achat à
      // l'unité donnerait l'illimité par la petite porte.
      entitlement.comparaisonCourante = _cle(volume: 8000);
      expect(entitlement.estDebloque, isFalse);

      // Y revenir la retrouve ouverte.
      entitlement.comparaisonCourante = _cle(volume: 4200);
      expect(entitlement.estDebloque, isTrue);
    });

    test('survit au redémarrage', () async {
      entitlement.comparaisonCourante = _cle();
      await jouer(BoutiqueFactice.achat(
        PurchaseStatus.purchased,
        produit: IdentifiantsProduit.rapportAndroid,
      ));

      // La boutique ne restaure pas un consommable : c'est le stockage
      // local qui doit tenir, y compris pour rouvrir depuis l'historique.
      final apres = Entitlement(stockage: stockage);
      await apres.charger();
      apres.comparaisonCourante = _cle();
      expect(apres.estDebloque, isTrue);
    });

    test('acheté sans comparaison désignée, n\'ouvre rien', () async {
      entitlement.comparaisonCourante = null;
      await jouer(BoutiqueFactice.achat(
        PurchaseStatus.purchased,
        produit: IdentifiantsProduit.rapportAndroid,
      ));

      expect(entitlement.estDebloque, isFalse);
      expect(stockage.comparaisons, isEmpty);
    });
  });

  group('le déblocage définitif', () {
    test('vaut pour toutes les comparaisons', () async {
      await jouer(BoutiqueFactice.achat(PurchaseStatus.purchased));

      expect(entitlement.estIllimite, isTrue);
      for (final volume in [1000.0, 4200.0, 99999.0]) {
        entitlement.comparaisonCourante = _cle(volume: volume);
        expect(entitlement.estDebloque, isTrue, reason: '$volume');
      }
      // Même sans comparaison désignée.
      entitlement.comparaisonCourante = null;
      expect(entitlement.estDebloque, isTrue);
    });

    test('reste proposé à qui a déjà payé un rapport', () async {
      entitlement.comparaisonCourante = _cle();
      await jouer(BoutiqueFactice.achat(
        PurchaseStatus.purchased,
        produit: IdentifiantsProduit.rapportAndroid,
      ));

      // Le deuxième barreau de l'échelle doit rester atteignable.
      expect(entitlement.estDebloque, isTrue);
      expect(service.peutAcheterIllimite, isTrue);
    });

    test('est le seul que la restauration ramène', () async {
      entitlement.comparaisonCourante = _cle();
      await jouer(BoutiqueFactice.achat(
        PurchaseStatus.purchased,
        produit: IdentifiantsProduit.rapportAndroid,
      ));

      await service.restaurer();

      // Un consommable n'est pas restaurable : le message doit le dire
      // sans laisser croire que l'achat a été perdu par erreur.
      expect(service.erreur, contains('définitif'));
      expect(entitlement.estIllimite, isFalse);
    });
  });

  test('les deux produits sont interrogés d\'un coup', () {
    expect(service.prixIllimite, '4,99 €');
    expect(service.prixRapport, '0,99 €');
    // Un identifiant par plateforme, jamais confondus.
    expect(IdentifiantsProduit.illimiteIos, 'com.fraistpe.app.unlock_full');
    expect(IdentifiantsProduit.rapportIos, 'com.fraistpe.app.report_single');
    expect(IdentifiantsProduit.illimiteAndroid, 'unlock_full');
    expect(IdentifiantsProduit.rapportAndroid, 'report_single');
  });
}

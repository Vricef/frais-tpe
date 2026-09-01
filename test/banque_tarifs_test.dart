import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/provider_detail_screen.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Une banque qui publie sa grille : le cas que le modèle ne savait pas
/// représenter tant que « tarifs fixes » se déduisait du type.
const _banqueAGrille = TpeProvider(
  id: 'credit_agricole_up2pay_mobile',
  nom: 'Crédit Agricole',
  offre: 'Up2pay Mobile',
  type: ProviderType.banquePro,
  fraisTransactionCb: 1.75,
  fraisMensuels: 0,
);

/// Une banque qui n'en publie aucune : seule une fourchette est connue.
const _banqueSansGrille = TpeProvider(
  id: 'bnp_paribas',
  nom: 'BNP Paribas',
  type: ProviderType.banquePro,
  fourchetteMin: 0.5,
  fourchetteMax: 2.5,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  group('une banque peut publier une grille fixe', () {
    test('son tarif est exact, pas estimé', () {
      expect(_banqueAGrille.aTarifsFixes, isTrue);
      expect(_banqueSansGrille.aTarifsFixes, isFalse);
    });

    test('le calcul retient le taux publié, pas un milieu de fourchette', () {
      const calculateur = FeeCalculator();
      expect(
        calculateur.calculer(provider: _banqueAGrille, volumeMensuel: 8000)
            .totalMensuel,
        closeTo(140, 0.001),
      );
      // Faute de taux publié, le milieu de la fourchette : 1,5 % de 8 000 €.
      expect(
        calculateur.calculer(provider: _banqueSansGrille, volumeMensuel: 8000)
            .totalMensuel,
        closeTo(120, 0.001),
      );
    });

    testWidgets('sa fiche montre la grille, pas le discours de négociation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ProviderDetailScreen(
            provider: _banqueAGrille,
            volumeMensuel: 8000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GRILLE TARIFAIRE'), findsOneWidget);
      expect(find.textContaining('se négocie au cas par cas'), findsNothing);
      // Le libellé reste celui d'une banque : c'en est une.
      expect(find.text('Banque professionnelle'), findsOneWidget);
    });

    testWidgets('celle sans grille garde la fourchette et sa mention', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ProviderDetailScreen(
            provider: _banqueSansGrille,
            volumeMensuel: 8000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('entre 0,5 % et 2,5 %'), findsOneWidget);
      expect(find.text('GRILLE TARIFAIRE'), findsNothing);
    });
  });

  group('seed : les banques ajoutées', () {
    late Map<String, dynamic> seed;
    setUpAll(() {
      seed = jsonDecode(File('firestore/providers.seed.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    TpeProvider lire(String id) =>
        TpeProvider.fromMap(id, seed[id] as Map<String, dynamic>);

    test('les deux offres BPCE sont identiques hors le nom', () {
      final ce = seed['caisse_epargne_tap_to_pay'] as Map<String, dynamic>;
      final bp = seed['banque_populaire_tap_to_pay'] as Map<String, dynamic>;
      // Même groupe, mêmes tarifs : un écart signalerait une faute de
      // saisie plutôt qu'une différence réelle.
      expect({...ce}..remove('nom'), equals({...bp}..remove('nom')));
      expect(lire('caisse_epargne_tap_to_pay').fraisTransactionCb, 1.25);
      expect(lire('caisse_epargne_tap_to_pay').fraisFixeTransaction, 0.15);
      expect(lire('caisse_epargne_tap_to_pay').fraisMensuels, 4.90);
    });

    test('les deux offres Monetico se distinguent par le taux et l\'abo', () {
      final sans = lire('credit_mutuel_monetico_sans_abonnement');
      final avec = lire('credit_mutuel_monetico_avec_abonnement');
      expect(sans.fraisTransactionCb, 1.70);
      expect(sans.fraisMensuels, 0);
      expect(sans.condition, contains('mise en service'));
      expect(avec.fraisTransactionCb, 1.00);
      expect(avec.fraisMensuels, 5);
      // L'abonnement n'a d'intérêt qu'au-delà d'un certain volume : les
      // deux offres doivent rester distinctes, sinon l'une est inutile.
      expect(sans.fraisTransactionCb, isNot(avec.fraisTransactionCb));
    });

    test('les banques sans grille publiée restent en fourchette', () {
      for (final id in [
        'bnp_paribas',
        'lcl',
        'la_banque_postale',
        'societe_generale',
      ]) {
        final p = lire(id);
        expect(p.aTarifsFixes, isFalse, reason: id);
        expect(p.fourchetteMin, 0.5, reason: id);
        expect(p.fourchetteMax, 2.5, reason: id);
        // Elles ne prétendent pas à une grille vérifiée.
        expect(p.source, 'estimation', reason: id);
      }
    });

    test('tout document à taux exact est marqué comme vérifié', () {
      for (final entree in seed.entries) {
        final p = TpeProvider.fromMap(
          entree.key,
          entree.value as Map<String, dynamic>,
        );
        if (!p.aTarifsFixes) continue;
        // Un taux au centime près sans provenance renseignée serait
        // invérifiable à la prochaine mise à jour.
        expect(
          p.source,
          anyOf('vérifiée', isNull),
          reason: '${entree.key} : source inattendue',
        );
      }
    });
  });
}

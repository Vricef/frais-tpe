import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/result_screen.dart';
import 'package:frais_tpe/services/calculation_store.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Meilleure dans l'absolu, mais suppose d'ouvrir un compte.
const _neobanque = TpeProvider(
  id: 'neobanque',
  nom: 'Néobanque',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.7,
  compteRequis: true,
);
/// Meilleure parmi celles qui s'ajoutent à la banque existante.
const _processeur = TpeProvider(
  id: 'processeur',
  nom: 'Processeur',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.2,
);
const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
);

const _calculateur = FeeCalculator();
const _volume = 4000.0;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('la seconde meilleure offre', () {
    test('existe quand la gagnante demande d\'ouvrir un compte', () {
      final r = _calculateur.comparer(
        actuel: _actuel,
        candidats: const [_neobanque, _processeur],
        volumeMensuel: _volume,
      )!;

      expect(r.optimise.provider.id, 'neobanque');
      expect(r.optimiseSansCompte?.provider.id, 'processeur');
      // 1,75 % - 1,2 % de 4 000 €.
      expect(r.economieSansCompteMensuelle, closeTo(22, 0.001));
    });

    test('est absente quand la gagnante n\'exige rien', () {
      final r = _calculateur.comparer(
        actuel: _actuel,
        candidats: const [_processeur],
        volumeMensuel: _volume,
      )!;

      // Il n'y a qu'un gagnant à montrer : en inventer un second
      // n'apporterait rien.
      expect(r.optimiseSansCompte, isNull);
    });

    test('n\'est pas proposée si elle coûte plus cher que l\'actuel', () {
      const cher = TpeProvider(
        id: 'cher',
        nom: 'Plus cher',
        type: ProviderType.processeurPaiement,
        fraisTransactionCb: 2.5,
      );
      final r = _calculateur.comparer(
        actuel: _actuel,
        candidats: const [_neobanque, cher],
        volumeMensuel: _volume,
      )!;

      // Proposer une alternative plus chère que ce que l'utilisateur
      // paie déjà n'aiderait personne.
      expect(r.optimiseSansCompte, isNull);
    });
  });

  group('écran de résultat', () {
    Widget ecran(Entitlement e) => MaterialApp(
          theme: AppTheme.light,
          home: ResultScreen(
            volumeMensuel: _volume,
            providerActuel: _actuel,
            providers: const [_actuel, _neobanque, _processeur],
            entitlement: e,
            store: PrefsCalculationStore(),
          ),
        );

    testWidgets('sans achat, aucun nom de gagnant n\'est lisible', (
      tester,
    ) async {
      await tester.pumpWidget(ecran(Entitlement(debloque: false)));
      await tester.pumpAndSettle();

      expect(find.text('La meilleure offre'), findsOneWidget);
      expect(find.text('Une autre offre'), findsOneWidget);
      // Les noms sont ce que l'achat débloque.
      expect(find.textContaining('Néobanque'), findsNothing);
      expect(find.textContaining('Processeur'), findsNothing);
      // L'ampleur du gain, elle, reste affichée : c'est l'hameçon.
      expect(find.textContaining('SANS CHANGER DE BANQUE'), findsOneWidget);
    });

    testWidgets('après achat, les deux noms apparaissent', (tester) async {
      final entitlement = Entitlement(debloque: false);
      await tester.pumpWidget(ecran(entitlement));
      await tester.pumpAndSettle();

      await entitlement.debloquer();
      await tester.pumpAndSettle();

      expect(find.text('Avec Néobanque'), findsOneWidget);
      expect(find.text('Processeur'), findsOneWidget);
      expect(find.text('La meilleure offre'), findsNothing);
    });
  });

  test('seed : les offres qui supposent un compte sont marquées', () {
    final seed = jsonDecode(
      File('firestore/providers.seed.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final avec = <String>[], sans = <String>[];
    for (final e in seed.entries) {
      final p = TpeProvider.fromMap(e.key, e.value as Map<String, dynamic>);
      (p.compteRequis ? avec : sans).add(e.key);
      // Une banque suppose toujours d'en être client.
      if (p.type == ProviderType.banquePro) {
        expect(p.compteRequis, isTrue, reason: e.key);
      }
    }
    // Les six processeurs de paiement s'ajoutent à la banque existante :
    // sans eux, la seconde meilleure offre n'existerait jamais.
    expect(sans, hasLength(6));
    expect(avec, hasLength(11));
  });
}

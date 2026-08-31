import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/comparison_table_screen.dart';
import 'package:frais_tpe/screens/provider_detail_screen.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:frais_tpe/widgets/masked_amount.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

const _qonto = TpeProvider(
  id: 'qonto',
  nom: 'Qonto',
  offre: 'Tap to Pay + TPE',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.7,
  fraisMensuels: 0,
  condition: 'Compte pro Qonto requis, à partir de 9 € HT/mois.',
);
const _sansCondition = TpeProvider(
  id: 'zettle',
  nom: 'Zettle',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
);
/// Moins cher que Qonto : sans lui, Qonto serait la meilleure offre et
/// donc affichée en clair — le test ne prouverait rien.
const _meilleur = TpeProvider(
  id: 'meilleur',
  nom: 'Prestataire le moins cher',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.3,
);
const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 2.2,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  group('condition d\'accès à une offre', () {
    test('elle survit à un aller-retour Firestore', () {
      final relu = TpeProvider.fromMap('qonto', _qonto.toMap());
      expect(relu.condition, _qonto.condition);

      // Une offre sans condition n'écrit pas le champ : le document
      // Firestore reste au plus près de ce qui est réellement connu.
      expect(_sansCondition.toMap().containsKey('condition'), isFalse);
      expect(TpeProvider.fromMap('zettle', _sansCondition.toMap()).condition,
          isNull);
    });

    test('elle ne pèse pas sur le coût calculé', () {
      const calculateur = FeeCalculator();
      final avec = calculateur.calculer(provider: _qonto, volumeMensuel: 8000);

      // 0,7 % de 8 000 €, et rien d'autre : le forfait de compte n'est
      // pas un frais de carte, l'ajouter fausserait la comparaison dans
      // l'autre sens.
      expect(avec.totalMensuel, closeTo(56, 0.001));
      expect(avec.lignes, hasLength(1));
    });

    testWidgets('la fiche l\'affiche et dit qu\'elle est hors calcul', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ProviderDetailScreen(
            provider: _qonto,
            volumeMensuel: 8000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_qonto.condition!), findsOneWidget);
      expect(find.textContaining("Non compté dans l'estimation"), findsOneWidget);
    });

    testWidgets('le tableau l\'affiche même sur une ligne verrouillée', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ComparisonTableScreen(
            volumeMensuel: 8000,
            providers: const [_actuel, _meilleur, _sansCondition, _qonto],
            providerActuel: _actuel,
            entitlement: Entitlement(debloque: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Qonto est bien du côté masqué : lui et Zettle, ni l'offre
      // actuelle ni la meilleure.
      expect(find.byType(MaskedAmount), findsNWidgets(2));
      expect(find.text('Qonto — Tap to Pay + TPE'), findsOneWidget);
      expect(find.text(_euro.format(56)), findsNothing);
      // …mais pas la condition : elle décrit l'offre, pas son prix, et
      // la cacher laisserait croire l'offre accessible telle quelle.
      expect(find.text(_qonto.condition!), findsOneWidget);
    });
  });

  group('fichier de seed', () {
    late Map<String, dynamic> seed;

    setUpAll(() {
      seed = jsonDecode(File('firestore/providers.seed.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('chaque document se relit comme un TpeProvider exploitable', () {
      expect(seed, hasLength(7));
      for (final entree in seed.entries) {
        final p = TpeProvider.fromMap(
          entree.key,
          entree.value as Map<String, dynamic>,
        );
        expect(p.nom, isNotEmpty, reason: entree.key);
        // Sans commission ni fourchette, la ligne n'est pas calculable.
        expect(
          p.fraisTransactionCb ?? p.fourchetteMin,
          isNotNull,
          reason: entree.key,
        );
      }
    });

    test('Qonto est seedé aux tarifs fournis', () {
      final qonto = TpeProvider.fromMap(
        'qonto',
        seed['qonto'] as Map<String, dynamic>,
      );
      expect(qonto.fraisTransactionCb, 0.7);
      expect(qonto.fraisMensuels, 0);
      expect(qonto.condition, contains('9 € HT/mois'));
      // Le taux cartes pro / hors UE est affiché sur la fiche, pas
      // fondu dans le calcul du cas courant.
      expect(qonto.tarifsAdditionnels.single.taux, 2.6);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/provider_detail_screen.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

const _verifie = TpeProvider(
  id: 'sumup',
  nom: 'SumUp',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
  source: 'vérifiée',
);
const _fourchette = TpeProvider(
  id: 'bnp_paribas',
  nom: 'BNP Paribas',
  type: ProviderType.banquePro,
  fourchetteMin: 0.5,
  fourchetteMax: 2.5,
  source: 'estimation',
);

Widget _fiche(TpeProvider p) => MaterialApp(
      theme: AppTheme.light,
      home: ProviderDetailScreen(provider: p, volumeMensuel: 8000),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('une grille relevée annonce sa source et sa date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _fiche(
        TpeProvider(
          id: _verifie.id,
          nom: _verifie.nom,
          type: _verifie.type,
          fraisTransactionCb: _verifie.fraisTransactionCb,
          source: _verifie.source,
          derniereMaj: DateTime(2026, 8, 6),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Vérifié sur le site officiel du prestataire, le 6 août 2026.'),
      findsOneWidget,
    );
  });

  testWidgets('une fourchette ne se présente jamais comme vérifiée', (
    tester,
  ) async {
    await tester.pumpWidget(_fiche(_fourchette));
    await tester.pumpAndSettle();

    // Le défaut d'avant : l'écran annonçait « Tarifs vérifiés » pour tout
    // le monde, y compris une banque qui ne publie aucun tarif.
    expect(find.textContaining('Vérifié sur le site officiel'), findsNothing);
    expect(
      find.textContaining('ne publie pas de grille tarifaire'),
      findsWidgets,
    );
  });

  testWidgets('sans source renseignée, aucune vérification n\'est affirmée', (
    tester,
  ) async {
    await tester.pumpWidget(
      _fiche(
        const TpeProvider(
          id: 'perso',
          nom: 'Mon prestataire',
          type: ProviderType.processeurPaiement,
          fraisTransactionCb: 1.6,
          estPersonnalise: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Vérifié sur le site officiel'), findsNothing);
  });

  group('seed', () {
    late Map<String, dynamic> seed;
    setUpAll(() {
      seed = jsonDecode(File('firestore/providers.seed.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('toutes les grilles relevées portent la date du relevé', () {
      for (final e in seed.entries) {
        expect(e.value['derniere_maj'], isNotNull, reason: e.key);
      }
    });

    test('le badge suit exactement la forme des tarifs', () {
      for (final e in seed.entries) {
        final p = TpeProvider.fromMap(e.key, e.value as Map<String, dynamic>);
        // Un taux exact vient forcément d'un relevé ; une fourchette ne
        // peut pas être « vérifiée ». Toute autre combinaison est une
        // faute de saisie qui se verrait à l'écran.
        expect(
          p.source,
          p.aTarifsFixes ? 'vérifiée' : 'estimation',
          reason: e.key,
        );
      }
      expect(
        seed.values.where((v) => (v as Map)['source'] == 'vérifiée'),
        hasLength(13),
      );
    });

    test('Crédit Agricole renvoie en agence sans avancer de taux', () {
      final ca = TpeProvider.fromMap(
        'credit_agricole_up2pay_mobile',
        seed['credit_agricole_up2pay_mobile'] as Map<String, dynamic>,
      );
      expect(ca.fraisTransactionCb, 1.75);
      expect(ca.condition, contains('conseiller'));
      expect(ca.condition, contains('inférieur à 1,75 %'));
      // Le taux réduit n'est pas public. Le seul pourcentage cité doit
      // être le plafond connu (1,75 %) ; tout autre chiffre serait une
      // valeur inventée présentée comme un tarif.
      final taux = RegExp(r'(\d+(?:,\d+)?)\s*%')
          .allMatches(ca.condition!)
          .map((m) => m.group(1))
          .toSet();
      expect(taux, {'1,75'});
    });
  });
}

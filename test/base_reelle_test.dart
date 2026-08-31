import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/comparison_table_screen.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/services/pdf_report_service.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:frais_tpe/widgets/masked_amount.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Les tests précédents travaillent sur des prestataires inventés, en
/// petit nombre. Ceux-ci rejouent le parcours sur la base réelle, dont
/// la taille a plus que doublé : c'est là que le PDF et le tableau
/// changent de comportement.
List<TpeProvider> chargerSeed() {
  final brut =
      jsonDecode(File('firestore/providers.seed.json').readAsStringSync())
          as Map<String, dynamic>;
  return brut.entries
      .map((e) => TpeProvider.fromMap(e.key, e.value as Map<String, dynamic>))
      .toList();
}

void main() {
  const calculator = FeeCalculator();
  const service = PdfReportService();
  late List<TpeProvider> providers;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
    providers = chargerSeed();
  });

  test('la base compte bien les prestataires attendus', () {
    expect(providers, hasLength(17));
  });

  test('le rapport PDF encaisse la base entière', () async {
    final actuel = providers.firstWhere((p) => p.id == 'zettle');
    final resultat = calculator.comparer(
      actuel: actuel,
      candidats: providers,
      volumeMensuel: 8000,
    )!;

    // Un tableau de classement trop long avait déjà fait dépasser la
    // limite de pages du générateur : le nombre de lignes est ce qui
    // met ce chemin sous tension.
    final octets = await service.construire(
      resultat: resultat,
      classement: calculator.classer(providers: providers, volumeMensuel: 8000),
      volumeMensuel: 8000,
      date: DateTime(2026, 8, 31),
    );

    expect(octets, isNotEmpty);
    expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(
      String.fromCharCodes(octets),
    ).length;
    expect(pages, greaterThan(0));
    expect(pages, lessThan(20), reason: 'le générateur plafonne à 20 pages');
  });

  testWidgets('le tableau gratuit ne chiffre que deux lignes sur dix-sept', (
    tester,
  ) async {
    final vue = tester.platformDispatcher.views.first;
    vue.physicalSize = const Size(1000, 4000);
    vue.devicePixelRatio = 1.0;
    addTearDown(() {
      vue.resetPhysicalSize();
      vue.resetDevicePixelRatio();
    });

    final actuel = providers.firstWhere((p) => p.id == 'zettle');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ComparisonTableScreen(
          volumeMensuel: 8000,
          providers: providers,
          providerActuel: actuel,
          entitlement: Entitlement(debloque: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Le prestataire actuel et la meilleure offre restent chiffrés ;
    // tout le reste est masqué. Quinze lignes verrouillées, c'est la
    // proportion qu'a prise le paywall en passant de sept à dix-sept.
    expect(find.byType(MaskedAmount), findsNWidgets(15));
  });

  testWidgets('le classement complet est cohérent une fois débloqué', (
    tester,
  ) async {
    final classement =
        calculator.classer(providers: providers, volumeMensuel: 8000);

    expect(classement, hasLength(17));
    // Trié du moins cher au plus cher, sans exception.
    for (var i = 1; i < classement.length; i++) {
      expect(
        classement[i].totalMensuel,
        greaterThanOrEqualTo(classement[i - 1].totalMensuel),
        reason: '${classement[i].provider.nomComplet} mal classé',
      );
    }
    // Toute ligne du classement est chiffrable : une offre sans montant
    // n'aurait rien à faire dans un comparateur.
    for (final b in classement) {
      expect(b.totalMensuel, greaterThan(0), reason: b.provider.nomComplet);
    }
  });
}

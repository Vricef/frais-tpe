import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/services/pdf_report_service.dart';
import 'package:intl/date_symbol_data_local.dart';

const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire actuel',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
  fraisMensuels: 9,
);
const _sumupPlus = TpeProvider(
  id: 'sumup_plus',
  nom: 'SumUp',
  offre: 'Paiements Plus',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.89,
  fraisMensuels: 19,
);
const _square = TpeProvider(
  id: 'square',
  nom: 'Square',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.65,
);
const _banque = TpeProvider(
  id: 'banque',
  nom: 'Banque Régionale',
  type: ProviderType.banquePro,
  fourchetteMin: 0.9,
  fourchetteMax: 1.8,
);

void main() {
  const calculator = FeeCalculator();
  const service = PdfReportService();

  setUpAll(() async {
    // Nécessaire pour rootBundle : la police du rapport est un asset.
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  test('le document embarque une police couvrant « € » et « — »', () async {
    // Les polices standard d'un PDF ne contiennent ni l'euro ni le tiret
    // cadratin : sans police embarquée, ces caractères disparaissent du
    // document et les montants s'impriment sans unité.
    final providers = [_actuel, _sumupPlus];
    final resultat = calculator.comparer(
      actuel: _actuel,
      candidats: providers,
      volumeMensuel: 4200,
    )!;

    final octets = await service.construire(
      resultat: resultat,
      classement: calculator.classer(
        providers: providers,
        volumeMensuel: 4200,
      ),
      volumeMensuel: 4200,
      date: DateTime(2026, 8, 6),
    );

    // La police est embarquée sous forme de flux TrueType.
    final contenu = String.fromCharCodes(octets);
    expect(
      contenu.contains('FontFile2') || contenu.contains('TrueType'),
      isTrue,
      reason: 'aucune police embarquée : « € » serait absent du rendu',
    );
  });

  test('produit un PDF valide et non vide', () async {
    final providers = [_actuel, _sumupPlus, _square, _banque];
    final resultat = calculator.comparer(
      actuel: _actuel,
      candidats: providers,
      volumeMensuel: 4200,
    )!;
    final classement = calculator.classer(
      providers: providers,
      volumeMensuel: 4200,
    );

    final octets = await service.construire(
      resultat: resultat,
      classement: classement,
      volumeMensuel: 4200,
      date: DateTime(2026, 8, 6),
    );

    expect(octets.length, greaterThan(1000));
    // En-tête de fichier PDF.
    expect(String.fromCharCodes(octets.take(5)), '%PDF-');

    // Écrit le fichier pour inspection visuelle pendant la mise au point.
    final sortie = Directory.systemTemp.createTempSync('frais_tpe_pdf');
    File('${sortie.path}/rapport.pdf').writeAsBytesSync(octets);
    // ignore: avoid_print
    print('PDF écrit : ${sortie.path}/rapport.pdf');
  });

  test('un classement très long ne fait pas échouer la mise en page', () async {
    // Les blocs insécables lèvent PdfTooBigPageException s'ils dépassent
    // une page : avec 60 prestataires en base, le tableau doit pouvoir se
    // répartir sur plusieurs pages.
    final nombreux = [
      _actuel,
      for (var i = 0; i < 60; i++)
        TpeProvider(
          id: 'p$i',
          nom: 'Prestataire $i',
          type: ProviderType.processeurPaiement,
          fraisTransactionCb: 1 + i * 0.01,
        ),
    ];

    final resultat = calculator.comparer(
      actuel: _actuel,
      candidats: nombreux,
      volumeMensuel: 4200,
    )!;

    final octets = await service.construire(
      resultat: resultat,
      classement: calculator.classer(
        providers: nombreux,
        volumeMensuel: 4200,
      ),
      volumeMensuel: 4200,
      date: DateTime(2026, 8, 6),
    );

    expect(octets.length, greaterThan(1000));
  });

  test('les trois variantes produisent chacune un PDF', () async {
    // Économie significative, faible, et déjà optimal : les trois
    // branches de template doivent se composer sans erreur de mise en
    // page (une variante plus courte ne doit pas casser le document).
    final cas = <String, (TpeProvider, List<TpeProvider>)>{
      'significative': (_actuel, [_actuel, _sumupPlus]),
      'faible': (
        const TpeProvider(
          id: 'actuel',
          nom: 'Actuel',
          type: ProviderType.processeurPaiement,
          fraisTransactionCb: 1.70,
        ),
        [
          const TpeProvider(
            id: 'actuel',
            nom: 'Actuel',
            type: ProviderType.processeurPaiement,
            fraisTransactionCb: 1.70,
          ),
          const TpeProvider(
            id: 'autre',
            nom: 'Autre',
            type: ProviderType.processeurPaiement,
            fraisTransactionCb: 1.65,
          ),
        ]
      ),
      'optimal': (
        _sumupPlus,
        [_sumupPlus, _actuel],
      ),
    };

    for (final entree in cas.entries) {
      final (actuel, providers) = entree.value;
      final resultat = calculator.comparer(
        actuel: actuel,
        candidats: providers,
        volumeMensuel: 4200,
      )!;
      final classement = calculator.classer(
        providers: providers,
        volumeMensuel: 4200,
      );

      final octets = await service.construire(
        resultat: resultat,
        classement: classement,
        volumeMensuel: 4200,
        date: DateTime(2026, 8, 6),
      );

      expect(
        octets.length,
        greaterThan(1000),
        reason: 'la variante ${entree.key} doit produire un document',
      );
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/provider_detail_screen.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('une fintech affiche sa grille tarifaire chiffrée', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProviderDetailScreen(
          provider: TpeProvider(
            id: 'sumup',
            nom: 'SumUp',
            type: ProviderType.processeurPaiement,
            fraisTransactionCb: 1.75,
            fraisMensuels: 9,
          ),
          volumeMensuel: 4200,
        ),
      ),
    );

    expect(find.text('SumUp'), findsOneWidget);
    expect(find.text('Processeur de paiement'), findsOneWidget);
    expect(find.text('GRILLE TARIFAIRE'), findsOneWidget);
    // 4200 * 1,75% + 9 = 82,50
    expect(find.textContaining('82,50'), findsWidgets);
    expect(find.text('1,75 %'), findsOneWidget);
    // Une fintech n'affiche pas de fourchette de négociation.
    expect(find.text('TARIF NÉGOCIÉ'), findsNothing);
  });

  testWidgets('une banque affiche une fourchette, pas un chiffre unique', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProviderDetailScreen(
          provider: TpeProvider(
            id: 'banque',
            nom: 'Banque Régionale',
            type: ProviderType.banquePro,
            fourchetteMin: 0.9,
            fourchetteMax: 1.8,
          ),
          volumeMensuel: 4200,
        ),
      ),
    );

    expect(find.text('Banque professionnelle'), findsOneWidget);
    expect(find.text('TARIF NÉGOCIÉ'), findsOneWidget);
    expect(
      find.text('Commission généralement entre 0,9 % et 1,8 %'),
      findsOneWidget,
    );
    expect(find.text('GRILLE TARIFAIRE'), findsNothing);
  });

  testWidgets('la date du relevé est affichée quand la source est connue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ProviderDetailScreen(
          provider: TpeProvider(
            id: 'sumup',
            nom: 'SumUp',
            type: ProviderType.processeurPaiement,
            fraisTransactionCb: 1.75,
            source: 'vérifiée',
            derniereMaj: DateTime(2026, 7, 28),
          ),
          volumeMensuel: 1000,
        ),
      ),
    );

    expect(
      find.text(
        'Vérifié sur le site officiel du prestataire, le 28 juillet 2026.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sans source renseignée, aucune mention trompeuse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProviderDetailScreen(
          provider: TpeProvider(
            id: 'sumup',
            nom: 'SumUp',
            type: ProviderType.processeurPaiement,
            fraisTransactionCb: 1.75,
          ),
          volumeMensuel: 1000,
        ),
      ),
    );

    expect(find.textContaining('Vérifié sur le site officiel'), findsNothing);
  });

  testWidgets('le panier moyen saisi change le coût des frais fixes', (
    tester,
  ) async {
    const provider = TpeProvider(
      id: 'p',
      nom: 'P',
      type: ProviderType.processeurPaiement,
      fraisFixeTransaction: 0.10,
    );

    // 1000 € / panier 10 € = 100 transactions * 0,10 = 10,00 €
    await tester.pumpWidget(
      _wrap(
        const ProviderDetailScreen(
          provider: provider,
          volumeMensuel: 1000,
          panierMoyen: 10,
        ),
      ),
    );
    expect(find.textContaining('10,00'), findsWidgets);

    // 1000 € / panier 50 € = 20 transactions * 0,10 = 2,00 €
    await tester.pumpWidget(
      _wrap(
        const ProviderDetailScreen(
          provider: provider,
          volumeMensuel: 1000,
          panierMoyen: 50,
        ),
      ),
    );
    expect(find.textContaining('2,00'), findsWidgets);
  });
}

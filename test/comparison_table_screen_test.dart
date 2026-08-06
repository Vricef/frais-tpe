import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/comparison_table_screen.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Même formateur que l'écran : en fr_FR, intl sépare le montant du « € »
/// par une espace insécable, qu'une chaîne écrite à la main ne reproduit
/// pas.
final _euro = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);

const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 2.0,
);
const _meilleur = TpeProvider(
  id: 'meilleur',
  nom: 'Le moins cher',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.0,
);
const _banque = TpeProvider(
  id: 'banque',
  nom: 'Banque Régionale',
  type: ProviderType.banquePro,
  fourchetteMin: 1.4,
  fourchetteMax: 1.6,
);

Widget _wrap({List<TpeProvider> providers = const [_actuel, _meilleur]}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ComparisonTableScreen(
      volumeMensuel: 1000,
      providers: providers,
      providerActuel: _actuel,
    ),
  );
}

void main() {
  testWidgets('affiche le nombre d\'offres comparées', (tester) async {
    await tester.pumpWidget(_wrap(providers: const [_actuel, _meilleur, _banque]));

    final volume = NumberFormat.decimalPattern('fr_FR').format(1000);
    expect(find.text('3 offres comparées'), findsOneWidget);
    expect(find.text('Pour $volume € encaissés par mois'), findsOneWidget);
  });

  testWidgets('étiquette la meilleure offre et celle de l\'utilisateur', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Meilleure offre'), findsOneWidget);
    expect(find.text('Votre offre'), findsOneWidget);
  });

  testWidgets("affiche l'écart par rapport à l'offre actuelle", (tester) async {
    await tester.pumpWidget(_wrap());

    // Actuel : 2% de 1000 = 20,00 ; meilleur : 1% = 10,00 → écart -10,00
    expect(find.text('- ${_euro.format(10)}'), findsOneWidget);
    // Pas d'écart affiché sur sa propre ligne.
    expect(find.text('- ${_euro.format(0)}'), findsNothing);
  });

  testWidgets('signale les coûts estimés des banques par « ≈ »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(providers: const [_actuel, _banque]));

    // Milieu de fourchette : 1,5% de 1000 = 15,00
    expect(find.text('≈ ${_euro.format(15)}'), findsOneWidget);
    expect(find.textContaining('ne publient pas de grille fixe'), findsOneWidget);
  });

  testWidgets('sans banque, aucune légende d\'estimation', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.textContaining('ne publient pas de grille fixe'), findsNothing);
  });

  testWidgets('une liste vide affiche un message plutôt qu\'un tableau vide', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(providers: const []));

    expect(find.text('Aucune offre à comparer pour le moment.'), findsOneWidget);
  });
}

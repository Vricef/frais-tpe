import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/history_screen.dart';
import 'package:frais_tpe/screens/result_screen.dart';
import 'package:frais_tpe/services/calculation_store.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/firestore_service.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
  fraisMensuels: 9,
);
const _meilleur = TpeProvider(
  id: 'sumup',
  nom: 'SumUp',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.89,
);

class _FakeFirestore implements FirestoreService {
  _FakeFirestore(this.providers);
  final List<TpeProvider> providers;

  @override
  Future<List<TpeProvider>> getProviders() async => providers;

  @override
  Stream<List<TpeProvider>> watchProviders() => Stream.value(providers);

  @override
  Future<TpeProvider?> getProvider(String id) async =>
      providers.where((p) => p.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _resultat(Entitlement entitlement, CalculationStore store) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ResultScreen(
      volumeMensuel: 4200,
      providerActuel: _actuel,
      providers: const [_actuel, _meilleur],
      entitlement: entitlement,
      store: store,
    ),
  );
}

Future<void> _appuyerSauvegarde(WidgetTester tester) async {
  final bouton = find.text('Enregistrer ce calcul');
  await tester.ensureVisible(bouton);
  await tester.pumpAndSettle();
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sans achat, la sauvegarde mène au paywall et n\'écrit rien', (
    tester,
  ) async {
    final store = PrefsCalculationStore();
    await tester.pumpWidget(_resultat(Entitlement(debloque: false), store));

    await _appuyerSauvegarde(tester);

    expect(find.text('Débloquez la comparaison complète'), findsOneWidget);
    expect(store.calculs, isEmpty);
  });

  testWidgets('une fois débloqué, le calcul est enregistré avec son libellé', (
    tester,
  ) async {
    final store = PrefsCalculationStore();
    await tester.pumpWidget(_resultat(Entitlement(debloque: true), store));

    await _appuyerSauvegarde(tester);

    // Un libellé est proposé d'avance ; on le valide tel quel.
    expect(find.text('Enregistrer ce calcul'), findsWidgets);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(store.calculs, hasLength(1));
    final calcul = store.calculs.single;
    expect(calcul.volumeMensuel, 4200);
    expect(calcul.providerActuelId, 'actuel');
    expect(calcul.libelle, contains('Mon prestataire'));
  });

  testWidgets('l\'historique liste les calculs enregistrés', (tester) async {
    final store = PrefsCalculationStore();
    await tester.pumpWidget(_resultat(Entitlement(debloque: true), store));
    await _appuyerSauvegarde(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HistoryScreen(
          store: store,
          entitlement: Entitlement(debloque: true),
          firestoreService: _FakeFirestore(const [_actuel, _meilleur]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vos calculs'), findsOneWidget);
    expect(find.textContaining('Mon prestataire'), findsWidgets);
  });

  testWidgets('un historique vide invite à sauvegarder plutôt qu\'un blanc', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HistoryScreen(
          store: PrefsCalculationStore(),
          entitlement: Entitlement(debloque: true),
          firestoreService: _FakeFirestore(const [_actuel]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun calcul sauvegardé'), findsOneWidget);
  });

  testWidgets(
    'rouvrir un calcul dont le prestataire a disparu prévient au lieu de '
    'donner un résultat faux',
    (tester) async {
      final store = PrefsCalculationStore();
      await tester.pumpWidget(_resultat(Entitlement(debloque: true), store));
      await _appuyerSauvegarde(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      // Laisse le SnackBar « Calcul enregistré » se retirer : tant qu'il
      // est affiché, le message suivant est mis en file d'attente derrière
      // lui. `pumpAndSettle` ne suffit pas — une fois son animation
      // terminée, plus aucune frame n'est planifiée.
      await tester.pump(const Duration(seconds: 5));

      // La base ne contient plus le prestataire de ce calcul.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HistoryScreen(
            store: store,
            entitlement: Entitlement(debloque: true),
            firestoreService: _FakeFirestore(const [_meilleur]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mon prestataire').first);
      // `pumpAndSettle` traverserait tout le cycle du SnackBar, disparition
      // automatique comprise : le message aurait déjà quitté l'écran au
      // moment de l'assertion.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining("n'est plus disponible"),
        findsOneWidget,
      );
    },
  );
}

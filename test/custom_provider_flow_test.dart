import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/models/saved_calculation.dart';
import 'package:frais_tpe/screens/comparison_table_screen.dart';
import 'package:frais_tpe/screens/volume_input_screen.dart';
import 'package:frais_tpe/services/calculation_store.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/firestore_service.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deux offres du même prestataire : le cas qui rendait le sélecteur
/// ambigu tant qu'il n'affichait que `nom`.
const _sumup = TpeProvider(
  id: 'sumup',
  nom: 'SumUp',
  offre: 'Sans abonnement',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
);
const _sumupPlus = TpeProvider(
  id: 'sumup_paiements_plus',
  nom: 'SumUp',
  offre: 'Paiements Plus',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.89,
  fraisMensuels: 19,
);

const _entreeManuelle = 'Mon prestataire n\'est pas dans la liste';

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

Widget _saisie() {
  return MaterialApp(
    theme: AppTheme.light,
    home: VolumeInputScreen(
      entitlement: Entitlement(),
      store: PrefsCalculationStore(),
      firestoreService: _FakeFirestore(const [_sumup, _sumupPlus]),
    ),
  );
}

Future<void> _ouvrirSelecteur(WidgetTester tester) async {
  final selecteur = find.byType(DropdownButton<TpeProvider>);
  await tester.ensureVisible(selecteur);
  await tester.pumpAndSettle();
  await tester.tap(selecteur);
  await tester.pumpAndSettle();
}

Future<void> _valider(WidgetTester tester, String libelle) async {
  final bouton = find.text(libelle);
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

  /// La fenêtre de test fait 600 px de haut par défaut, trop peu pour
  /// l'écran de saisie : le sélecteur et le bouton du formulaire s'y
  /// retrouvent hors de portée du tap.
  setUp(() {
    final vue = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    vue.physicalSize = const Size(1000, 2200);
    vue.devicePixelRatio = 1.0;
    addTearDown(() {
      vue.resetPhysicalSize();
      vue.resetDevicePixelRatio();
    });
  });

  group('saisie du prestataire actuel', () {
    testWidgets('deux offres du même prestataire restent distinguables', (
      tester,
    ) async {
      await tester.pumpWidget(_saisie());
      await tester.pumpAndSettle();
      await _ouvrirSelecteur(tester);

      expect(find.text('SumUp — Sans abonnement'), findsWidgets);
      expect(find.text('SumUp — Paiements Plus'), findsWidgets);
      // Le nom nu ne suffirait pas à choisir entre les deux offres.
      expect(find.text('SumUp'), findsNothing);
    });

    testWidgets("l'entrée de saisie manuelle est dans le sélecteur", (
      tester,
    ) async {
      await tester.pumpWidget(_saisie());
      await tester.pumpAndSettle();

      // Elle n'apparaît qu'une fois le sélecteur ouvert : c'est là que
      // l'utilisateur constate que son prestataire manque.
      expect(find.text(_entreeManuelle), findsNothing);
      await _ouvrirSelecteur(tester);
      expect(find.text(_entreeManuelle), findsOneWidget);
    });

    testWidgets('un prestataire saisi devient le prestataire actuel', (
      tester,
    ) async {
      await tester.pumpWidget(_saisie());
      await tester.pumpAndSettle();
      await _ouvrirSelecteur(tester);
      await tester.tap(find.text(_entreeManuelle));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Mon prestataire'),
        'Smile&Pay',
      );
      await tester.enterText(find.widgetWithText(TextField, '1,75'), '1,6');
      await tester.pumpAndSettle();
      await _valider(tester, 'Utiliser ce prestataire');

      // Il occupe la place du prestataire actuel dans le sélecteur.
      expect(find.text('Smile&Pay'), findsOneWidget);
      expect(find.text('Choisir…'), findsNothing);
    });

    testWidgets('abandonner le formulaire ne change pas la sélection', (
      tester,
    ) async {
      await tester.pumpWidget(_saisie());
      await tester.pumpAndSettle();
      await _ouvrirSelecteur(tester);
      await tester.tap(find.text('SumUp — Paiements Plus').last);
      await tester.pumpAndSettle();

      await _ouvrirSelecteur(tester);
      await tester.tap(find.text(_entreeManuelle));
      await tester.pumpAndSettle();
      // Fermeture sans valider.
      Navigator.of(tester.element(find.byType(TextField).first)).pop();
      await tester.pumpAndSettle();

      expect(find.text('SumUp — Paiements Plus'), findsOneWidget);
    });

    testWidgets('rouvrir le formulaire pré-remplit les tarifs saisis', (
      tester,
    ) async {
      await tester.pumpWidget(_saisie());
      await tester.pumpAndSettle();
      await _ouvrirSelecteur(tester);
      await tester.tap(find.text(_entreeManuelle));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '1,75'), '1,6');
      await tester.pumpAndSettle();
      await _valider(tester, 'Utiliser ce prestataire');

      await _ouvrirSelecteur(tester);
      await tester.tap(find.text(_entreeManuelle));
      await tester.pumpAndSettle();

      // Sans pré-remplissage, corriger un taux obligerait à tout ressaisir.
      expect(find.text('Corriger vos tarifs'), findsOneWidget);
      expect(find.text('1,6'), findsOneWidget);
    });
  });

  testWidgets('les noms longs ne débordent pas sur un écran étroit', (
    tester,
  ) async {
    // 360 px : la largeur d'un téléphone d'entrée de gamme, la plus
    // contrainte du parc. Un débordement de RenderFlex y ferait échouer
    // le test, ce qu'une fenêtre large masquerait.
    final vue = tester.platformDispatcher.views.first;
    vue.physicalSize = const Size(360, 800);
    vue.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: VolumeInputScreen(
          entitlement: Entitlement(),
          store: PrefsCalculationStore(),
          firestoreService: _FakeFirestore(const [
            TpeProvider(
              id: 'long',
              nom: 'Crédit Agricole Alpes Provence',
              offre: 'Monétique professionnelle négociée',
              type: ProviderType.processeurPaiement,
              fraisTransactionCb: 1.2,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _ouvrirSelecteur(tester);

    expect(find.text(_entreeManuelle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('tableau comparatif', () {
    testWidgets("n'offre plus d'ajout de prestataire", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ComparisonTableScreen(
            volumeMensuel: 8000,
            providers: const [_sumup, _sumupPlus],
            providerActuel: _sumup,
            entitlement: Entitlement(debloque: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La saisie a lieu à l'écran précédent : la proposer ici obligeait
      // à revenir en arrière pour déclarer son propre prestataire.
      expect(find.textContaining("n'est pas listé"), findsNothing);
    });
  });

  group('sauvegarde', () {
    test('un prestataire saisi survit à un aller-retour JSON', () {
      const perso = TpeProvider(
        id: 'perso',
        nom: 'Smile&Pay',
        type: ProviderType.processeurPaiement,
        fraisTransactionCb: 1.6,
        fraisFixeTransaction: 0.1,
        fraisMensuels: 12,
        estPersonnalise: true,
      );
      final calcul = SavedCalculation(
        id: '1',
        libelle: 'Boutique',
        volumeMensuel: 8000,
        providerActuelId: 'perso',
        providerPerso: perso,
        creeLe: DateTime(2026, 8, 31),
      );

      final relu = SavedCalculation.decodeListe(
        SavedCalculation.encodeListe([calcul]),
      ).single;

      // Sans ces tarifs, l'historique ne retrouverait rien en base et le
      // calcul serait irrécupérable.
      expect(relu.providerPerso, isNotNull);
      expect(relu.providerPerso!.nom, 'Smile&Pay');
      expect(relu.providerPerso!.fraisTransactionCb, 1.6);
      expect(relu.providerPerso!.fraisFixeTransaction, 0.1);
      expect(relu.providerPerso!.fraisMensuels, 12);
      expect(relu.providerPerso!.estPersonnalise, isTrue);
    });

    test('un calcul sur un prestataire de la base ne stocke rien de plus', () {
      final calcul = SavedCalculation(
        id: '1',
        libelle: 'Boutique',
        volumeMensuel: 8000,
        providerActuelId: 'sumup',
        creeLe: DateTime(2026, 8, 31),
      );

      expect(calcul.toJson().containsKey('provider_perso'), isFalse);
      expect(
        SavedCalculation.decodeListe(
          SavedCalculation.encodeListe([calcul]),
        ).single.providerPerso,
        isNull,
      );
    });
  });
}

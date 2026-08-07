import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/main.dart';
import 'package:frais_tpe/screens/startup_error_screen.dart';
import 'package:frais_tpe/services/calculation_store.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sans erreur de démarrage, l\'app ouvre l\'accueil', (
    tester,
  ) async {
    await tester.pumpWidget(FraisTpeApp());

    expect(find.text('Frais TPE'), findsOneWidget);
    expect(find.byType(StartupErrorScreen), findsNothing);
  });

  testWidgets(
    'une initialisation Firebase en échec affiche une explication, pas un '
    'écran noir',
    (tester) async {
      await tester.pumpWidget(
        FraisTpeApp(
          entitlement: Entitlement(),
          store: PrefsCalculationStore(),
          erreurDemarrage: Exception('no Firebase App has been created'),
        ),
      );

      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(find.textContaining("n'a pas pu"), findsOneWidget);
      // Quelque chose est rendu : c'est tout l'objet de cet écran.
      expect(find.text('Frais TPE'), findsOneWidget);
    },
  );

  testWidgets('le détail technique reste masqué hors mode debug', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Enveloppe(
        child: StartupErrorScreen(
          erreur: 'FirebaseException: config manquante',
          afficherDetail: false,
        ),
      ),
    );

    expect(find.text('DÉTAIL TECHNIQUE'), findsNothing);
    expect(find.textContaining('config manquante'), findsNothing);
  });

  testWidgets('en debug, le détail oriente vers flutterfire configure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Enveloppe(
        child: StartupErrorScreen(
          erreur: 'FirebaseException: config manquante',
          afficherDetail: true,
        ),
      ),
    );

    expect(find.text('DÉTAIL TECHNIQUE'), findsOneWidget);
    expect(find.textContaining('config manquante'), findsOneWidget);
    expect(find.textContaining('flutterfire configure'), findsOneWidget);
  });
}

class _Enveloppe extends StatelessWidget {
  const _Enveloppe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.light, home: child);
  }
}

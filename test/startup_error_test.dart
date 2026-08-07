import 'dart:async';

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

  testWidgets('une initialisation réussie ouvre l\'accueil', (tester) async {
    await tester.pumpWidget(FraisTpeApp(initialisation: () async {}));
    await tester.pumpAndSettle();

    expect(find.text('Comparer mes frais'), findsOneWidget);
    expect(find.byType(StartupErrorScreen), findsNothing);
  });

  testWidgets('quelque chose est affiché pendant l\'initialisation', (
    tester,
  ) async {
    // Le point de tout ce mécanisme : l'app ne doit jamais rester sur un
    // écran vide, même le temps du démarrage.
    final bloque = Completer<void>();
    await tester.pumpWidget(FraisTpeApp(initialisation: () => bloque.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Frais TPE'), findsOneWidget);

    bloque.complete();
    await tester.pumpAndSettle();
    expect(find.text('Comparer mes frais'), findsOneWidget);
  });

  testWidgets(
    'une initialisation Firebase en échec affiche une explication, pas un '
    'écran noir',
    (tester) async {
      await tester.pumpWidget(
        FraisTpeApp(
          entitlement: Entitlement(),
          store: PrefsCalculationStore(),
          initialisation: () async =>
              throw Exception('no Firebase App has been created'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(find.textContaining("n'a pas pu"), findsOneWidget);
      // Quelque chose est rendu : c'est tout l'objet de cet écran.
      expect(find.text('Frais TPE'), findsOneWidget);
    },
  );

  testWidgets('« Réessayer » relance l\'initialisation', (tester) async {
    var tentatives = 0;
    await tester.pumpWidget(
      FraisTpeApp(
        initialisation: () async {
          tentatives++;
          if (tentatives == 1) throw Exception('échec passager');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StartupErrorScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Réessayer'));
    await tester.pumpAndSettle();

    expect(tentatives, 2);
    expect(find.text('Comparer mes frais'), findsOneWidget);
  });

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

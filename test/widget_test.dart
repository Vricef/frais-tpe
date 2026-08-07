import 'package:flutter_test/flutter_test.dart';

import 'package:frais_tpe/main.dart';

void main() {
  testWidgets('FraisTpeApp affiche le titre', (WidgetTester tester) async {
    // Initialisation neutralisée : la vraie appelle Firebase, absent des
    // tests. Le démarrage réel est couvert par startup_error_test.dart.
    await tester.pumpWidget(FraisTpeApp(initialisation: () async {}));
    await tester.pumpAndSettle();

    expect(find.text('Frais TPE'), findsOneWidget);
  });
}

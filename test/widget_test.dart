import 'package:flutter_test/flutter_test.dart';

import 'package:frais_tpe/main.dart';

void main() {
  testWidgets('FraisTpeApp affiche le titre', (WidgetTester tester) async {
    await tester.pumpWidget(const FraisTpeApp());

    expect(find.text('Frais TPE'), findsOneWidget);
  });
}

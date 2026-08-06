import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/result_screen.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/services/report_sharing.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 1.75,
  fraisMensuels: 9,
);
const _meilleur = TpeProvider(
  id: 'meilleur',
  nom: 'SumUp',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.89,
);

/// Capture les partages au lieu d'ouvrir la feuille système.
class _SharingEspion implements ReportSharing {
  final documents = <Uint8List>[];

  @override
  Future<void> partager({
    required Uint8List document,
    required String nomFichier,
  }) async {
    documents.add(document);
  }
}

Widget _ecran(Entitlement entitlement, ReportSharing sharing) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ResultScreen(
      volumeMensuel: 4200,
      providerActuel: _actuel,
      providers: const [_actuel, _meilleur],
      entitlement: entitlement,
      sharing: sharing,
    ),
  );
}

/// L'écran défile : le bouton PDF est sous la ligne de flottaison de la
/// fenêtre de test par défaut (600 px de haut).
Future<void> _appuyerSurExport(WidgetTester tester) async {
  final bouton = find.text('Recevoir le détail en PDF');
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

  testWidgets('sans achat, le bouton PDF mène au paywall et n\'exporte rien', (
    tester,
  ) async {
    final espion = _SharingEspion();
    await tester.pumpWidget(_ecran(Entitlement(debloque: false), espion));

    await _appuyerSurExport(tester);

    expect(find.text('Débloquez la comparaison complète'), findsOneWidget);
    expect(
      espion.documents,
      isEmpty,
      reason: 'aucun rapport ne doit être produit avant l\'achat',
    );
  });

  testWidgets('le bouton porte un cadenas tant que l\'achat n\'est pas fait', (
    tester,
  ) async {
    final entitlement = Entitlement(debloque: false);
    await tester.pumpWidget(_ecran(entitlement, _SharingEspion()));
    await tester.ensureVisible(find.text('Recevoir le détail en PDF'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsWidgets);

    entitlement.debloquer();
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('une fois débloqué, le bouton produit et partage le rapport', (
    tester,
  ) async {
    final espion = _SharingEspion();
    await tester.pumpWidget(_ecran(Entitlement(debloque: true), espion));

    await _appuyerSurExport(tester);

    expect(espion.documents, hasLength(1));
    expect(String.fromCharCodes(espion.documents.single.take(5)), '%PDF-');
  });

  testWidgets('l\'achat depuis le paywall enchaîne sur l\'export', (
    tester,
  ) async {
    // L'utilisateur ne doit pas avoir à ré-appuyer sur le bouton après
    // avoir payé : c'est le geste qu'il venait de faire.
    final espion = _SharingEspion();
    final entitlement = Entitlement(debloque: false);
    await tester.pumpWidget(_ecran(entitlement, espion));

    await _appuyerSurExport(tester);

    await tester.tap(find.text('Débloquer pour 3,99 €'));
    await tester.pumpAndSettle();

    expect(espion.documents, hasLength(1));
  });
}

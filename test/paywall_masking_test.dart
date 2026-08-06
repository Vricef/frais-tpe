import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/screens/comparison_table_screen.dart';
import 'package:frais_tpe/services/entitlement.dart';
import 'package:frais_tpe/theme/app_theme.dart';
import 'package:frais_tpe/widgets/masked_amount.dart';
import 'package:intl/intl.dart';

/// Vérifie que le masquage du paywall ne laisse rien de déductible.
///
/// Les montants masqués sont à des ordres de grandeur très différents
/// (2 chiffres vs 4) : si le placeholder trahissait la valeur d'une
/// manière ou d'une autre — largeur, texte résiduel, écart chiffré — les
/// tests ci-dessous le verraient.
const _actuel = TpeProvider(
  id: 'actuel',
  nom: 'Mon prestataire',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 5.0, // 500,00 € pour 10 000 €
);
const _meilleur = TpeProvider(
  id: 'meilleur',
  nom: 'Le moins cher',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.1, // 10,00 €
);
const _milieuPetit = TpeProvider(
  id: 'milieu_petit',
  nom: 'Offre B',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 0.5, // 50,00 € — 2 chiffres
);
const _milieuGros = TpeProvider(
  id: 'milieu_gros',
  nom: 'Offre C',
  type: ProviderType.processeurPaiement,
  fraisTransactionCb: 3.0, // 300,00 € — 3 chiffres
);
const _banqueMasquee = TpeProvider(
  id: 'banque',
  nom: 'Banque Régionale',
  type: ProviderType.banquePro,
  fourchetteMin: 1.0,
  fourchetteMax: 2.0, // 150,00 €
);

const _volume = 10000.0;

Widget _tableau({required bool debloque}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ComparisonTableScreen(
      volumeMensuel: _volume,
      providers: const [
        _actuel,
        _meilleur,
        _milieuPetit,
        _milieuGros,
        _banqueMasquee,
      ],
      providerActuel: _actuel,
      entitlement: Entitlement(debloque: debloque),
    ),
  );
}

final _euro = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);

/// Tous les textes présents dans l'arbre de widgets rendu.
List<String> _textesAffiches(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .toList();
}

void main() {
  group('masquage du paywall', () {
    testWidgets('les montants masqués sont absents de l\'arbre de widgets', (
      tester,
    ) async {
      await tester.pumpWidget(_tableau(debloque: false));
      final textes = _textesAffiches(tester).join('|');

      // Visibles en gratuit : la meilleure offre et celle de l'utilisateur.
      expect(textes, contains(_euro.format(10)));
      expect(textes, contains(_euro.format(500)));

      // Masqués : aucune trace, sous aucune forme.
      for (final cache in [50, 300, 150]) {
        expect(
          textes,
          isNot(contains(_euro.format(cache))),
          reason: 'le montant masqué $cache ne doit apparaître nulle part',
        );
      }
    });

    testWidgets('aucun écart chiffré ne permet de retrouver un montant', (
      tester,
    ) async {
      await tester.pumpWidget(_tableau(debloque: false));
      final textes = _textesAffiches(tester).join('|');

      // 500 - 50 = 450, 500 - 300 = 200, 500 - 150 = 350 : si l'écart
      // était affiché sur une ligne masquée, le montant s'en déduirait.
      for (final ecart in [450, 200, 350]) {
        expect(
          textes,
          isNot(contains(_euro.format(ecart))),
          reason: 'un écart de $ecart trahirait le montant masqué',
        );
      }

      // L'écart de la meilleure offre, lui, reste affiché : 500 - 10 = 490.
      expect(textes, contains(_euro.format(490)));
    });

    testWidgets('tous les placeholders ont exactement la même taille', (
      tester,
    ) async {
      await tester.pumpWidget(_tableau(debloque: false));

      final tailles = tester
          .renderObjectList<RenderBox>(find.byType(MaskedAmount))
          .map((box) => box.size)
          .toList();

      expect(tailles.length, 3, reason: '3 offres doivent être masquées');
      expect(
        tailles.toSet().length,
        1,
        reason: 'des largeurs différentes trahiraient l\'ordre de grandeur',
      );
    });

    testWidgets('le placeholder n\'expose pas le montant en sémantique', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_tableau(debloque: false));

      // Aucun nœud de sémantique ne doit porter un montant masqué.
      for (final cache in [50, 300, 150]) {
        expect(
          find.bySemanticsLabel(RegExp(_euro.format(cache))),
          findsNothing,
          reason: 'un lecteur d\'écran ne doit pas énoncer $cache',
        );
      }
      expect(find.bySemanticsLabel('Montant verrouillé'), findsWidgets);

      handle.dispose();
    });

    testWidgets('une ligne verrouillée ouvre le paywall, pas la fiche', (
      tester,
    ) async {
      await tester.pumpWidget(_tableau(debloque: false));

      await tester.tap(find.text('Offre C'));
      await tester.pumpAndSettle();

      // La fiche afficherait le coût exact — c'est bien le paywall qui
      // doit s'ouvrir.
      expect(find.text('Débloquez la comparaison complète'), findsOneWidget);
      expect(find.text('GRILLE TARIFAIRE'), findsNothing);
      expect(_textesAffiches(tester).join('|'), isNot(contains(_euro.format(300))));
    });

    testWidgets('une fois débloqué, tous les montants apparaissent', (
      tester,
    ) async {
      await tester.pumpWidget(_tableau(debloque: true));
      final textes = _textesAffiches(tester).join('|');

      for (final montant in [10, 50, 150, 300, 500]) {
        expect(textes, contains(_euro.format(montant)));
      }
      expect(find.byType(MaskedAmount), findsNothing);
    });

    testWidgets(
      "l'ordre des lignes masquées ne dépend pas de leur montant",
      (tester) async {
        // Les offres masquées sont rendues par ordre alphabétique et non
        // par coût. Sans cela, ajouter un prestataire personnalisé — dont
        // l'utilisateur choisit le tarif — et observer où il se place
        // permettrait de retrouver n'importe quel montant masqué par
        // dichotomie.
        await tester.pumpWidget(_tableau(debloque: false));

        final noms = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((t) => ['Banque Régionale', 'Offre B', 'Offre C'].contains(t))
            .toList();

        // Ordre alphabétique : Banque Régionale, Offre B, Offre C.
        // Par coût, ce serait Offre B (50), Banque (150), Offre C (300).
        expect(noms, ['Banque Régionale', 'Offre B', 'Offre C']);
      },
    );

    testWidgets('aucun rang n\'est affiché tant que le tableau est verrouillé', (
      tester,
    ) async {
      // Un rang dirait combien d'offres masquées s'intercalent entre deux
      // montants connus, et donc dans quel intervalle elles se situent.
      await tester.pumpWidget(_tableau(debloque: false));
      final textes = _textesAffiches(tester);

      for (final rang in ['1', '2', '3', '4', '5']) {
        expect(
          textes,
          isNot(contains(rang)),
          reason: 'le rang $rang situerait les offres masquées',
        );
      }

      await tester.pumpWidget(_tableau(debloque: true));
      expect(_textesAffiches(tester), contains('1'));
    });

    testWidgets(
      'un prestataire saisi par l\'utilisateur reste chiffré et ne déplace '
      'pas les lignes masquées',
      (tester) async {
        const perso = TpeProvider(
          id: 'perso_1',
          nom: 'Smile&Pay',
          type: ProviderType.processeurPaiement,
          fraisTransactionCb: 1.6, // 160,00 € — entre deux montants masqués
          estPersonnalise: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: ComparisonTableScreen(
              volumeMensuel: _volume,
              providers: const [
                _actuel,
                _meilleur,
                _milieuPetit,
                _milieuGros,
                _banqueMasquee,
                perso,
              ],
              providerActuel: _actuel,
              entitlement: Entitlement(debloque: false),
            ),
          ),
        );

        final textes = _textesAffiches(tester).join('|');

        // Son montant lui est montré : il en a fourni les taux, le masquer
        // n'aurait rien protégé.
        expect(textes, contains(_euro.format(160)));

        // Les montants masqués le restent, malgré son insertion.
        for (final cache in [50, 300, 150]) {
          expect(textes, isNot(contains(_euro.format(cache))));
        }
        expect(find.byType(MaskedAmount), findsNWidgets(3));
      },
    );

    testWidgets('l\'achat révèle les montants sans quitter le tableau', (
      tester,
    ) async {
      final entitlement = Entitlement();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ComparisonTableScreen(
            volumeMensuel: _volume,
            providers: const [_actuel, _meilleur, _milieuPetit],
            providerActuel: _actuel,
            entitlement: entitlement,
          ),
        ),
      );

      expect(find.byType(MaskedAmount), findsOneWidget);

      entitlement.debloquer();
      await tester.pump();

      expect(find.byType(MaskedAmount), findsNothing);
      expect(_textesAffiches(tester).join('|'), contains(_euro.format(50)));
    });
  });
}

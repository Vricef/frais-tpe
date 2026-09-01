// flutter_test exporte son propre ComparisonResult (comparaison de
// goldens), sans rapport avec le nôtre.
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:frais_tpe/models/fee_breakdown.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/services/fee_calculator.dart';
import 'package:frais_tpe/services/report_templates.dart';
import 'package:intl/date_symbol_data_local.dart';

TpeProvider _p(String id, double commission, {double? mensuel}) {
  return TpeProvider(
    id: id,
    nom: id,
    type: ProviderType.processeurPaiement,
    fraisTransactionCb: commission,
    fraisMensuels: mensuel,
  );
}

void main() {
  const calculator = FeeCalculator();
  const templates = ReportTemplates();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  /// Compare deux offres à 4 200 € de volume.
  ComparisonResult cas(double actuel, double autre) {
    return calculator.comparer(
      actuel: _p('actuel', actuel),
      candidats: [_p('autre', autre)],
      volumeMensuel: 4200,
    )!;
  }

  group('choix de la variante', () {
    test('une économie nette donne la variante significative', () {
      final r = cas(1.75, 0.89);
      expect(
        templates.variantePour(r),
        VarianteRapport.economieSignificative,
      );
    });

    test('une économie sous le seuil donne la variante faible', () {
      // 4200 × (1,75 % − 1,70 %) = 2,10 € par mois.
      final r = cas(1.75, 1.70);
      expect(r.economieMensuelle, lessThan(ReportTemplates.seuilEconomieFaible));
      expect(templates.variantePour(r), VarianteRapport.economieFaible);
    });

    test('aucune économie donne la variante déjà optimal', () {
      final r = cas(1.0, 2.0);
      expect(templates.variantePour(r), VarianteRapport.dejaOptimal);
    });
  });

  group('contenu des variantes', () {
    test('la variante significative annonce le montant et pousse à agir', () {
      final r = cas(1.75, 0.89);
      expect(templates.titre(r), contains('de trop'));
      expect(
        templates.introduction(r, volumeMensuel: 4200, panierMoyen: 35),
        contains("d'économie mensuelle"),
      );
      expect(templates.recommandation(r), contains("s'aligner"));
    });

    test(
      "la variante faible ne présente pas un gain modeste comme une urgence",
      () {
        final r = cas(1.75, 1.70);
        // Le titre ne doit pas alarmer pour 2 € par mois.
        expect(templates.titre(r), isNot(contains('de trop')));
        expect(
          templates.introduction(r, volumeMensuel: 4200, panierMoyen: 35),
          contains('modeste'),
        );
        expect(templates.recommandation(r), contains('Conservez'));
      },
    );

    test('la variante déjà optimal ne fabrique pas un écart', () {
      final r = cas(1.0, 2.0);
      expect(templates.titre(r), contains('déjà au meilleur tarif'));
      expect(
        templates.introduction(r, volumeMensuel: 4200, panierMoyen: 35),
        contains('Aucune des offres comparées ne fait mieux'),
      );
      expect(templates.recommandation(r), contains("n'avez rien à changer"));
    });
  });

  group('note de méthode', () {
    test('mentionne toujours ce que le calcul retient et écarte', () {
      final note = templates.noteMethode(contientEstimationBancaire: false);
      expect(note, contains('en personne'));
      expect(note, contains("prix d'achat du terminal"));
      expect(note, isNot(contains('banques traditionnelles')));
    });

    test('avertit sur les estimations bancaires quand il y en a', () {
      final note = templates.noteMethode(contientEstimationBancaire: true);
      expect(note, contains('banques traditionnelles'));
      expect(note, contains('ordre de grandeur'));
    });
  });

  test('le texte ne dépend que des données, pas du moment de génération', () {
    // Templates pré-écrits, pas de génération IA (§6) : deux appels
    // successifs doivent produire exactement le même texte.
    final r = cas(1.75, 0.89);
    expect(
      templates.introduction(r, volumeMensuel: 4200, panierMoyen: 35),
      templates.introduction(r, volumeMensuel: 4200, panierMoyen: 35),
    );
  });

  test('le pied de page date le rapport', () {
    expect(
      templates.piedDePage(DateTime(2026, 8, 6)),
      contains('6 août 2026'),
    );
  });
}

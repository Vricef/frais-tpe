import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/provider.dart';
import 'package:frais_tpe/services/fee_calculator.dart';

TpeProvider _fintech({
  String id = 'sumup',
  double? commission,
  double? fraisFixe,
  double? mensuel,
}) {
  return TpeProvider(
    id: id,
    nom: id,
    type: ProviderType.processeurPaiement,
    fraisTransactionCb: commission,
    fraisFixeTransaction: fraisFixe,
    fraisMensuels: mensuel,
  );
}

void main() {
  const calculator = FeeCalculator();

  group('calculer', () {
    test('applique la commission proportionnelle au volume', () {
      final result = calculator.calculer(
        provider: _fintech(commission: 1.75),
        volumeMensuel: 4200,
      );

      expect(result.totalMensuel, closeTo(73.50, 0.001));
      expect(result.lignes.single.libelle, 'Commission par paiement');
    });

    test('additionne commission, frais fixe et abonnement', () {
      final result = calculator.calculer(
        provider: _fintech(commission: 1.5, fraisFixe: 0.10, mensuel: 9),
        volumeMensuel: 3500,
        panierMoyen: 35,
      );

      // 3500 * 1.5% = 52.50 ; 100 transactions * 0.10 = 10 ; + 9
      expect(result.totalMensuel, closeTo(71.50, 0.001));
      expect(result.lignes.length, 3);
    });

    test('utilise le panier moyen par défaut si non renseigné', () {
      final avecDefaut = calculator.calculer(
        provider: _fintech(fraisFixe: 0.10),
        volumeMensuel: 3500,
      );
      final explicite = calculator.calculer(
        provider: _fintech(fraisFixe: 0.10),
        volumeMensuel: 3500,
        panierMoyen: FeeCalculator.panierMoyenParDefaut,
      );

      expect(avecDefaut.totalMensuel, explicite.totalMensuel);
    });

    test('ignore les postes absents de la grille tarifaire', () {
      final result = calculator.calculer(
        provider: _fintech(commission: 1.75),
        volumeMensuel: 1000,
      );

      expect(result.lignes.length, 1);
    });

    test('un volume nul ne génère aucun frais de transaction', () {
      final result = calculator.calculer(
        provider: _fintech(commission: 1.75, fraisFixe: 0.10, mensuel: 9),
        volumeMensuel: 0,
      );

      // Seul l'abonnement reste dû.
      expect(result.totalMensuel, closeTo(9, 0.001));
    });

    test('le coût annuel vaut douze mois', () {
      final result = calculator.calculer(
        provider: _fintech(mensuel: 10),
        volumeMensuel: 1000,
      );

      expect(result.totalAnnuel, closeTo(120, 0.001));
    });

    test("une banque traditionnelle est estimée au milieu de sa fourchette", () {
      final banque = TpeProvider(
        id: 'bnp',
        nom: 'BNP',
        type: ProviderType.banquePro,
        fourchetteMin: 1.0,
        fourchetteMax: 2.0,
      );

      final result = calculator.calculer(
        provider: banque,
        volumeMensuel: 1000,
      );

      // Milieu de fourchette = 1.5% de 1000 = 15
      expect(result.totalMensuel, closeTo(15, 0.001));
    });
  });

  group('classer', () {
    test('trie du moins cher au plus cher', () {
      final classement = calculator.classer(
        providers: [
          _fintech(id: 'cher', commission: 2.0),
          _fintech(id: 'pas_cher', commission: 1.0),
          _fintech(id: 'moyen', commission: 1.5),
        ],
        volumeMensuel: 1000,
      );

      expect(
        classement.map((b) => b.provider.id),
        ['pas_cher', 'moyen', 'cher'],
      );
    });

    test('conserve le prestataire actuel dans le classement', () {
      final actuel = _fintech(id: 'actuel', commission: 2.0);
      final classement = calculator.classer(
        providers: [actuel, _fintech(id: 'autre', commission: 1.0)],
        volumeMensuel: 1000,
      );

      expect(classement.length, 2);
      expect(
        classement.map((b) => b.provider.id),
        containsAll(['actuel', 'autre']),
      );
    });

    test('départage les coûts égaux par nom, pour un ordre stable', () {
      final classement = calculator.classer(
        providers: [
          _fintech(id: 'zeta', commission: 1.5),
          _fintech(id: 'alpha', commission: 1.5),
        ],
        volumeMensuel: 1000,
      );

      expect(classement.map((b) => b.provider.id), ['alpha', 'zeta']);
    });

    test('une liste vide donne un classement vide', () {
      expect(
        calculator.classer(providers: const [], volumeMensuel: 1000),
        isEmpty,
      );
    });
  });

  group('comparer', () {
    test('retient le prestataire le moins cher', () {
      final result = calculator.comparer(
        actuel: _fintech(id: 'actuel', commission: 2.0),
        candidats: [
          _fintech(id: 'cher', commission: 1.9),
          _fintech(id: 'moins_cher', commission: 1.2),
        ],
        volumeMensuel: 1000,
      );

      expect(result!.optimise.provider.id, 'moins_cher');
      expect(result.economieMensuelle, closeTo(8, 0.001));
      expect(result.economieAnnuelle, closeTo(96, 0.001));
    });

    test("exclut le prestataire actuel des candidats", () {
      final actuel = _fintech(id: 'sumup', commission: 1.75);
      final result = calculator.comparer(
        actuel: actuel,
        candidats: [actuel, _fintech(id: 'zettle', commission: 1.5)],
        volumeMensuel: 1000,
      );

      expect(result!.optimise.provider.id, 'zettle');
    });

    test('signale une situation déjà optimale', () {
      final result = calculator.comparer(
        actuel: _fintech(id: 'actuel', commission: 1.0),
        candidats: [_fintech(id: 'autre', commission: 2.0)],
        volumeMensuel: 1000,
      );

      expect(result!.dejaOptimal, isTrue);
      expect(result.economieMensuelle, closeTo(-10, 0.001));

      // Les écarts restent calculés — ils décrivent fidèlement la
      // différence, ici en défaveur de l'alternative. C'est à l'affichage
      // de ne pas présenter cela comme une économie.
      final somme = result.ecartParPoste.fold<double>(
        0,
        (total, l) => total + l.montantMensuel,
      );
      expect(somme, closeTo(result.economieMensuelle, 0.001));
      expect(result.ecartParPoste.every((l) => l.montantMensuel < 0), isTrue);
    });

    test("la somme des écarts égale toujours l'économie annoncée", () {
      // Cas réel : SumUp Paiements Plus est moins cher au total malgré un
      // abonnement plus élevé. Si le détail omettait les postes où la
      // nouvelle offre coûte davantage, il afficherait 36,12 € là où
      // l'économie est de 26,12 € — et le lecteur qui vérifie trouverait
      // un total faux.
      final result = calculator.comparer(
        actuel: _fintech(id: 'actuel', commission: 1.75, mensuel: 9),
        candidats: [_fintech(id: 'sumup_plus', commission: 0.89, mensuel: 19)],
        volumeMensuel: 4200,
      )!;

      final somme = result.ecartParPoste.fold<double>(
        0,
        (total, l) => total + l.montantMensuel,
      );
      expect(somme, closeTo(result.economieMensuelle, 0.001));
      expect(result.economieMensuelle, closeTo(26.12, 0.001));

      final abonnement =
          result.ecartParPoste.firstWhere((l) => l.libelle == 'Abonnement mensuel');
      expect(
        abonnement.montantMensuel,
        closeTo(-10, 0.001),
        reason: 'un poste plus cher doit apparaître avec un écart négatif',
      );
    });

    test('un poste absent de l\'offre actuelle apparaît dans l\'écart', () {
      // La nouvelle offre facture un frais fixe que l'actuelle n'a pas :
      // sans union des deux listes, ce poste serait invisible.
      final result = calculator.comparer(
        actuel: _fintech(id: 'actuel', commission: 2.0),
        candidats: [_fintech(id: 'autre', commission: 1.0, fraisFixe: 0.10)],
        volumeMensuel: 3500,
      )!;

      final libelles = result.ecartParPoste.map((l) => l.libelle);
      expect(libelles, contains('Frais fixe par transaction'));

      final somme = result.ecartParPoste.fold<double>(
        0,
        (total, l) => total + l.montantMensuel,
      );
      expect(somme, closeTo(result.economieMensuelle, 0.001));
    });

    test("détaille l'écart poste par poste, du plus gros au plus petit", () {
      final result = calculator.comparer(
        actuel: _fintech(id: 'actuel', commission: 1.75, mensuel: 9),
        candidats: [_fintech(id: 'autre', commission: 1.30)],
        volumeMensuel: 4200,
      );

      final ecarts = result!.ecartParPoste;
      expect(ecarts.length, 2);
      expect(ecarts.first.libelle, 'Commission par paiement');
      expect(ecarts.first.montantMensuel, closeTo(18.90, 0.001));
      expect(ecarts.last.libelle, 'Abonnement mensuel');
      expect(ecarts.last.montantMensuel, closeTo(9, 0.001));
    });

    test('renvoie null sans candidat exploitable', () {
      final actuel = _fintech(id: 'sumup', commission: 1.75);

      expect(
        calculator.comparer(
          actuel: actuel,
          candidats: const [],
          volumeMensuel: 1000,
        ),
        isNull,
      );
      expect(
        calculator.comparer(
          actuel: actuel,
          candidats: [actuel],
          volumeMensuel: 1000,
        ),
        isNull,
      );
    });
  });
}

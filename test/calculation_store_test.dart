import 'package:flutter_test/flutter_test.dart';
import 'package:frais_tpe/models/saved_calculation.dart';
import 'package:frais_tpe/services/calculation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedCalculation _calcul(
  String id, {
  String libelle = 'Calcul',
  DateTime? creeLe,
  double volume = 4200,
}) {
  return SavedCalculation(
    id: id,
    libelle: libelle,
    volumeMensuel: volume,
    providerActuelId: 'sumup',
    creeLe: creeLe ?? DateTime(2026, 8, 6),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enregistre puis relit un calcul', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('1', libelle: 'Institut'));

    final relu = PrefsCalculationStore();
    await relu.charger();

    expect(relu.calculs, hasLength(1));
    expect(relu.calculs.single.libelle, 'Institut');
    expect(relu.calculs.single.volumeMensuel, 4200);
  });

  test('le panier moyen absent le reste après relecture', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('1'));

    final relu = PrefsCalculationStore();
    await relu.charger();
    expect(relu.calculs.single.panierMoyen, isNull);
  });

  test('classe du plus récent au plus ancien', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('vieux', creeLe: DateTime(2026, 1, 1)));
    await store.enregistrer(_calcul('recent', creeLe: DateTime(2026, 8, 6)));
    await store.enregistrer(_calcul('milieu', creeLe: DateTime(2026, 5, 1)));

    expect(
      store.calculs.map((c) => c.id),
      ['recent', 'milieu', 'vieux'],
    );
  });

  test('un même identifiant écrase au lieu de dupliquer', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('1', libelle: 'Avant'));
    await store.enregistrer(_calcul('1', libelle: 'Après'));

    expect(store.calculs, hasLength(1));
    expect(store.calculs.single.libelle, 'Après');
  });

  test('supprime un calcul', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('1'));
    await store.enregistrer(_calcul('2'));

    await store.supprimer('1');
    expect(store.calculs.map((c) => c.id), ['2']);

    final relu = PrefsCalculationStore();
    await relu.charger();
    expect(relu.calculs.map((c) => c.id), ['2']);
  });

  test('notifie ses auditeurs à chaque changement', () async {
    final store = PrefsCalculationStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.enregistrer(_calcul('1'));
    await store.supprimer('1');
    await store.charger();

    expect(notifications, 3);
  });

  group('robustesse du stockage', () {
    test('un stockage vide donne une liste vide', () async {
      final store = PrefsCalculationStore();
      await store.charger();
      expect(store.calculs, isEmpty);
    });

    test('un stockage corrompu ne fait pas échouer le chargement', () async {
      // Mieux vaut un historique vide qu'une app qui refuse de démarrer.
      SharedPreferences.setMockInitialValues({
        'calculs_sauvegardes': 'ceci n\'est pas du JSON',
      });
      final store = PrefsCalculationStore();
      await store.charger();
      expect(store.calculs, isEmpty);
    });

    test('une entrée incomplète est ignorée, les autres sont conservées', () {
      // Écriture interrompue ou format d'une version antérieure : une
      // seule entrée abîmée ne doit pas emporter tout l'historique.
      final liste = SavedCalculation.decodeListe(
        '[{"id":"ok","libelle":"Bon","volume_mensuel":1000,'
        '"provider_actuel_id":"sumup","cree_le":"2026-08-06T00:00:00.000"},'
        '{"id":"casse","libelle":"Incomplet"}]',
      );
      expect(liste, hasLength(1));
      expect(liste.single.id, 'ok');
    });

    test('une date illisible invalide l\'entrée', () {
      final liste = SavedCalculation.decodeListe(
        '[{"id":"x","libelle":"X","volume_mensuel":1000,'
        '"provider_actuel_id":"sumup","cree_le":"pas une date"}]',
      );
      expect(liste, isEmpty);
    });
  });

  test('la liste exposée ne peut pas être modifiée de l\'extérieur', () async {
    final store = PrefsCalculationStore();
    await store.enregistrer(_calcul('1'));

    expect(
      () => store.calculs.add(_calcul('2')),
      throwsUnsupportedError,
    );
  });
}

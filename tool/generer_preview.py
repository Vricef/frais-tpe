#!/usr/bin/env python3
"""Génère `lib/_preview.dart` à partir de `firestore/providers.seed.json`.

Le harnais de capture d'écran rend un écran isolé dans un navigateur. Ses
données sont dérivées du fichier de seed plutôt que réécrites à la main :
une capture ne peut donc pas montrer des tarifs qui ne sont plus en base.

Usage :  python3 tool/generer_preview.py
"""
import json
import pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
SEED = RACINE / "firestore" / "providers.seed.json"
SORTIE = RACINE / "lib" / "_preview.dart"

CHAMPS_NUM = [
    ("frais_transaction_cb", "fraisTransactionCb"),
    ("frais_fixe_transaction", "fraisFixeTransaction"),
    ("frais_mensuels", "fraisMensuels"),
    ("cout_terminal_min", "coutTerminalMin"),
    ("cout_terminal_max", "coutTerminalMax"),
    ("fourchette_min", "fourchetteMin"),
    ("fourchette_max", "fourchetteMax"),
]
CHAMPS_TEXTE = [
    ("condition", "condition"),
    ("mention_negociation", "mentionNegociation"),
    ("source", "source"),
]


def litteral(texte):
    echappe = texte.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return f"'{echappe}'"


def provider_dart(pid, p):
    lignes = [f"    id: {litteral(pid)},", f"    nom: {litteral(p['nom'])},"]
    if p.get("offre"):
        lignes.append(f"    offre: {litteral(p['offre'])},")
    lignes.append(f"    type: ProviderType.{p['type']},")
    for cle, champ in CHAMPS_NUM:
        if cle in p:
            lignes.append(f"    {champ}: {float(p[cle])},")
    if p.get("tarifs_additionnels"):
        items = ", ".join(
            "TarifAdditionnel(libelle: {}, taux: {})".format(
                litteral(t["libelle"]), float(t["taux"])
            )
            for t in p["tarifs_additionnels"]
        )
        lignes.append(f"    tarifsAdditionnels: [{items}],")
    for cle, champ in CHAMPS_TEXTE:
        if p.get(cle):
            lignes.append(f"    {champ}: {litteral(p[cle])},")
    if p.get("derniere_maj"):
        a, m, j = (int(x) for x in p["derniere_maj"].split("-"))
        lignes.append(f"    derniereMaj: DateTime({a}, {m}, {j}),")
    return "  TpeProvider(\n" + "\n".join(lignes) + "\n  ),"


ENTETE = '''// GÉNÉRÉ — ne pas modifier à la main.
//
// Harnais de capture d'écran : rend un écran isolé, dans un navigateur,
// sur les données réellement présentes en base. Régénéré par
// `tool/generer_preview.py`, qui lit `firestore/providers.seed.json` :
// une capture ne peut donc pas afficher des tarifs qui n'existent plus.
//
// Hors de l'application livrée — aucun écran ne l'importe.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/provider.dart';
import 'screens/comparison_table_screen.dart';
import 'screens/home_screen.dart';
import 'screens/result_screen.dart';
import 'screens/volume_input_screen.dart';
import 'services/calculation_store.dart';
import 'services/entitlement.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

// Non `const` : `derniereMaj` porte un DateTime, qui n'en est pas un.
final _providers = <TpeProvider>[
'''

PIED = '''];

/// Le scénario de toutes les captures : un même commerçant, un même
/// volume. Des montants qui varieraient d'une image à l'autre se
/// remarquent, et c'est le public attentif qu'on vise.
const _volume = 4200.0;
///
/// Le prestataire retenu cumule commission, frais fixe et abonnement :
/// c'est le seul cas où le détail de l'écart montre ses trois postes et
/// où l'on peut vérifier que leur somme tombe juste.
final _actuel =
    _providers.firstWhere((p) => p.id == 'caisse_epargne_tap_to_pay');

/// Firestore n'est pas joignable depuis le navigateur de capture : les
/// écrans reçoivent la base par cette implémentation locale.
class _SeedFirestore implements FirestoreService {
  @override
  Future<List<TpeProvider>> getProviders() async => _providers;

  @override
  Stream<List<TpeProvider>> watchProviders() => Stream.value(_providers);

  @override
  Future<TpeProvider?> getProvider(String id) async =>
      _providers.where((p) => p.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  // Roboto se télécharge depuis fonts.gstatic.com, injoignable ici : sans
  // police locale, les captures sortiraient sans aucun texte.
  //
  // Elle est enregistrée sous le nom « Roboto » plutôt que sous un nom
  // propre : le thème pose des `textStyle` explicites sans famille — sur
  // les boutons notamment — qui retombent sur Roboto et qu'un simple
  // `textTheme.apply()` ne rattrape pas. Le bouton d'export sortait vide.
  final chargeur = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
  await chargeur.load();

  runApp(const _Capture());
}

class _Capture extends StatelessWidget {
  const _Capture();

  @override
  Widget build(BuildContext context) {
    final ecran = Uri.base.queryParameters['ecran'] ?? 'resultat';
    final sombre = Uri.base.queryParameters['theme'] == 'sombre';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: sombre ? AppTheme.dark : AppTheme.light,
      home: _ecranDemande(ecran),
    );
  }

  Widget _ecranDemande(String nom) {
    switch (nom) {
      case 'accueil':
        return HomeScreen(
          entitlement: Entitlement(),
          store: PrefsCalculationStore(),
        );
      case 'saisie':
        return VolumeInputScreen(
          entitlement: Entitlement(),
          store: PrefsCalculationStore(),
          firestoreService: _SeedFirestore(),
        );
      case 'tableau':
        return ComparisonTableScreen(
          volumeMensuel: _volume,
          providers: _providers,
          providerActuel: _actuel,
          entitlement: Entitlement(debloque: true),
        );
      case 'tableau-verrouille':
        return ComparisonTableScreen(
          volumeMensuel: _volume,
          providers: _providers,
          providerActuel: _actuel,
          entitlement: Entitlement(debloque: false),
        );
      case 'resultat':
      default:
        return ResultScreen(
          volumeMensuel: _volume,
          providerActuel: _actuel,
          providers: _providers,
          entitlement: Entitlement(debloque: true),
          store: PrefsCalculationStore(),
        );
    }
  }
}
'''

def main():
    prov = json.loads(SEED.read_text(encoding="utf-8"))
    corps = "\n".join(provider_dart(k, v) for k, v in prov.items())
    SORTIE.write_text(ENTETE + corps + "\n" + PIED, encoding="utf-8")
    print(f"{SORTIE.relative_to(RACINE)} : {len(prov)} prestataires")


if __name__ == "__main__":
    main()

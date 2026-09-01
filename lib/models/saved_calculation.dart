import 'dart:convert';

import 'provider.dart';

/// Un calcul sauvegardé (§3.1, §8 — fonctionnalité payante).
///
/// Seules les **entrées** du calcul sont conservées, pas ses résultats :
/// les grilles tarifaires évoluent, et un montant figé le jour de la
/// sauvegarde deviendrait faux sans prévenir. Rouvrir un calcul le rejoue
/// donc sur les tarifs du moment — ce qui est précisément l'intérêt d'y
/// revenir.
class SavedCalculation {
  const SavedCalculation({
    required this.id,
    required this.libelle,
    required this.volumeMensuel,
    required this.providerActuelId,
    required this.creeLe,
    this.panierMoyen,
    this.providerPerso,
  });

  final String id;

  /// Nom donné par l'utilisateur, ou libellé par défaut.
  final String libelle;

  final double volumeMensuel;
  final double? panierMoyen;

  /// Identifiant du prestataire alors sélectionné. S'il disparaît de la
  /// base, le calcul devient inexploitable et l'écran le signale plutôt
  /// que d'afficher un résultat faux.
  final String providerActuelId;

  /// Tarifs du prestataire quand l'utilisateur les a saisis lui-même.
  ///
  /// Ceux-là ne sont pas en base : sans les conserver ici, rouvrir le
  /// calcul serait impossible, [providerActuelId] ne correspondant à
  /// aucun document. C'est la seule exception à la règle « on ne stocke
  /// que les entrées » — et c'en est bien une : ces taux sont une saisie
  /// de l'utilisateur, pas un résultat calculé.
  final TpeProvider? providerPerso;

  final DateTime creeLe;

  Map<String, dynamic> toJson() => {
        'id': id,
        'libelle': libelle,
        'volume_mensuel': volumeMensuel,
        if (panierMoyen != null) 'panier_moyen': panierMoyen,
        'provider_actuel_id': providerActuelId,
        if (providerPerso != null)
          'provider_perso': {
            'nom': providerPerso!.nom,
            'frais_transaction_cb': providerPerso!.fraisTransactionCb,
            if (providerPerso!.fraisFixeTransaction != null)
              'frais_fixe_transaction': providerPerso!.fraisFixeTransaction,
            if (providerPerso!.fraisMensuels != null)
              'frais_mensuels': providerPerso!.fraisMensuels,
          },
        'cree_le': creeLe.toIso8601String(),
      };

  /// Reconstruit le prestataire saisi à partir de la forme stockée.
  ///
  /// Les champs sont réécrits à la main plutôt que par [TpeProvider.toMap] :
  /// celle-ci produit un `Timestamp` Firestore, que `jsonEncode` refuse.
  static TpeProvider? _persoFromJson(Object? brut, String id) {
    if (brut is! Map) return null;
    final commission = (brut['frais_transaction_cb'] as num?)?.toDouble();
    // Sans commission il n'y a rien à calculer : l'entrée est ignorée,
    // et le calcul se comportera comme un prestataire introuvable.
    if (commission == null) return null;
    return TpeProvider(
      id: id,
      nom: brut['nom'] as String? ?? 'Mon prestataire',
      type: ProviderType.processeurPaiement,
      fraisTransactionCb: commission,
      fraisFixeTransaction:
          (brut['frais_fixe_transaction'] as num?)?.toDouble(),
      fraisMensuels: (brut['frais_mensuels'] as num?)?.toDouble(),
      estPersonnalise: true,
    );
  }

  static SavedCalculation? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final volume = json['volume_mensuel'];
    final providerId = json['provider_actuel_id'];
    final creeLe = DateTime.tryParse(json['cree_le'] as String? ?? '');
    // Un enregistrement incomplet — écriture interrompue, format d'une
    // version antérieure — est ignoré plutôt que de faire échouer le
    // chargement de tout l'historique.
    if (id is! String || volume is! num || providerId is! String ||
        creeLe == null) {
      return null;
    }
    return SavedCalculation(
      id: id,
      libelle: json['libelle'] as String? ?? 'Calcul',
      volumeMensuel: volume.toDouble(),
      panierMoyen: (json['panier_moyen'] as num?)?.toDouble(),
      providerActuelId: providerId,
      providerPerso: _persoFromJson(json['provider_perso'], providerId),
      creeLe: creeLe,
    );
  }

  static String encodeListe(List<SavedCalculation> calculs) {
    return jsonEncode(calculs.map((c) => c.toJson()).toList());
  }

  static List<SavedCalculation> decodeListe(String? brut) {
    if (brut == null || brut.isEmpty) return const [];
    try {
      final decode = jsonDecode(brut);
      if (decode is! List) return const [];
      return decode
          .whereType<Map<String, dynamic>>()
          .map(SavedCalculation.fromJson)
          .whereType<SavedCalculation>()
          .toList();
    } on FormatException {
      // Stockage corrompu : mieux vaut un historique vide qu'une app qui
      // refuse de démarrer.
      return const [];
    }
  }
}

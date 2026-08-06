import 'dart:convert';

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

  final DateTime creeLe;

  Map<String, dynamic> toJson() => {
        'id': id,
        'libelle': libelle,
        'volume_mensuel': volumeMensuel,
        if (panierMoyen != null) 'panier_moyen': panierMoyen,
        'provider_actuel_id': providerActuelId,
        'cree_le': creeLe.toIso8601String(),
      };

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

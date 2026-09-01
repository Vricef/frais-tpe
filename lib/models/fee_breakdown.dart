import 'provider.dart';

/// Une ligne du détail des frais (ex. "Commission par paiement : 18,90 €").
///
/// Alimente le bloc "D'où vient l'écart" sous la jauge : le montant affiché
/// n'a de valeur que si l'utilisateur peut voir d'où il sort.
class FeeLine {
  const FeeLine({required this.libelle, required this.montantMensuel});

  final String libelle;

  /// Montant mensuel en euros.
  ///
  /// Sur une ligne de coût, toujours positif. Sur une ligne d'écart
  /// ([ComparisonResult.ecartParPoste]), le signe porte le sens : positif
  /// quand la nouvelle offre coûte moins cher sur ce poste, négatif quand
  /// elle coûte davantage.
  final double montantMensuel;
}

/// Le coût mensuel d'un prestataire pour un volume donné, décomposé.
class FeeBreakdown {
  const FeeBreakdown({
    required this.provider,
    required this.lignes,
    required this.totalMensuel,
  });

  final TpeProvider provider;
  final List<FeeLine> lignes;
  final double totalMensuel;

  double get totalAnnuel => totalMensuel * 12;
}

/// Comparaison entre la situation actuelle et la meilleure offre trouvée.
class ComparisonResult {
  const ComparisonResult({
    required this.actuel,
    required this.optimise,
    required this.ecartParPoste,
    this.optimiseSansCompte,
  });

  final FeeBreakdown actuel;
  final FeeBreakdown optimise;

  /// La moins chère parmi les offres qui ne demandent pas d'ouvrir un
  /// compte, quand elle diffère de [optimise].
  ///
  /// Sans elle, le classement désigne toujours le même gagnant à celui
  /// qui n'a aucune intention de changer de banque : une réponse exacte
  /// et inutilisable. `null` quand la meilleure offre est déjà de
  /// celles-là — il n'y a alors qu'un gagnant à montrer.
  final FeeBreakdown? optimiseSansCompte;

  double? get economieSansCompteMensuelle => optimiseSansCompte == null
      ? null
      : actuel.totalMensuel - optimiseSansCompte!.totalMensuel;

  /// Détail de l'écart poste par poste, dans l'ordre d'affichage.
  final List<FeeLine> ecartParPoste;

  /// Économie mensuelle. Peut être négative si le prestataire actuel est
  /// déjà le moins cher — l'écran doit alors féliciter plutôt qu'alerter.
  double get economieMensuelle => actuel.totalMensuel - optimise.totalMensuel;

  double get economieAnnuelle => economieMensuelle * 12;

  bool get dejaOptimal => economieMensuelle <= 0;
}

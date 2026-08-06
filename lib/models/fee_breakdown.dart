import 'provider.dart';

/// Une ligne du détail des frais (ex. "Commission par paiement : 18,90 €").
///
/// Alimente le bloc "D'où vient l'écart" sous la jauge : le montant affiché
/// n'a de valeur que si l'utilisateur peut voir d'où il sort.
class FeeLine {
  const FeeLine({required this.libelle, required this.montantMensuel});

  final String libelle;

  /// Montant mensuel en euros (toujours positif ; l'écran l'affiche
  /// précédé du signe adéquat).
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
  });

  final FeeBreakdown actuel;
  final FeeBreakdown optimise;

  /// Détail de l'écart poste par poste, dans l'ordre d'affichage.
  final List<FeeLine> ecartParPoste;

  /// Économie mensuelle. Peut être négative si le prestataire actuel est
  /// déjà le moins cher — l'écran doit alors féliciter plutôt qu'alerter.
  double get economieMensuelle => actuel.totalMensuel - optimise.totalMensuel;

  double get economieAnnuelle => economieMensuelle * 12;

  bool get dejaOptimal => economieMensuelle <= 0;
}

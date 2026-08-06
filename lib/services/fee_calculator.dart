import '../models/fee_breakdown.dart';
import '../models/provider.dart';

/// Calcule le coût réel d'un prestataire selon le volume encaissé
/// (cahier des charges §3.1).
///
/// Le calcul reste volontairement simple et lisible : commission
/// proportionnelle + frais fixe par transaction + frais mensuels. C'est
/// exactement ce que l'utilisateur pourra vérifier ligne à ligne dans le
/// détail affiché sous la jauge.
class FeeCalculator {
  const FeeCalculator();

  /// Panier moyen par défaut, utilisé pour estimer le nombre de
  /// transactions quand l'utilisateur ne le renseigne pas.
  static const double panierMoyenParDefaut = 35;

  FeeBreakdown calculer({
    required TpeProvider provider,
    required double volumeMensuel,
    double? panierMoyen,
  }) {
    final panier = (panierMoyen == null || panierMoyen <= 0)
        ? panierMoyenParDefaut
        : panierMoyen;
    final nbTransactions = volumeMensuel <= 0 ? 0.0 : volumeMensuel / panier;

    final lignes = <FeeLine>[];

    final tauxCommission = provider.aTarifsFixes
        ? provider.fraisTransactionCb
        : _milieuDeFourchette(provider);
    if (tauxCommission != null && tauxCommission > 0) {
      lignes.add(
        FeeLine(
          libelle: 'Commission par paiement',
          montantMensuel: volumeMensuel * tauxCommission / 100,
        ),
      );
    }

    final fraisFixe = provider.fraisFixeTransaction;
    if (fraisFixe != null && fraisFixe > 0) {
      lignes.add(
        FeeLine(
          libelle: 'Frais fixe par transaction',
          montantMensuel: nbTransactions * fraisFixe,
        ),
      );
    }

    final fraisMensuels = provider.fraisMensuels;
    if (fraisMensuels != null && fraisMensuels > 0) {
      lignes.add(
        FeeLine(libelle: 'Abonnement mensuel', montantMensuel: fraisMensuels),
      );
    }

    final total = lignes.fold<double>(0, (sum, l) => sum + l.montantMensuel);

    return FeeBreakdown(
      provider: provider,
      lignes: lignes,
      totalMensuel: total,
    );
  }

  /// Pour une banque traditionnelle, les tarifs sont négociés au cas par
  /// cas (§3.2) : on estime avec le milieu de fourchette, et l'écran
  /// affiche la fourchette plutôt qu'un chiffre unique.
  double? _milieuDeFourchette(TpeProvider provider) {
    final min = provider.fourchetteMin;
    final max = provider.fourchetteMax;
    if (min == null && max == null) return null;
    if (min == null) return max;
    if (max == null) return min;
    return (min + max) / 2;
  }

  /// Classe tous les prestataires du moins cher au plus cher pour le
  /// volume donné — le tableau comparatif de l'écran 3.
  ///
  /// Contrairement à [comparer], le prestataire actuel reste dans la
  /// liste : l'utilisateur doit pouvoir se situer parmi les offres.
  List<FeeBreakdown> classer({
    required List<TpeProvider> providers,
    required double volumeMensuel,
    double? panierMoyen,
  }) {
    final breakdowns = providers
        .map(
          (p) => calculer(
            provider: p,
            volumeMensuel: volumeMensuel,
            panierMoyen: panierMoyen,
          ),
        )
        .toList();

    breakdowns.sort((a, b) {
      final parCout = a.totalMensuel.compareTo(b.totalMensuel);
      // À coût égal, on départage par nom pour que l'ordre soit stable
      // d'un affichage à l'autre.
      return parCout != 0
          ? parCout
          : a.provider.nom.toLowerCase().compareTo(b.provider.nom.toLowerCase());
    });
    return breakdowns;
  }

  /// Compare la situation actuelle à la meilleure offre parmi [candidats].
  ///
  /// Renvoie `null` si aucun candidat n'est exploitable.
  ComparisonResult? comparer({
    required TpeProvider actuel,
    required List<TpeProvider> candidats,
    required double volumeMensuel,
    double? panierMoyen,
  }) {
    if (candidats.isEmpty) return null;

    final breakdownActuel = calculer(
      provider: actuel,
      volumeMensuel: volumeMensuel,
      panierMoyen: panierMoyen,
    );

    final breakdowns = candidats
        .where((p) => p.id != actuel.id)
        .map(
          (p) => calculer(
            provider: p,
            volumeMensuel: volumeMensuel,
            panierMoyen: panierMoyen,
          ),
        )
        .toList();
    if (breakdowns.isEmpty) return null;

    breakdowns.sort((a, b) => a.totalMensuel.compareTo(b.totalMensuel));
    final meilleur = breakdowns.first;

    return ComparisonResult(
      actuel: breakdownActuel,
      optimise: meilleur,
      ecartParPoste: _ecartParPoste(breakdownActuel, meilleur),
    );
  }

  /// Écart poste par poste entre deux offres, pour le bloc "D'où vient
  /// l'écart". Seuls les postes où l'on économise sont listés : le but est
  /// d'expliquer le gain, pas de dresser un bilan comptable.
  List<FeeLine> _ecartParPoste(FeeBreakdown actuel, FeeBreakdown optimise) {
    final parLibelleOptimise = {
      for (final l in optimise.lignes) l.libelle: l.montantMensuel,
    };

    final ecarts = <FeeLine>[];
    for (final ligne in actuel.lignes) {
      final montantOptimise = parLibelleOptimise[ligne.libelle] ?? 0;
      final ecart = ligne.montantMensuel - montantOptimise;
      if (ecart > 0.005) {
        ecarts.add(FeeLine(libelle: ligne.libelle, montantMensuel: ecart));
      }
    }

    ecarts.sort((a, b) => b.montantMensuel.compareTo(a.montantMensuel));
    return ecarts;
  }
}

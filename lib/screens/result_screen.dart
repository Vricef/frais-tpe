import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_breakdown.dart';
import '../models/provider.dart';
import '../services/entitlement.dart';
import '../services/fee_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/comparison_gauge.dart';
import '../widgets/ticket_card.dart';
import 'comparison_table_screen.dart';

/// Écran 3 du parcours (§8) : le résultat de la comparaison.
///
/// Composant clé : la jauge à deux barres sur une même échelle. L'écart
/// est matérialisé en hachures terre cuite — le ton reste rassurant, et
/// le détail poste par poste juste en dessous désamorce la méfiance sur
/// le chiffre affiché.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.volumeMensuel,
    required this.providerActuel,
    required this.providers,
    required this.entitlement,
    this.panierMoyen,
    this.calculator = const FeeCalculator(),
  });

  final double volumeMensuel;

  /// Panier moyen saisi par l'utilisateur ; `null` = valeur par défaut.
  final double? panierMoyen;

  final TpeProvider providerActuel;
  final List<TpeProvider> providers;
  final FeeCalculator calculator;
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final resultat = calculator.comparer(
      actuel: providerActuel,
      candidats: providers,
      volumeMensuel: volumeMensuel,
      panierMoyen: panierMoyen,
    );

    final formatVolume = NumberFormat.decimalPattern('fr_FR');

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TicketHeader(
                trailing: '${formatVolume.format(volumeMensuel)} €/mois',
              ),
              const SizedBox(height: 24),
              if (resultat == null)
                const _AucuneComparaison()
              else ...[
                _Titre(resultat: resultat),
                const SizedBox(height: 20),
                _CarteResultat(
                  resultat: resultat,
                  volumeMensuel: volumeMensuel,
                  panierMoyen: panierMoyen,
                  providers: providers,
                  providerActuel: providerActuel,
                  entitlement: entitlement,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Le titre porte le message principal. Si la situation est déjà la
/// meilleure, on rassure au lieu d'inventer un problème.
class _Titre extends StatelessWidget {
  const _Titre({required this.resultat});

  final ComparisonResult resultat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final format = _formatEuro;

    if (resultat.dejaOptimal) {
      return Text(
        'Vous êtes déjà au bon tarif.',
        style: textTheme.headlineMedium?.copyWith(fontSize: 26, height: 1.25),
      );
    }

    return Text.rich(
      TextSpan(
        style: textTheme.headlineMedium?.copyWith(fontSize: 26, height: 1.25),
        children: [
          const TextSpan(text: 'Vous payez '),
          TextSpan(
            text: format.format(resultat.economieMensuelle),
            style: TextStyle(color: colors.accent),
          ),
          const TextSpan(text: ' de trop chaque mois.'),
        ],
      ),
    );
  }
}

class _CarteResultat extends StatelessWidget {
  const _CarteResultat({
    required this.resultat,
    required this.volumeMensuel,
    required this.panierMoyen,
    required this.providers,
    required this.providerActuel,
    required this.entitlement,
  });

  final ComparisonResult resultat;
  final double volumeMensuel;
  final double? panierMoyen;
  final List<TpeProvider> providers;
  final TpeProvider providerActuel;
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = _formatEuro;

    return TicketCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComparisonGauge(
            currentLabel: "Aujourd'hui",
            currentAmount: resultat.actuel.totalMensuel,
            optimizedLabel: 'Avec ${resultat.optimise.provider.nom}',
            optimizedAmount: resultat.optimise.totalMensuel,
          ),
          if (!resultat.dejaOptimal) ...[
            const SizedBox(height: 16),
            _NoteHachure(),
          ],
          const SizedBox(height: 16),
          _EncartEconomie(resultat: resultat),
          if (resultat.ecartParPoste.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              "D'OÙ VIENT L'ÉCART",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            for (final ligne in resultat.ecartParPoste) ...[
              _LigneEcart(ligne: ligne, format: format),
              const SizedBox(height: 2),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // L'export PDF est une fonctionnalité débloquée par
                // l'achat unique (§4) — écran paywall à venir.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export PDF — à venir')),
                );
              },
              child: const Text('Recevoir le détail en PDF'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ComparisonTableScreen(
                      volumeMensuel: volumeMensuel,
                      providers: providers,
                      providerActuel: providerActuel,
                      panierMoyen: panierMoyen,
                      entitlement: entitlement,
                    ),
                  ),
                );
              },
              child: Text(
                providers.length > 1
                    ? 'Voir les ${providers.length} offres comparées'
                    : 'Voir le détail des offres',
                style: TextStyle(color: colors.textSecondary, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteHachure extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 17, color: colors.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              "La partie hachurée, c'est ce que vous payez en trop.",
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EncartEconomie extends StatelessWidget {
  const _EncartEconomie({required this.resultat});

  final ComparisonResult resultat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = _formatEuro;
    final optimal = resultat.dejaOptimal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: optimal ? colors.surfaceAlt : colors.savingsSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            optimal ? 'Rien à économiser' : 'Économie par mois',
            style: TextStyle(
              color: optimal ? colors.textSecondary : colors.savings,
              fontSize: 14,
            ),
          ),
          if (!optimal)
            Text(
              '- ${format.format(resultat.economieMensuelle)}',
              style: context.amountStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.savings,
              ),
            ),
        ],
      ),
    );
  }
}

class _LigneEcart extends StatelessWidget {
  const _LigneEcart({required this.ligne, required this.format});

  final FeeLine ligne;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            ligne.libelle,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
          ),
          Text(
            '- ${format.format(ligne.montantMensuel)}',
            style: context.amountStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AucuneComparaison extends StatelessWidget {
  const _AucuneComparaison();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pas encore de comparaison possible',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "Aucun autre prestataire n'est disponible pour se comparer au "
            "vôtre. Réessayez plus tard.",
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

final _formatEuro = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_breakdown.dart';
import '../models/provider.dart';
import '../services/entitlement.dart';
import '../services/fee_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/masked_amount.dart';
import '../widgets/ticket_card.dart';
import 'paywall_screen.dart';
import 'provider_detail_screen.dart';

/// Écran 3 bis du parcours (§8) : le tableau comparatif de toutes les
/// offres.
///
/// Présenté comme un ticket de caisse : une ligne par offre, les montants
/// alignés en colonne. Le prestataire de l'utilisateur y figure aussi —
/// se situer dans le classement fait partie de l'information.
///
/// Un prestataire absent de la base se saisit à l'écran précédent, avec
/// le reste du calcul : il arrive ici déjà classé, comme les autres.
class ComparisonTableScreen extends StatelessWidget {
  const ComparisonTableScreen({
    super.key,
    required this.volumeMensuel,
    required this.providers,
    required this.providerActuel,
    required this.entitlement,
    this.panierMoyen,
    this.calculator = const FeeCalculator(),
  });

  final double volumeMensuel;
  final List<TpeProvider> providers;
  final TpeProvider providerActuel;
  final double? panierMoyen;
  final FeeCalculator calculator;

  /// Tant que l'achat n'est pas fait, seules la meilleure offre et celle
  /// de l'utilisateur affichent leur coût (§4 : la version gratuite
  /// compare un seul prestataire).
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: entitlement,
      builder: (context, deverrouille, _) {
        final classement = calculator.classer(
          providers: providers,
          volumeMensuel: volumeMensuel,
          panierMoyen: panierMoyen,
        );

        final coutActuel = classement
            .where((b) => b.provider.id == providerActuel.id)
            .map((b) => b.totalMensuel)
            .firstOrNull;

        return _Vue(
          classement: classement,
          deverrouille: deverrouille,
          coutActuel: coutActuel,
          volumeMensuel: volumeMensuel,
          panierMoyen: panierMoyen,
          providerActuel: providerActuel,
          entitlement: entitlement,
        );
      },
    );
  }
}

class _Vue extends StatelessWidget {
  const _Vue({
    required this.classement,
    required this.deverrouille,
    required this.coutActuel,
    required this.volumeMensuel,
    required this.panierMoyen,
    required this.providerActuel,
    required this.entitlement,
  });

  final List<FeeBreakdown> classement;
  final bool deverrouille;
  final double? coutActuel;
  final double volumeMensuel;
  final double? panierMoyen;
  final TpeProvider providerActuel;
  final Entitlement entitlement;

  /// Les offres chiffrées en version gratuite : la moins chère de la base,
  /// celle de l'utilisateur, et celles qu'il a saisies lui-même (dont il
  /// connaît déjà les montants, puisqu'il en a fourni les taux).
  Set<String> get _idsVisibles {
    final ids = <String>{providerActuel.id};
    final meilleureReelle = classement
        .where((b) => !b.provider.estPersonnalise)
        .map((b) => b.provider.id)
        .firstOrNull;
    if (meilleureReelle != null) ids.add(meilleureReelle);
    for (final b in classement) {
      if (b.provider.estPersonnalise) ids.add(b.provider.id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final formatVolume = NumberFormat.decimalPattern('fr_FR');

    final idsVisibles = _idsVisibles;
    final verrouillees = deverrouille
        ? const <FeeBreakdown>[]
        : (classement
            .where((b) => !idsVisibles.contains(b.provider.id))
            .toList()
          // Tri alphabétique et non par coût : l'ordre d'une ligne masquée
          // renseignerait sur son montant. Combiné à l'ajout d'un
          // prestataire personnalisé — dont l'utilisateur choisit le
          // tarif — un classement par coût permettrait de retrouver
          // n'importe quel montant masqué par dichotomie.
          ..sort((a, b) => a.provider.nomComplet
              .toLowerCase()
              .compareTo(b.provider.nomComplet.toLowerCase())));
    final visibles = deverrouille
        ? classement
        : classement.where((b) => idsVisibles.contains(b.provider.id)).toList();

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classement.length > 1
                    ? '${classement.length} offres comparées'
                    : 'Offre comparée',
                style: textTheme.headlineMedium?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Pour ${formatVolume.format(volumeMensuel)} € encaissés par mois',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (classement.isEmpty)
                _ListeVide()
              else
                TicketCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < visibles.length; i++) ...[
                        if (i > 0) const TicketPerforation(),
                        _LigneOffre(
                          // Le rang n'est affiché qu'une fois débloqué :
                          // en gratuit, il dirait combien d'offres masquées
                          // s'intercalent entre deux montants connus.
                          rang: deverrouille ? i + 1 : null,
                          breakdown: visibles[i],
                          estActuel:
                              visibles[i].provider.id == providerActuel.id,
                          estMeilleure: classement.isNotEmpty &&
                              visibles[i].provider.id ==
                                  classement.first.provider.id,
                          coutActuel: coutActuel,
                          verrouille: false,
                          onTap: () => _ouvrirFiche(context, visibles[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              if (verrouillees.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'AUTRES OFFRES COMPARÉES',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                TicketCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < verrouillees.length; i++) ...[
                        if (i > 0) const TicketPerforation(),
                        _LigneOffre(
                          rang: null,
                          breakdown: verrouillees[i],
                          estActuel: false,
                          estMeilleure: false,
                          coutActuel: coutActuel,
                          verrouille: true,
                          // Une ligne verrouillée ne doit pas ouvrir la
                          // fiche : elle y afficherait le coût exact,
                          // contournant le masquage du tableau.
                          onTap: () => _ouvrirPaywall(context),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AppelDeblocage(
                  nombreMasque: verrouillees.length,
                  onTap: () => _ouvrirPaywall(context),
                ),
              ],
              if (classement.any((b) => !b.provider.aTarifsFixes)) ...[
                const SizedBox(height: 14),
                _LegendeEstimation(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(entitlement: entitlement),
      ),
    );
  }

  void _ouvrirFiche(BuildContext context, FeeBreakdown breakdown) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderDetailScreen(
          provider: breakdown.provider,
          volumeMensuel: volumeMensuel,
          panierMoyen: panierMoyen,
        ),
      ),
    );
  }
}

/// Une ligne du tableau : nom, coût mensuel, et écart par rapport à la
/// situation actuelle de l'utilisateur.
class _LigneOffre extends StatelessWidget {
  const _LigneOffre({
    required this.rang,
    required this.breakdown,
    required this.estActuel,
    required this.estMeilleure,
    required this.coutActuel,
    required this.verrouille,
    required this.onTap,
  });

  final int? rang;
  final FeeBreakdown breakdown;
  final bool estActuel;
  final bool estMeilleure;
  final double? coutActuel;
  final bool verrouille;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = breakdown.provider;

    // Sur une ligne verrouillée, le montant n'est jamais mis en forme : la
    // valeur ne doit exister ni dans l'arbre de widgets, ni dans l'arbre
    // de sémantique lu par les lecteurs d'écran.
    //
    // Les banques n'ont pas de tarif public : leur coût est une estimation
    // au milieu de la fourchette, signalée par « ≈ ». Ce marqueur disparaît
    // lui aussi quand la ligne est verrouillée — les placeholders doivent
    // être strictement identiques d'une ligne à l'autre.
    final montant = verrouille
        ? null
        : '${provider.aTarifsFixes ? '' : '≈ '}'
            '${_formatEuro.format(breakdown.totalMensuel)}';

    // L'écart est masqué pour la même raison : il donne directement le
    // montant caché, par soustraction avec le coût actuel affiché
    // au-dessus.
    final ecart = coutActuel == null || estActuel || verrouille
        ? null
        : breakdown.totalMensuel - coutActuel!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (rang != null)
              SizedBox(
                width: 24,
                child: Text(
                  '$rang',
                  style: context.amountStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.nomComplet,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: estActuel || estMeilleure
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (estActuel || estMeilleure || provider.estPersonnalise) ...[
                    const SizedBox(height: 4),
                    _Etiquette(
                      texte: estActuel
                          ? 'Votre offre'
                          : estMeilleure
                              ? 'Meilleure offre'
                              : 'Saisi par vous',
                      couleur: estMeilleure && !estActuel
                          ? colors.savings
                          : colors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (montant == null)
                  const MaskedAmount()
                else
                  Text(
                    montant,
                    style: context.amountStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (ecart != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    ecart < 0
                        ? '- ${_formatEuro.format(ecart.abs())}'
                        : '+ ${_formatEuro.format(ecart)}',
                    style: context.amountStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ecart < 0 ? colors.savings : colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              verrouille ? Icons.lock_outline : Icons.chevron_right,
              size: verrouille ? 15 : 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.texte, required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: couleur,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// L'invitation au déblocage, placée sous le tableau — après que
/// l'utilisateur a vu ce qu'il manque, pas avant.
class _AppelDeblocage extends StatelessWidget {
  const _AppelDeblocage({required this.nombreMasque, required this.onTap});

  final int nombreMasque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombreMasque > 1
                ? 'Voir le coût de ces $nombreMasque offres'
                : "Voir le coût de cette offre",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Débloquez la comparaison complète, l\'export PDF et la '
            'sauvegarde pour 3,99 € — un seul paiement.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              child: const Text('Débloquer pour 3,99 €'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendeEstimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '≈',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Les banques ne publient pas de grille fixe : leur coût est "
            "estimé au milieu des tarifs habituellement constatés, et se "
            "négocie au cas par cas.",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListeVide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      child: Text(
        "Aucune offre à comparer pour le moment.",
        style: TextStyle(color: colors.textSecondary),
      ),
    );
  }
}

final _formatEuro = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);

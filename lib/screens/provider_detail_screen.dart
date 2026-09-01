import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_breakdown.dart';
import '../models/provider.dart';
import '../services/fee_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket_card.dart';

/// Écran 4 du parcours (§8) : la fiche tarifs complète d'un prestataire.
///
/// Deux affichages selon le type (§3.2) : un processeur de paiement a une
/// grille publique et fixe, donc des chiffres exacts ; une banque
/// traditionnelle négocie au cas par cas, donc une fourchette présentée
/// comme argument de négociation plutôt qu'un chiffre unique.
class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({
    super.key,
    required this.provider,
    required this.volumeMensuel,
    this.panierMoyen,
    this.calculator = const FeeCalculator(),
  });

  final TpeProvider provider;
  final double volumeMensuel;
  final double? panierMoyen;
  final FeeCalculator calculator;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final breakdown = calculator.calculer(
      provider: provider,
      volumeMensuel: volumeMensuel,
      panierMoyen: panierMoyen,
    );

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.nomComplet,
                style: textTheme.headlineMedium?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              _EtiquetteType(type: provider.type),
              const SizedBox(height: 20),
              _CarteCout(breakdown: breakdown, volumeMensuel: volumeMensuel),
              const SizedBox(height: 16),
              if (provider.aTarifsFixes)
                _GrilleTarifaire(provider: provider)
              else
                _FourchetteNegociation(provider: provider),
              if (provider.condition != null) ...[
                const SizedBox(height: 16),
                _Condition(texte: provider.condition!),
              ],
              if (provider.tarifsAdditionnels.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TarifsAdditionnels(tarifs: provider.tarifsAdditionnels),
              ],
              if (provider.aUnTerminalAAcheter) ...[
                const SizedBox(height: 16),
                _CoutTerminal(provider: provider),
              ],
              const SizedBox(height: 16),
              _MentionSource(provider: provider),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtiquetteType extends StatelessWidget {
  const _EtiquetteType({required this.type});

  final ProviderType type;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final libelle = type == ProviderType.processeurPaiement
        ? 'Processeur de paiement'
        : 'Banque professionnelle';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        libelle,
        style: TextStyle(color: colors.textSecondary, fontSize: 12),
      ),
    );
  }
}

/// Le coût estimé pour le volume de l'utilisateur — l'information qu'il
/// est venu chercher, donc placée en premier.
class _CarteCout extends StatelessWidget {
  const _CarteCout({required this.breakdown, required this.volumeMensuel});

  final FeeBreakdown breakdown;
  final double volumeMensuel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formatVolume = NumberFormat.decimalPattern('fr_FR');

    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POUR ${formatVolume.format(volumeMensuel)} € PAR MOIS',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatEuro.format(breakdown.totalMensuel),
                style: context.amountStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ mois',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'soit ${_formatEuro.format(breakdown.totalAnnuel)} par an',
            style: TextStyle(color: colors.textSecondary, fontSize: 13.5),
          ),
          if (breakdown.lignes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const TicketPerforation(),
            const SizedBox(height: 14),
            for (final ligne in breakdown.lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ligne.libelle,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    ),
                    Text(
                      _formatEuro.format(ligne.montantMensuel),
                      style: context.amountStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ce que la grille tarifaire seule ne dit pas : compte obligatoire,
/// frais de mise en service, facturation conditionnelle.
///
/// Le texte est repris tel quel de la base plutôt qu'assorti d'une
/// mention figée : certaines de ces précisions sont des surcoûts à
/// prévoir, d'autres jouent en faveur du prestataire, et une seule
/// formule ne peut pas être juste pour les deux.
class _Condition extends StatelessWidget {
  const _Condition({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À SAVOIR',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  texte,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La grille tarifaire brute, telle qu'annoncée par le prestataire.
class _GrilleTarifaire extends StatelessWidget {
  const _GrilleTarifaire({required this.provider});

  final TpeProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lignes = <(String, String)>[
      if (provider.fraisTransactionCb != null)
        (
          'Commission par paiement',
          '${_formatPourcent.format(provider.fraisTransactionCb)} %',
        ),
      if (provider.fraisFixeTransaction != null)
        (
          'Frais fixe par transaction',
          _formatEuro.format(provider.fraisFixeTransaction),
        ),
      if (provider.fraisMensuels != null)
        ('Abonnement mensuel', _formatEuro.format(provider.fraisMensuels)),
    ];

    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GRILLE TARIFAIRE',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (lignes.isEmpty)
            Text(
              'Aucun tarif renseigné pour ce prestataire.',
              style: TextStyle(color: colors.textSecondary),
            )
          else
            for (final (libelle, valeur) in lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      libelle,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    ),
                    Text(
                      valeur,
                      style: context.amountStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Pour une banque traditionnelle : la fourchette, présentée comme un
/// levier de négociation plutôt que comme un tarif figé.
class _FourchetteNegociation extends StatelessWidget {
  const _FourchetteNegociation({required this.provider});

  final TpeProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final min = provider.fourchetteMin;
    final max = provider.fourchetteMax;

    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TARIF NÉGOCIÉ',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (min != null || max != null)
            Text(
              'Commission généralement entre '
              '${_formatPourcent.format(min ?? max)} % et '
              '${_formatPourcent.format(max ?? min)} %',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          else
            Text(
              'Tarifs non communiqués publiquement.',
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
            ),
          const SizedBox(height: 10),
          Text(
            provider.mentionNegociation ??
                "Cette banque ne publie pas de grille fixe : le tarif se "
                    "négocie au cas par cas. Les chiffres ci-dessus vous "
                    "donnent une base de discussion.",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Les taux qui ne s'appliquent qu'à certains encaissements.
///
/// Ils ne pèsent pas sur le calcul — celui-ci retient le cas courant —
/// mais les afficher évite une mauvaise surprise à qui encaisse beaucoup
/// d'Amex, de cartes étrangères ou de paiements à distance.
class _TarifsAdditionnels extends StatelessWidget {
  const _TarifsAdditionnels({required this.tarifs});

  final List<TarifAdditionnel> tarifs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AUTRES CAS DE PAIEMENT',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          for (final t in tarifs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t.libelle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.fraisFixe == null
                        ? '${_formatPourcent.format(t.taux)} %'
                        : '${_formatPourcent.format(t.taux)} % + '
                            '${_formatEuro.format(t.fraisFixe)}',
                    style: context.amountStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Le coût estimé ci-dessus retient le cas courant : encaissement '
            'en personne, carte domestique.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le prix du terminal, volontairement tenu hors du coût mensuel.
///
/// C'est un achat unique : l'intégrer au calcul récurrent fausserait la
/// comparaison, mais l'ignorer masquerait un écart réel — de 29 € à 249 €
/// selon les prestataires.
class _CoutTerminal extends StatelessWidget {
  const _CoutTerminal({required this.provider});

  final TpeProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final min = provider.coutTerminalMin;
    final max = provider.coutTerminalMax;

    final String montant;
    if (min != null && max != null && min != max) {
      montant = 'de ${_formatEuroEntier.format(min)} '
          'à ${_formatEuroEntier.format(max)} HT';
    } else if (min != null && max == null) {
      montant = 'à partir de ${_formatEuroEntier.format(min)} HT';
    } else {
      montant = '${_formatEuroEntier.format(max ?? min)} HT';
    }

    return TicketCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.point_of_sale_outlined, size: 19, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terminal $montant',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Achat unique, non compté dans le coût mensuel ci-dessus.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// D'où viennent les chiffres affichés, et depuis quand.
///
/// La distinction n'est pas cosmétique : une grille relevée sur le site
/// du prestataire et une fourchette indicative n'engagent pas la même
/// chose. Tant que cet écran annonçait « Tarifs vérifiés » pour tout le
/// monde, une banque qui ne publie aucun tarif se présentait comme
/// vérifiée.
class _MentionSource extends StatelessWidget {
  const _MentionSource({required this.provider});

  final TpeProvider provider;

  static const sourceVerifiee = 'vérifiée';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final verifie = provider.source == sourceVerifiee;
    // La date affichée est celle du relevé, pas celle du jour : dater la
    // vérification d'aujourd'hui reviendrait à affirmer un contrôle qui
    // n'a pas eu lieu.
    final date = provider.derniereMaj;
    final quand = date == null
        ? null
        : DateFormat('d MMMM yyyy', 'fr_FR').format(date);

    final texte = verifie
        ? [
            'Vérifié sur le site officiel du prestataire',
            if (quand != null) ', le $quand',
            '.',
          ].join()
        : [
            'Fourchette indicative : ce prestataire ne publie pas de grille '
                'tarifaire',
            if (quand != null) ' (relevé du $quand)',
            '.',
          ].join();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          verifie ? Icons.verified_outlined : Icons.help_outline,
          size: 15,
          color: verifie ? colors.savings : colors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

final _formatEuro = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);

/// Les taux s'écrivent avec au plus deux décimales, sans zéro inutile
/// (1,75 % mais 2 % plutôt que 2,00 %).
final _formatPourcent = NumberFormat('0.##', 'fr_FR');

/// Les prix de matériel sont annoncés en euros entiers (39 €, 249 €) :
/// les afficher « 39,00 € » ferait faussement précis.
final _formatEuroEntier = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 0,
);

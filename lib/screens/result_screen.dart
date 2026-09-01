import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_breakdown.dart';
import '../models/provider.dart';
import '../models/saved_calculation.dart';
import '../services/calculation_store.dart';
import '../services/entitlement.dart';
import '../services/fee_calculator.dart';
import '../services/pdf_report_service.dart';
import '../services/report_sharing.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/comparison_gauge.dart';
import '../widgets/save_calculation_sheet.dart';
import '../widgets/ticket_card.dart';
import 'comparison_table_screen.dart';
import 'paywall_screen.dart';

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
    required this.store,
    this.panierMoyen,
    this.calculator = const FeeCalculator(),
    this.pdfService = const PdfReportService(),
    this.sharing = const PrintingReportSharing(),
  });

  final double volumeMensuel;

  /// Panier moyen saisi par l'utilisateur ; `null` = valeur par défaut.
  final double? panierMoyen;

  final TpeProvider providerActuel;
  final List<TpeProvider> providers;
  final FeeCalculator calculator;
  final Entitlement entitlement;
  final PdfReportService pdfService;
  final ReportSharing sharing;
  final CalculationStore store;

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
                  calculator: calculator,
                  pdfService: pdfService,
                  sharing: sharing,
                  store: store,
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
    required this.calculator,
    required this.pdfService,
    required this.sharing,
    required this.store,
  });

  final ComparisonResult resultat;
  final double volumeMensuel;
  final double? panierMoyen;
  final List<TpeProvider> providers;
  final TpeProvider providerActuel;
  final Entitlement entitlement;
  final FeeCalculator calculator;
  final PdfReportService pdfService;
  final ReportSharing sharing;
  final CalculationStore store;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = _formatEuro;

    return ValueListenableBuilder<bool>(
      valueListenable: entitlement,
      builder: (context, deverrouille, _) => TicketCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComparisonGauge(
            currentLabel: "Aujourd'hui",
            currentAmount: resultat.actuel.totalMensuel,
            // Le montant de l'économie suffit à donner envie ; c'est le
            // nom du gagnant qu'on vend. Il reste masqué tant que l'achat
            // n'est pas fait.
            optimizedLabel: deverrouille
                ? 'Avec ${resultat.optimise.provider.nom}'
                : 'La meilleure offre',
            optimizedAmount: resultat.optimise.totalMensuel,
          ),
          if (!resultat.dejaOptimal) ...[
            const SizedBox(height: 16),
            _NoteHachure(),
          ],
          const SizedBox(height: 16),
          _EncartEconomie(resultat: resultat),
          if (resultat.optimiseSansCompte != null) ...[
            const SizedBox(height: 12),
            _SansChangerDeBanque(
              resultat: resultat,
              deverrouille: deverrouille,
            ),
          ],
          // Le détail explique une économie : hors de propos quand il n'y
          // en a pas, où il ne listerait que des écarts défavorables.
          if (!resultat.dejaOptimal && resultat.ecartParPoste.isNotEmpty) ...[
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
          _BoutonPdf(
            resultat: resultat,
            volumeMensuel: volumeMensuel,
            panierMoyen: panierMoyen,
            providers: providers,
            entitlement: entitlement,
            calculator: calculator,
            pdfService: pdfService,
            sharing: sharing,
          ),
          const SizedBox(height: 10),
          _BoutonSauvegarde(
            volumeMensuel: volumeMensuel,
            panierMoyen: panierMoyen,
            providerActuel: providerActuel,
            entitlement: entitlement,
            store: store,
          ),
          const SizedBox(height: 10),
          // Bouton bordé et non lien discret : à l'essai, personne ne
          // trouvait le tableau comparatif, qui est pourtant le cœur de
          // ce que l'app a à montrer.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
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
              icon: Icon(Icons.table_rows_outlined, size: 19,
                  color: colors.accent),
              label: Text(
                providers.length > 1
                    ? 'Comparer les ${providers.length} offres'
                    : 'Voir le détail des offres',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// La meilleure offre qui ne demande pas d'ouvrir un compte ailleurs.
///
/// Sans elle, le classement désigne le même gagnant à tout le monde, y
/// compris à qui n'a aucune intention de changer de banque : une réponse
/// exacte et inutilisable. Son nom reste masqué avant l'achat, comme
/// celui de la meilleure offre.
class _SansChangerDeBanque extends StatelessWidget {
  const _SansChangerDeBanque({
    required this.resultat,
    required this.deverrouille,
  });

  final ComparisonResult resultat;
  final bool deverrouille;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offre = resultat.optimiseSansCompte!;
    final economie = resultat.economieSansCompteMensuelle!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_outlined, size: 18,
              color: colors.textSecondary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SANS CHANGER DE BANQUE',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  deverrouille ? offre.provider.nomComplet : 'Une autre offre',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatEuro.format(offre.totalMensuel),
                style: context.amountStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '- ${_formatEuro.format(economie)}',
                style: context.amountStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.savings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Le bouton d'export PDF, verrouillé tant que l'achat n'est pas fait
/// (§4). Non débloqué, il mène au paywall plutôt que de se griser : un
/// bouton inerte n'explique rien.
class _BoutonPdf extends StatefulWidget {
  const _BoutonPdf({
    required this.resultat,
    required this.volumeMensuel,
    required this.panierMoyen,
    required this.providers,
    required this.entitlement,
    required this.calculator,
    required this.pdfService,
    required this.sharing,
  });

  final ComparisonResult resultat;
  final double volumeMensuel;
  final double? panierMoyen;
  final List<TpeProvider> providers;
  final Entitlement entitlement;
  final FeeCalculator calculator;
  final PdfReportService pdfService;
  final ReportSharing sharing;

  @override
  State<_BoutonPdf> createState() => _BoutonPdfState();
}

class _BoutonPdfState extends State<_BoutonPdf> {
  bool _enCours = false;

  Future<void> _appuyer() async {
    if (!widget.entitlement.estDebloque) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaywallScreen(entitlement: widget.entitlement),
        ),
      );
      // Au retour, si l'achat vient d'être fait, on enchaîne sur l'export
      // plutôt que d'obliger à ré-appuyer.
      if (!mounted || !widget.entitlement.estDebloque) return;
    }
    await _exporter();
  }

  Future<void> _exporter() async {
    setState(() => _enCours = true);
    try {
      final classement = widget.calculator.classer(
        providers: widget.providers,
        volumeMensuel: widget.volumeMensuel,
        panierMoyen: widget.panierMoyen,
      );
      final document = await widget.pdfService.construire(
        resultat: widget.resultat,
        classement: classement,
        volumeMensuel: widget.volumeMensuel,
        panierMoyen: widget.panierMoyen,
      );
      await widget.sharing.partager(
        document: document,
        nomFichier: 'frais-tpe-rapport.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le rapport n'a pas pu être créé. Réessayez."),
        ),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.entitlement,
      builder: (context, deverrouille, _) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _enCours ? null : _appuyer,
            child: _enCours
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!deverrouille) ...[
                        Icon(Icons.lock_outline, size: 16, color: colors.onPrimary),
                        const SizedBox(width: 8),
                      ],
                      const Text('Recevoir le détail en PDF'),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Sauvegarde du calcul (§4 : fonctionnalité débloquée par l'achat).
///
/// Bouton secondaire : l'export PDF reste l'action principale de l'écran.
class _BoutonSauvegarde extends StatefulWidget {
  const _BoutonSauvegarde({
    required this.volumeMensuel,
    required this.panierMoyen,
    required this.providerActuel,
    required this.entitlement,
    required this.store,
  });

  final double volumeMensuel;
  final double? panierMoyen;
  final TpeProvider providerActuel;
  final Entitlement entitlement;
  final CalculationStore store;

  @override
  State<_BoutonSauvegarde> createState() => _BoutonSauvegardeState();
}

class _BoutonSauvegardeState extends State<_BoutonSauvegarde> {
  Future<void> _appuyer() async {
    if (!widget.entitlement.estDebloque) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaywallScreen(entitlement: widget.entitlement),
        ),
      );
      if (!mounted || !widget.entitlement.estDebloque) return;
    }

    final libelle = await demanderLibelleCalcul(
      context,
      libelleParDefaut: libelleParDefautPour(
        nomPrestataire: widget.providerActuel.nomComplet,
        volumeMensuel: widget.volumeMensuel,
      ),
    );
    if (libelle == null || !mounted) return;

    await widget.store.enregistrer(
      SavedCalculation(
        // L'horodatage sert d'identifiant : deux sauvegardes successives
        // du même calcul créent deux entrées, ce qui correspond à ce que
        // l'utilisateur voit.
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        libelle: libelle,
        volumeMensuel: widget.volumeMensuel,
        panierMoyen: widget.panierMoyen,
        providerActuelId: widget.providerActuel.id,
        // Un prestataire saisi à la main n'existe pas en base : ses
        // tarifs partent avec le calcul, sans quoi il serait impossible
        // de le rouvrir.
        providerPerso: widget.providerActuel.estPersonnalise
            ? widget.providerActuel
            : null,
        creeLe: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calcul enregistré.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.entitlement,
      builder: (context, deverrouille, _) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _appuyer,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.divider),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  deverrouille ? Icons.bookmark_outline : Icons.lock_outline,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Enregistrer ce calcul',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
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
    // Un poste sur lequel la nouvelle offre coûte plus cher doit se lire
    // comme tel : sans le signe, un abonnement plus élevé passerait pour
    // une économie et le détail ne tomberait pas juste.
    final economise = ligne.montantMensuel >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              ligne.libelle,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${economise ? '-' : '+'} '
            '${format.format(ligne.montantMensuel.abs())}',
            style: context.amountStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: economise ? colors.textPrimary : colors.textSecondary,
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

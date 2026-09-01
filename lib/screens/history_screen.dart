import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/provider.dart';
import '../models/saved_calculation.dart';
import '../services/calculation_store.dart';
import '../services/entitlement.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket_card.dart';
import 'result_screen.dart';

/// Écran 7 du parcours (§8) : les calculs sauvegardés.
///
/// Rouvrir un calcul le rejoue sur les tarifs du moment plutôt que
/// d'afficher un résultat figé : les grilles évoluent, et c'est justement
/// ce qui rend l'historique utile.
///
/// L'évolution des coûts dans le temps reste hors périmètre (§3.3) : on
/// conserve des calculs, on ne trace pas de courbe.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.store,
    required this.entitlement,
    this.firestoreService,
  });

  final CalculationStore store;
  final Entitlement entitlement;
  final FirestoreService? firestoreService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final FirestoreService _service;
  List<TpeProvider> _providers = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _service = widget.firestoreService ?? FirestoreService();
    _charger();
  }

  Future<void> _charger() async {
    await widget.store.charger();
    try {
      final providers = await _service.getProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
    }
  }

  Future<void> _ouvrir(SavedCalculation calcul) async {
    // Le prestataire saisi par l'utilisateur prime : il n'est pas en base,
    // ses tarifs ont voyagé avec le calcul.
    final actuel = calcul.providerPerso ??
        _providers.where((p) => p.id == calcul.providerActuelId).firstOrNull;

    if (actuel == null) {
      // Le prestataire a disparu de la base : rejouer le calcul
      // donnerait un résultat faux, on le dit plutôt que de l'inventer.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ce prestataire n'est plus disponible : le calcul ne peut pas "
            "être rouvert.",
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          volumeMensuel: calcul.volumeMensuel,
          panierMoyen: calcul.panierMoyen,
          providerActuel: actuel,
          providers: [
            ..._providers,
            if (calcul.providerPerso != null) calcul.providerPerso!,
          ],
          entitlement: widget.entitlement,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _supprimer(SavedCalculation calcul) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce calcul ?'),
        content: Text('« ${calcul.libelle} » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme ?? false) {
      await widget.store.supprimer(calcul.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final calculs = widget.store.calculs;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vos calculs',
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    calculs.isEmpty
                        ? 'Rien de sauvegardé pour le moment.'
                        : 'Rouvrir un calcul le recalcule avec les tarifs '
                            'à jour.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (calculs.isEmpty)
                    _EtatVide()
                  else
                    for (final calcul in calculs) ...[
                      _LigneCalcul(
                        calcul: calcul,
                        chargement: _chargement,
                        onOuvrir: () => _ouvrir(calcul),
                        onSupprimer: () => _supprimer(calcul),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LigneCalcul extends StatelessWidget {
  const _LigneCalcul({
    required this.calcul,
    required this.chargement,
    required this.onOuvrir,
    required this.onSupprimer,
  });

  final SavedCalculation calcul;
  final bool chargement;
  final VoidCallback onOuvrir;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formatVolume = NumberFormat.decimalPattern('fr_FR');
    final formatDate = DateFormat('d MMMM yyyy', 'fr_FR');

    return InkWell(
      onTap: chargement ? null : onOuvrir,
      borderRadius: BorderRadius.circular(20),
      child: TicketCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    calcul.libelle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${formatVolume.format(calcul.volumeMensuel)} € par mois',
                    style: context.amountStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Enregistré le ${formatDate.format(calcul.creeLe)}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSupprimer,
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colors.textSecondary,
              ),
              tooltip: 'Supprimer',
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bookmark_outline, size: 22, color: colors.accent),
          const SizedBox(height: 10),
          Text(
            'Aucun calcul sauvegardé',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            "Depuis un résultat, enregistrez le calcul pour le retrouver ici "
            "et le rejouer plus tard avec les tarifs à jour.",
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/provider.dart';
import '../services/calculation_store.dart';
import '../services/entitlement.dart';
import '../services/fee_calculator.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket_card.dart';
import 'result_screen.dart';

/// Écran 2 du parcours (§8) : saisie du volume/CA mensuel encaissé par
/// carte, et du prestataire actuel.
///
/// Un seul chiffre obligatoire : c'est le point de friction principal du
/// parcours, tout le reste est optionnel.
class VolumeInputScreen extends StatefulWidget {
  const VolumeInputScreen({
    super.key,
    required this.entitlement,
    required this.store,
    this.firestoreService,
  });

  final Entitlement entitlement;
  final CalculationStore store;

  /// Injectable pour les tests ; par défaut, l'instance Firestore réelle.
  final FirestoreService? firestoreService;

  @override
  State<VolumeInputScreen> createState() => _VolumeInputScreenState();
}

class _VolumeInputScreenState extends State<VolumeInputScreen> {
  final _controller = TextEditingController();
  final _panierController = TextEditingController();
  late final FirestoreService _service;

  List<TpeProvider> _providers = const [];
  TpeProvider? _providerActuel;
  bool _chargement = true;
  String? _erreur;

  /// Le panier moyen est replié par défaut : il ne concerne que les
  /// utilisateurs dont le ticket s'écarte nettement de la moyenne.
  bool _optionsOuvertes = false;

  static const _montantsSuggeres = [2000.0, 4000.0, 8000.0];

  @override
  void initState() {
    super.initState();
    _service = widget.firestoreService ?? FirestoreService();
    _chargerProviders();
  }

  @override
  void dispose() {
    _controller.dispose();
    _panierController.dispose();
    super.dispose();
  }

  Future<void> _chargerProviders() async {
    try {
      final providers = await _service.getProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = "Impossible de charger les tarifs. Vérifiez votre connexion.";
        _chargement = false;
      });
    }
  }

  double? _montantSaisi(TextEditingController controller) {
    final texte = controller.text
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    final valeur = double.tryParse(texte);
    return (valeur != null && valeur > 0) ? valeur : null;
  }

  double? get _volume => _montantSaisi(_controller);

  /// `null` si l'utilisateur n'a rien saisi : le calcul retombe alors sur
  /// [FeeCalculator.panierMoyenParDefaut].
  double? get _panierMoyen => _montantSaisi(_panierController);

  bool get _peutComparer =>
      _volume != null && _providerActuel != null && !_chargement;

  void _comparer() {
    final volume = _volume;
    final actuel = _providerActuel;
    if (volume == null || actuel == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          volumeMensuel: volume,
          panierMoyen: _panierMoyen,
          providerActuel: actuel,
          providers: _providers,
          entitlement: widget.entitlement,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Combien encaissez-vous\npar carte ?',
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 25,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TicketCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VOLUME CB MENSUEL',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Le « € » est un Text à part plutôt qu'un
                            // suffixText : Flutter masque le suffixe tant que
                            // le champ est vide et non focalisé, or l'unité
                            // doit rester lisible en permanence.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    autofocus: true,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9 ,.]'),
                                      ),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    style: context.amountStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: context.amountStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textSecondary,
                                      ),
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Text(
                                  '€',
                                  style: context.amountStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: colors.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const TicketPerforation(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (final montant in _montantsSuggeres) ...[
                                  _PuceMontant(
                                    montant: montant,
                                    selectionne: _volume == montant,
                                    onTap: () {
                                      _controller.text =
                                          montant.toStringAsFixed(0);
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'VOTRE PRESTATAIRE ACTUEL',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_chargement)
                        const _EtatChargement()
                      else if (_erreur != null)
                        _EtatErreur(message: _erreur!, onRetry: () {
                          setState(() {
                            _chargement = true;
                            _erreur = null;
                          });
                          _chargerProviders();
                        })
                      else
                        _SelecteurPrestataire(
                          providers: _providers,
                          selection: _providerActuel,
                          onChanged: (p) => setState(() => _providerActuel = p),
                        ),
                      const SizedBox(height: 20),
                      _OptionsAvancees(
                        ouvert: _optionsOuvertes,
                        onToggle: () => setState(
                          () => _optionsOuvertes = !_optionsOuvertes,
                        ),
                        panierController: _panierController,
                        onPanierChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _peutComparer ? _comparer : null,
                  child: const Text('Comparer les frais'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Réglages optionnels, repliés par défaut.
///
/// Le panier moyen sert à estimer le nombre de transactions, donc les
/// frais fixes par paiement. La valeur par défaut convient à la plupart
/// des commerces, mais l'écart est réel entre un artisan (gros tickets,
/// peu de transactions) et un institut (tickets moyens, beaucoup de
/// transactions) — d'où la possibilité de la corriger.
class _OptionsAvancees extends StatelessWidget {
  const _OptionsAvancees({
    required this.ouvert,
    required this.onToggle,
    required this.panierController,
    required this.onPanierChanged,
  });

  final bool ouvert;
  final VoidCallback onToggle;
  final TextEditingController panierController;
  final VoidCallback onPanierChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  ouvert ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Affiner le calcul',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              ouvert ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TicketCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PANIER MOYEN PAR PAIEMENT',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: panierController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9 ,.]'),
                            ),
                          ],
                          onChanged: (_) => onPanierChanged(),
                          style: context.amountStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                          ),
                          decoration: InputDecoration(
                            hintText: FeeCalculator.panierMoyenParDefaut
                                .toStringAsFixed(0),
                            hintStyle: context.amountStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      Text(
                        '€',
                        style: context.amountStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Le montant moyen d'un paiement par carte chez vous. "
                    "Sert à estimer les frais facturés à la transaction. "
                    "Laissez vide si vous ne savez pas.",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PuceMontant extends StatelessWidget {
  const _PuceMontant({
    required this.montant,
    required this.selectionne,
    required this.onTap,
  });

  final double montant;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = NumberFormat.decimalPattern('fr_FR');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selectionne ? colors.primary : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${format.format(montant)} €',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selectionne ? colors.onPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SelecteurPrestataire extends StatelessWidget {
  const _SelecteurPrestataire({
    required this.providers,
    required this.selection,
    required this.onChanged,
  });

  final List<TpeProvider> providers;
  final TpeProvider? selection;
  final ValueChanged<TpeProvider?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (providers.isEmpty) {
      return Text(
        'Aucun prestataire disponible pour le moment.',
        style: TextStyle(color: colors.textSecondary),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TpeProvider>(
          value: selection,
          isExpanded: true,
          hint: Text(
            'Choisir…',
            style: TextStyle(color: colors.textSecondary),
          ),
          dropdownColor: colors.surface,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(vertical: 6),
          items: [
            for (final p in providers)
              DropdownMenuItem(value: p, child: Text(p.nom)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EtatChargement extends StatelessWidget {
  const _EtatChargement();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Chargement des tarifs…',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EtatErreur extends StatelessWidget {
  const _EtatErreur({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: colors.accent,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

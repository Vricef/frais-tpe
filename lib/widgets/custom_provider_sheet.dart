import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Formulaire de saisie du prestataire actuel quand il est absent de la
/// base.
///
/// Sert aux prestataires non couverts (Smile&Pay, Yavin, Stancer, Revolut
/// Business…) et aux tarifs négociés individuellement, que personne ne
/// peut connaître à la place du commerçant.
///
/// [initial] pré-remplit les champs pour corriger une saisie précédente.
///
/// Renvoie le prestataire saisi, ou `null` si l'utilisateur abandonne.
Future<TpeProvider?> afficherFormulairePrestataire(
  BuildContext context, {
  required String id,
  TpeProvider? initial,
}) {
  return showModalBottomSheet<TpeProvider>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FormulairePrestataire(id: id, initial: initial),
  );
}

class _FormulairePrestataire extends StatefulWidget {
  const _FormulairePrestataire({required this.id, this.initial});

  final String id;
  final TpeProvider? initial;

  @override
  State<_FormulairePrestataire> createState() => _FormulairePrestataireState();
}

class _FormulairePrestataireState extends State<_FormulairePrestataire> {
  final _nom = TextEditingController();
  final _commission = TextEditingController();
  final _fraisFixe = TextEditingController();
  final _abonnement = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _nom.text = initial.nom;
    _commission.text = _texte(initial.fraisTransactionCb);
    _fraisFixe.text = _texte(initial.fraisFixeTransaction);
    _abonnement.text = _texte(initial.fraisMensuels);
  }

  /// Virgule décimale : le champ est relu par l'utilisateur, pas par
  /// une machine.
  static String _texte(double? valeur) {
    if (valeur == null) return '';
    final brut = valeur.toStringAsFixed(2);
    return brut.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  @override
  void dispose() {
    _nom.dispose();
    _commission.dispose();
    _fraisFixe.dispose();
    _abonnement.dispose();
    super.dispose();
  }

  double? _valeur(TextEditingController c) {
    final texte =
        c.text.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
    final v = double.tryParse(texte);
    return (v != null && v > 0) ? v : null;
  }

  /// La commission est le seul champ obligatoire : sans elle, il n'y a
  /// rien à comparer.
  bool get _valide => _valeur(_commission) != null;

  void _valider() {
    final commission = _valeur(_commission);
    if (commission == null) return;

    final nom = _nom.text.trim();
    Navigator.of(context).pop(
      TpeProvider(
        id: widget.id,
        nom: nom.isEmpty ? 'Mon prestataire' : nom,
        type: ProviderType.processeurPaiement,
        fraisTransactionCb: commission,
        fraisFixeTransaction: _valeur(_fraisFixe),
        fraisMensuels: _valeur(_abonnement),
        estPersonnalise: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // Laisse la place au clavier : sans ça, les champs du bas passent
      // dessous et deviennent inatteignables.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.initial == null
                    ? 'Votre prestataire'
                    : 'Corriger vos tarifs',
                style: textTheme.headlineMedium?.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 8),
              Text(
                "Pour un prestataire absent de la liste, ou un tarif que "
                "vous avez négocié. Ces montants figurent sur votre relevé "
                "mensuel ou votre contrat.",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _Champ(
                libelle: 'NOM (OPTIONNEL)',
                controller: _nom,
                indice: 'Mon prestataire',
                numerique: false,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _Champ(
                libelle: 'COMMISSION PAR PAIEMENT',
                controller: _commission,
                indice: '1,75',
                suffixe: '%',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _Champ(
                libelle: 'FRAIS FIXE PAR TRANSACTION (OPTIONNEL)',
                controller: _fraisFixe,
                indice: '0,10',
                suffixe: '€',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _Champ(
                libelle: 'ABONNEMENT MENSUEL (OPTIONNEL)',
                controller: _abonnement,
                indice: '0',
                suffixe: '€',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valide ? _valider : null,
                  child: const Text('Utiliser ce prestataire'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  const _Champ({
    required this.libelle,
    required this.controller,
    required this.indice,
    required this.onChanged,
    this.suffixe,
    this.numerique = true,
  });

  final String libelle;
  final TextEditingController controller;
  final String indice;
  final String? suffixe;
  final bool numerique;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libelle,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 10.5,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: numerique
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: numerique
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
                    : null,
                onChanged: (_) => onChanged(),
                style: numerique
                    ? context.amountStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      )
                    : TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                decoration: InputDecoration(
                  hintText: indice,
                  hintStyle: TextStyle(
                    color: colors.textSecondary,
                    fontSize: numerique ? 19 : 16,
                    fontWeight: numerique ? FontWeight.w700 : FontWeight.w500,
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (suffixe != null) ...[
              const SizedBox(width: 8),
              Text(
                suffixe!,
                style: context.amountStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

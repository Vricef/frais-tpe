import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// Demande un nom pour le calcul à sauvegarder.
///
/// Un libellé par défaut est proposé : la plupart des utilisateurs
/// valideront sans y toucher, et un historique de « Calcul 1, Calcul 2 »
/// ne servirait à personne.
Future<String?> demanderLibelleCalcul(
  BuildContext context, {
  required String libelleParDefaut,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FormulaireLibelle(defaut: libelleParDefaut),
  );
}

/// Libellé proposé : le prestataire et le volume, ce qui distingue deux
/// calculs au premier coup d'œil.
String libelleParDefautPour({
  required String nomPrestataire,
  required double volumeMensuel,
}) {
  final volume = NumberFormat.decimalPattern('fr_FR').format(volumeMensuel);
  return '$nomPrestataire — $volume €/mois';
}

class _FormulaireLibelle extends StatefulWidget {
  const _FormulaireLibelle({required this.defaut});

  final String defaut;

  @override
  State<_FormulaireLibelle> createState() => _FormulaireLibelleState();
}

class _FormulaireLibelleState extends State<_FormulaireLibelle> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.defaut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final libelle = _controller.text.trim();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              'Enregistrer ce calcul',
              style: textTheme.headlineMedium?.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous le retrouverez dans « Vos calculs », recalculé avec les '
              'tarifs à jour.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (libelle.isNotEmpty) Navigator.of(context).pop(libelle);
              },
              decoration: const InputDecoration(hintText: 'Nom du calcul'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: libelle.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(libelle),
                child: const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

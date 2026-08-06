import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Un montant verrouillé par le paywall.
///
/// Volontairement construit pour ne rien laisser déduire de la valeur
/// masquée :
///
/// * **Largeur fixe** ([_largeur]) — un placeholder dimensionné d'après le
///   texte réel trahirait l'ordre de grandeur (3 chiffres vs 5).
/// * **Le montant n'est jamais passé à ce widget** — il n'existe donc ni
///   dans l'arbre de widgets, ni dans l'arbre de sémantique lu par les
///   lecteurs d'écran. Un simple `Opacity` ou un flou par-dessus le vrai
///   `Text` aurait laissé la valeur accessible.
/// * **Aucune variation d'apparence** d'une ligne à l'autre : même nombre
///   de points, même couleur, quel que soit le montant caché.
class MaskedAmount extends StatelessWidget {
  const MaskedAmount({super.key});

  static const double _largeur = 58;
  static const double _hauteur = 15;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Montant verrouillé',
      // `container: true` est nécessaire : sans nœud de sémantique propre,
      // l'annotation n'aurait rien à annoter — les points décoratifs n'en
      // produisent aucun — et le lecteur d'écran passerait la case en
      // silence au lieu d'annoncer qu'elle est verrouillée.
      container: true,
      excludeSemantics: true,
      child: Container(
        width: _largeur,
        height: _hauteur,
        decoration: BoxDecoration(
          color: colors.track,
          borderRadius: BorderRadius.circular(_hauteur / 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

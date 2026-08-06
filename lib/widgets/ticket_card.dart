import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// La carte "ticket de caisse" : surface claire, coins arrondis, filet
/// discret. Support visuel commun à tous les écrans.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.divider),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Le liseré perforé d'un ticket de caisse : une ligne de tirets.
/// Utilisé pour séparer deux blocs sans la dureté d'un trait plein.
class TicketPerforation extends StatelessWidget {
  const TicketPerforation({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.divider;
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashGap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => SizedBox(
              width: dashWidth,
              height: 1,
              child: ColoredBox(color: color),
            ),
          ),
        );
      },
    );
  }
}

/// L'en-tête de l'app : pastille terre cuite + nom, éventuellement suivi
/// d'une information de contexte alignée à droite (ex. le volume saisi).
class TicketHeader extends StatelessWidget {
  const TicketHeader({super.key, this.trailing});

  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, color: colors.onPrimary, size: 18),
        ),
        const SizedBox(width: 10),
        Text('Frais TPE', style: Theme.of(context).textTheme.titleMedium),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

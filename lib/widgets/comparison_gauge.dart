import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// La jauge à deux barres sur une même échelle : facture actuelle vs
/// facture optimisée. L'écart entre les deux est le message — matérialisé
/// en hachures terre cuite, jamais en rouge alarmant.
///
/// Au montage, les barres se remplissent de 0 à leur longueur en 500 ms ;
/// la hachure n'apparaît qu'à la fin de l'animation.
class ComparisonGauge extends StatefulWidget {
  const ComparisonGauge({
    super.key,
    required this.currentLabel,
    required this.currentAmount,
    required this.optimizedLabel,
    required this.optimizedAmount,
    this.duration = const Duration(milliseconds: 500),
  });

  final String currentLabel;
  final double currentAmount;
  final String optimizedLabel;
  final double optimizedAmount;
  final Duration duration;

  @override
  State<ComparisonGauge> createState() => _ComparisonGaugeState();
}

class _ComparisonGaugeState extends State<ComparisonGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fillAnimation;
  late final Animation<double> _hachureOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 1, curve: Curves.easeOut),
    );
    _hachureOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(widget.currentAmount, widget.optimizedAmount);
    final optimizedFraction =
        maxValue == 0 ? 0.0 : widget.optimizedAmount / maxValue;
    final currentFraction =
        maxValue == 0 ? 0.0 : widget.currentAmount / maxValue;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GaugeRow(
              label: widget.currentLabel,
              amount: widget.currentAmount,
              child: _GaugeBar(
                filledFraction: currentFraction * _fillAnimation.value,
                filledColor: context.colors.track,
                hachureFrom: optimizedFraction * _fillAnimation.value,
                hachureOpacity: _hachureOpacity.value,
              ),
            ),
            const SizedBox(height: 16),
            _GaugeRow(
              label: widget.optimizedLabel,
              amount: widget.optimizedAmount,
              child: _GaugeBar(
                filledFraction: optimizedFraction * _fillAnimation.value,
                filledColor: context.colors.savings,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({
    required this.label,
    required this.amount,
    required this.child,
  });

  final String label;
  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              format.format(amount),
              style: context.amountStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Une barre de la jauge : un fond neutre (`track`), une portion remplie,
/// et éventuellement un segment hachuré représentant l'écart.
class _GaugeBar extends StatelessWidget {
  const _GaugeBar({
    required this.filledFraction,
    required this.filledColor,
    this.hachureFrom,
    this.hachureOpacity = 0,
  });

  /// Fraction (0-1) de la largeur totale occupée par [filledColor].
  final double filledFraction;
  final Color filledColor;

  /// Fraction (0-1) à partir de laquelle le segment hachuré commence.
  /// `null` = pas de hachure sur cette barre.
  final double? hachureFrom;
  final double hachureOpacity;

  static const double _height = 12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.track)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: filledFraction.clamp(0, 1),
                child: ColoredBox(color: filledColor),
              ),
            ),
            if (hachureFrom != null)
              Positioned.fill(
                child: Opacity(
                  opacity: hachureOpacity,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: (1 - hachureFrom!).clamp(0, 1),
                    child: CustomPaint(
                      painter: _HachurePainter(
                        stripeColor: colors.hachure,
                        backgroundTint: colors.hachure.withValues(alpha: 0.16),
                      ),
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

/// Motif de hachures diagonales terre cuite représentant l'écart —
/// désamorcé (pas de rouge), le message porte sur la longueur, pas la
/// couleur.
class _HachurePainter extends CustomPainter {
  const _HachurePainter({required this.stripeColor, required this.backgroundTint});

  final Color stripeColor;
  final Color backgroundTint;

  static const double _stripeWidth = 3;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundTint);

    final paint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stripeWidth;

    final diagonal = size.width + size.height;
    for (double x = -size.height; x < diagonal; x += _stripeWidth + _gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HachurePainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor ||
        oldDelegate.backgroundTint != backgroundTint;
  }
}

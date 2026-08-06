import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ticket_card.dart';
import 'volume_input_screen.dart';

/// Écran 1 du parcours (cahier des charges §8) : présentation rapide de
/// l'app.
///
/// Ton chaleureux et rassurant : la cible n'est pas technophile, la
/// promesse doit tenir en une phrase et le premier geste être évident.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const TicketHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Vos frais de carte\nsont-ils trop élevés ?',
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 30,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Indiquez ce que vous encaissez par carte chaque mois. "
                        "On compare les offres et on vous dit, chiffres à l'appui, "
                        "ce que vous pourriez économiser.",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _Argument(
                        icone: Icons.timer_outlined,
                        titre: 'Une minute suffit',
                        detail:
                            "Un seul chiffre à saisir, aucun compte à créer, "
                            "aucune connexion bancaire.",
                      ),
                      const SizedBox(height: 16),
                      const _Argument(
                        icone: Icons.visibility_outlined,
                        titre: 'Le détail, pas juste un chiffre',
                        detail:
                            "Chaque euro d'écart est expliqué poste par poste : "
                            "commission, abonnement, terminal.",
                      ),
                      const SizedBox(height: 16),
                      const _Argument(
                        icone: Icons.block_outlined,
                        titre: 'Zéro publicité',
                        detail:
                            "Aucune pub, jamais. On ne revend pas vos données.",
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const VolumeInputScreen(),
                      ),
                    );
                  },
                  child: const Text('Comparer mes frais'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Gratuit — sans inscription',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
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

class _Argument extends StatelessWidget {
  const _Argument({
    required this.icone,
    required this.titre,
    required this.detail,
  });

  final IconData icone;
  final String titre;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

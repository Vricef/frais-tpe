import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ticket_card.dart';

/// Écran affiché quand l'app n'a pas pu démarrer normalement.
///
/// Sans lui, une initialisation Firebase en échec laisse un écran noir :
/// `runApp` n'est jamais atteint, donc rien n'est rendu et rien n'est dit.
/// Mieux vaut une explication qu'un écran vide, pour l'utilisateur comme
/// pour celui qui déboguera.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    super.key,
    required this.erreur,
    this.afficherDetail = false,
    this.onReessayer,
  });

  final Object erreur;

  /// Permet de relancer l'initialisation sans quitter l'app : une panne
  /// réseau passagère ne doit pas obliger à redémarrer.
  final VoidCallback? onReessayer;

  /// Affiche le message technique. Réservé au mode debug : il n'aiderait
  /// pas un commerçant, et l'inquiéterait plutôt.
  final bool afficherDetail;

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
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 30,
                        color: colors.accent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "L'application n'a pas pu\ndémarrer",
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Les grilles tarifaires n'ont pas pu être chargées. "
                        "Vérifiez votre connexion et relancez l'application.",
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (afficherDetail) ...[
                        const SizedBox(height: 24),
                        TicketCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DÉTAIL TECHNIQUE',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SelectableText(
                                '$erreur',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Firebase n'est pas configuré pour cette "
                                "plateforme. Lancez « flutterfire configure » "
                                "à la racine du projet, puis relancez l'app.",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              if (onReessayer != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onReessayer,
                    child: const Text('Réessayer'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

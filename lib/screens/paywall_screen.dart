import 'package:flutter/material.dart';

import '../services/entitlement.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket_card.dart';

/// Écran 5 du parcours (§8) : le déblocage par achat unique.
///
/// Achat unique à 3,99 €, pas d'abonnement, et rappel explicite de
/// l'absence de publicité — la contrainte ferme du §4 est aussi le
/// meilleur argument de vente auprès de la cible.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.entitlement});

  final Entitlement entitlement;

  static const double prix = 3.99;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: const CloseButton()),
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
                      Text(
                        'Débloquez la comparaison complète',
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Un seul paiement, définitif. Pas un abonnement.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TicketCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Avantage(
                              icone: Icons.table_rows_outlined,
                              texte: 'Le coût exact de toutes les offres, '
                                  'pas seulement la meilleure',
                            ),
                            const SizedBox(height: 14),
                            const _Avantage(
                              icone: Icons.picture_as_pdf_outlined,
                              texte: 'Export PDF du rapport détaillé',
                            ),
                            const SizedBox(height: 14),
                            const _Avantage(
                              icone: Icons.bookmark_outline,
                              texte: 'Sauvegarde de vos calculs',
                            ),
                            const SizedBox(height: 16),
                            const TicketPerforation(),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '3,99 €',
                                  style: context.amountStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.block_outlined,
                            size: 17,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              "Aucune publicité, ni avant ni après l'achat. "
                              "Vos données ne sont pas revendues.",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO(iap) : brancher `in_app_purchase` — ici, le
                    // déblocage est simulé le temps de configurer les
                    // produits sur App Store Connect et Play Console.
                    entitlement.debloquer();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Débloquer pour 3,99 €'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restauration — à brancher avec l\'achat'),
                      ),
                    );
                  },
                  child: Text(
                    'Restaurer un achat',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
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

class _Avantage extends StatelessWidget {
  const _Avantage({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 19, color: colors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

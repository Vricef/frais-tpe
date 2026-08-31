import 'package:flutter/material.dart';

import '../services/entitlement.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket_card.dart';

/// Écran 5 du parcours (§8) : le déblocage par achat unique.
///
/// Achat unique à 3,99 €, pas d'abonnement, et rappel explicite de
/// l'absence de publicité — la contrainte ferme du §4 est aussi le
/// meilleur argument de vente auprès de la cible.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.entitlement, this.achats});

  final Entitlement entitlement;

  /// Injectable pour les tests ; par défaut, la boutique de la plateforme.
  final PurchaseService? achats;

  /// Prix de repli, affiché tant que la boutique n'a pas répondu. Le prix
  /// réel vient d'elle : lui seul est juste dans la devise et avec les
  /// taxes du pays de l'utilisateur.
  static const double prix = 3.99;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PurchaseService _achats;
  late final bool _serviceInterne;

  @override
  void initState() {
    super.initState();
    // Le service de l'app quand il existe, sinon un service local — le
    // même flux d'achats écouté deux fois ferait finaliser chaque
    // transaction deux fois.
    final partage = FournisseurAchats.lireDe(context);
    _serviceInterne = widget.achats == null && partage == null;
    _achats = widget.achats ??
        partage ??
        PurchaseService(entitlement: widget.entitlement);
    _achats.addListener(_surChangement);
    if (_serviceInterne) _achats.demarrer();
  }

  @override
  void dispose() {
    _achats.removeListener(_surChangement);
    // Seul le service créé ici lui appartient : disposer de celui qu'on
    // nous a passé couperait l'écoute de son propriétaire.
    if (_serviceInterne) _achats.dispose();
    super.dispose();
  }

  void _surChangement() {
    if (!mounted) return;
    final erreur = _achats.erreur;
    if (erreur != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(erreur)));
      _achats.oublierErreur();
    }
    // Le déblocage referme l'écran : rester dessus après avoir payé
    // laisserait croire que l'achat n'a pas pris.
    if (widget.entitlement.estDebloque && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

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
              if (_achats.etat == EtatAchat.indisponible)
                _BoutiqueIndisponible()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _achats.peutAcheter ? _achats.acheter : null,
                    child: _achats.etat == EtatAchat.enCours
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        // Le prix vient de la boutique dès qu'elle a
                        // répondu ; celui du cahier des charges ne sert
                        // qu'à ne pas afficher un bouton sans montant.
                        : Text('Débloquer pour ${_achats.prix ?? _prixDeRepli}'),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _achats.etat == EtatAchat.enCours
                      ? null
                      : _achats.restaurer,
                  child: Text(
                    'Restaurer mes achats',
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

/// Prix de repli, écrit à la française : « 3,99 € ».
final String _prixDeRepli =
    '${PaywallScreen.prix.toStringAsFixed(2).replaceAll('.', ',')} €';

/// Ni bouton d'achat ni prix quand il n'y a rien à vendre : proposer un
/// paiement qui échouera est pire que de l'annoncer.
class _BoutiqueIndisponible extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TicketCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 19, color: colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "L'achat n'est pas disponible pour le moment. Vérifiez votre "
              "connexion, puis réessayez.",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
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

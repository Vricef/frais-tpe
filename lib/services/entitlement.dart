import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// L'état du déblocage par achat unique (§4 : 2,99 €).
///
/// Déblocage : comparaison multi-prestataires, export PDF, sauvegarde.
///
/// L'état est conservé sur l'appareil en plus d'être connu de la
/// boutique. Sans cela, l'app redemanderait à la boutique à chaque
/// démarrage — donc verrouillerait tout hors connexion, pour un achat
/// pourtant définitif. La boutique reste la source de vérité : c'est elle
/// que [PurchaseService] interroge à la restauration.
class Entitlement extends ValueNotifier<bool> {
  Entitlement({bool debloque = false, this.stockage = const _PrefsStockage()})
      : super(debloque);

  /// Clé locale. Un utilisateur déterminé peut la forcer sur un appareil
  /// rooté ; le contournement lui coûterait plus cher que les 2,99 €, et
  /// la parade — une vérification serveur — imposerait un compte, que le
  /// cahier des charges exclut.
  static const cle = 'entitlement_debloque';

  final StockageEntitlement stockage;

  bool get estDebloque => value;

  /// Relit l'état au démarrage. Un échec de lecture laisse l'app
  /// verrouillée plutôt que débloquée : la restauration reste ouverte à
  /// l'utilisateur, alors qu'un déblocage indu serait invisible.
  Future<void> charger() async {
    try {
      if (await stockage.lire()) value = true;
    } catch (e) {
      debugPrint('Lecture du déblocage impossible : $e');
    }
  }

  Future<void> debloquer() async {
    value = true;
    try {
      await stockage.ecrire(true);
    } catch (e) {
      // L'achat vaut pour cette session même si l'écriture échoue ; la
      // restauration le rétablira au prochain lancement.
      debugPrint('Écriture du déblocage impossible : $e');
    }
  }
}

/// Isolé pour que les tests n'aient pas à simuler le stockage du système.
abstract class StockageEntitlement {
  Future<bool> lire();
  Future<void> ecrire(bool debloque);
}

class _PrefsStockage implements StockageEntitlement {
  const _PrefsStockage();

  @override
  Future<bool> lire() async =>
      (await SharedPreferences.getInstance()).getBool(Entitlement.cle) ?? false;

  @override
  Future<void> ecrire(bool debloque) async =>
      (await SharedPreferences.getInstance()).setBool(Entitlement.cle, debloque);
}

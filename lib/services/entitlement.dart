import 'package:flutter/foundation.dart';

/// L'état du déblocage par achat unique (§4 : 3,99 €).
///
/// Déblocage : comparaison multi-prestataires, export PDF, sauvegarde.
///
/// L'achat in-app réel (`in_app_purchase` + configuration des stores)
/// n'est pas encore branché : [debloquer] fait aujourd'hui basculer
/// l'état en mémoire. Le reste de l'app ne dépend que de cette interface,
/// donc le branchement se fera ici sans toucher aux écrans.
class Entitlement extends ValueNotifier<bool> {
  Entitlement({bool debloque = false}) : super(debloque);

  bool get estDebloque => value;

  void debloquer() => value = true;
}

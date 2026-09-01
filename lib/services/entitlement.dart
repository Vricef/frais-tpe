import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// L'état du déblocage (§4), sous ses deux formes : un rapport à
/// 0,99 €, ou tout à vie pour 4,99 €.
///
/// L'illimité est un achat non consommable : la boutique le connaît et
/// sait le restaurer. Le rapport à l'unité est un consommable, qu'aucune
/// boutique ne restaure — il ne vaut donc que pour la comparaison qui
/// l'a déclenché, conservée sur l'appareil.
///
/// Reste un `ValueNotifier<bool>` : les écrans n'ont à connaître que la
/// réponse — débloqué ou non — et aucun n'a changé.
class Entitlement extends ValueNotifier<bool> {
  Entitlement({
    bool debloque = false,
    this.stockage = const _PrefsStockage(),
  })  : _illimite = debloque,
        super(debloque);

  static const cleIllimite = 'entitlement_debloque';
  static const cleComparaisons = 'entitlement_comparaisons';

  final StockageEntitlement stockage;

  bool _illimite;
  final Set<String> _comparaisons = {};
  String? _comparaisonCourante;

  /// L'achat définitif, restaurable auprès de la boutique.
  bool get estIllimite => _illimite;

  /// La comparaison affichée en ce moment. Les écrans la posent en
  /// arrivant ; c'est elle que déverrouille un rapport à l'unité.
  String? get comparaisonCourante => _comparaisonCourante;

  set comparaisonCourante(String? cle) {
    if (_comparaisonCourante == cle) return;
    _comparaisonCourante = cle;
    _recalculer();
  }

  bool get estDebloque => value;

  /// Une comparaison est identifiée par ses entrées : deux calculs sur le
  /// même volume, le même panier et le même prestataire donnent le même
  /// résultat, et un seul achat doit les couvrir — y compris rouvert
  /// depuis l'historique des mois plus tard.
  static String cleDe({
    required double volumeMensuel,
    required double? panierMoyen,
    required String providerActuelId,
  }) {
    final volume = volumeMensuel.toStringAsFixed(2);
    final panier = panierMoyen?.toStringAsFixed(2) ?? 'defaut';
    return '$providerActuelId|$volume|$panier';
  }

  bool comparaisonEstDebloquee(String cle) =>
      _illimite || _comparaisons.contains(cle);

  /// Relit l'état au démarrage. Un échec de lecture laisse l'app
  /// verrouillée plutôt que débloquée : la restauration reste ouverte à
  /// l'utilisateur, alors qu'un déblocage indu serait invisible.
  Future<void> charger() async {
    try {
      _illimite = _illimite || await stockage.lireIllimite();
      _comparaisons.addAll(await stockage.lireComparaisons());
    } catch (e) {
      debugPrint('Lecture du déblocage impossible : $e');
    }
    _recalculer();
  }

  /// L'achat définitif.
  Future<void> debloquer() async {
    _illimite = true;
    _recalculer();
    try {
      await stockage.ecrireIllimite(true);
    } catch (e) {
      // L'achat vaut pour cette session même si l'écriture échoue ; la
      // restauration le rétablira au prochain lancement.
      debugPrint('Écriture du déblocage impossible : $e');
    }
  }

  /// Le rapport à l'unité, acquis pour [cle] — par défaut la comparaison
  /// en cours, celle que l'utilisateur avait sous les yeux en payant.
  Future<void> debloquerComparaison([String? cle]) async {
    final cible = cle ?? _comparaisonCourante;
    if (cible == null) {
      debugPrint('Rapport acheté sans comparaison courante : rien à ouvrir.');
      return;
    }
    _comparaisons.add(cible);
    _recalculer();
    try {
      await stockage.ecrireComparaisons(_comparaisons);
    } catch (e) {
      debugPrint('Écriture de la comparaison débloquée impossible : $e');
    }
  }

  void _recalculer() {
    value = _illimite ||
        (_comparaisonCourante != null &&
            _comparaisons.contains(_comparaisonCourante));
  }
}

/// Isolé pour que les tests n'aient pas à simuler le stockage du système.
abstract class StockageEntitlement {
  Future<bool> lireIllimite();
  Future<void> ecrireIllimite(bool illimite);
  Future<Set<String>> lireComparaisons();
  Future<void> ecrireComparaisons(Set<String> comparaisons);
}

class _PrefsStockage implements StockageEntitlement {
  const _PrefsStockage();

  @override
  Future<bool> lireIllimite() async =>
      (await SharedPreferences.getInstance()).getBool(Entitlement.cleIllimite) ??
      false;

  @override
  Future<void> ecrireIllimite(bool illimite) async =>
      (await SharedPreferences.getInstance())
          .setBool(Entitlement.cleIllimite, illimite);

  @override
  Future<Set<String>> lireComparaisons() async =>
      (await SharedPreferences.getInstance())
          .getStringList(Entitlement.cleComparaisons)
          ?.toSet() ??
      {};

  @override
  Future<void> ecrireComparaisons(Set<String> comparaisons) async =>
      (await SharedPreferences.getInstance())
          .setStringList(Entitlement.cleComparaisons, comparaisons.toList());
}

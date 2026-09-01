import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_calculation.dart';

/// Conservation des calculs sauvegardés.
///
/// Le stockage est **local à l'appareil**, pas dans Firestore. L'app ne
/// demande aucune inscription (§3.1) : mettre ces données en ligne
/// supposerait une identité, donc une authentification, donc un compte —
/// exactement ce que le parcours promet d'éviter. Le revers est assumé :
/// les calculs ne suivent pas d'un téléphone à l'autre et disparaissent
/// avec l'app.
abstract class CalculationStore extends ChangeNotifier {
  List<SavedCalculation> get calculs;

  Future<void> charger();
  Future<void> enregistrer(SavedCalculation calcul);
  Future<void> supprimer(String id);
}

class PrefsCalculationStore extends ChangeNotifier implements CalculationStore {
  PrefsCalculationStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _cle = 'calculs_sauvegardes';

  SharedPreferences? _prefs;
  List<SavedCalculation> _calculs = const [];

  @override
  List<SavedCalculation> get calculs => List.unmodifiable(_calculs);

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<void> charger() async {
    final prefs = await _instance;
    _calculs = SavedCalculation.decodeListe(prefs.getString(_cle));
    _trier();
    notifyListeners();
  }

  @override
  Future<void> enregistrer(SavedCalculation calcul) async {
    // Un même identifiant écrase l'entrée existante : renommer ou
    // réenregistrer un calcul ne doit pas en créer un doublon.
    _calculs = [
      ..._calculs.where((c) => c.id != calcul.id),
      calcul,
    ];
    _trier();
    await _persister();
    notifyListeners();
  }

  @override
  Future<void> supprimer(String id) async {
    _calculs = _calculs.where((c) => c.id != id).toList();
    await _persister();
    notifyListeners();
  }

  /// Du plus récent au plus ancien : l'historique se consulte par le haut.
  void _trier() {
    _calculs = [..._calculs]..sort((a, b) => b.creeLe.compareTo(a.creeLe));
  }

  Future<void> _persister() async {
    final prefs = await _instance;
    await prefs.setString(_cle, SavedCalculation.encodeListe(_calculs));
  }
}

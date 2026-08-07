import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/startup_error_screen.dart';
import 'services/calculation_store.dart';
import 'services/entitlement.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nécessaire avant tout DateFormat en fr_FR (dates de mise à jour des
  // grilles tarifaires) : sans ça, le formatage lève une exception.
  await initializeDateFormatting('fr_FR');

  // L'initialisation de Firebase échoue tant que la configuration native
  // n'est pas en place (google-services.json / GoogleService-Info.plist).
  // Laisser l'exception remonter empêcherait `runApp` d'être appelé : rien
  // ne s'afficherait, pas même un message — un écran noir muet, dont la
  // cause est introuvable sans lire les logs.
  Object? erreurDemarrage;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    erreurDemarrage = e;
    debugPrint('Firebase n\'a pas pu être initialisé : $e');
  }

  runApp(FraisTpeApp(erreurDemarrage: erreurDemarrage));
}

class FraisTpeApp extends StatelessWidget {
  FraisTpeApp({
    super.key,
    Entitlement? entitlement,
    CalculationStore? store,
    this.erreurDemarrage,
  })  : entitlement = entitlement ?? Entitlement(),
        store = store ?? PrefsCalculationStore();

  /// État du déblocage par achat unique, partagé par tous les écrans.
  final Entitlement entitlement;

  /// Calculs sauvegardés, conservés localement sur l'appareil.
  final CalculationStore store;

  /// Renseigné si Firebase n'a pas pu démarrer : l'app s'ouvre alors sur
  /// un écran d'explication plutôt que sur un parcours qui n'aboutirait
  /// à rien, faute de grilles tarifaires.
  final Object? erreurDemarrage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frais TPE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Suit le réglage clair/sombre du téléphone.
      themeMode: ThemeMode.system,
      home: erreurDemarrage == null
          ? HomeScreen(entitlement: entitlement, store: store)
          : StartupErrorScreen(
              erreur: erreurDemarrage!,
              // Le détail technique n'a de sens que pendant le
              // développement ; l'utilisateur final n'en ferait rien.
              afficherDetail: kDebugMode,
            ),
    );
  }
}

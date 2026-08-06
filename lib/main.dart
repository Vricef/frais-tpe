import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/entitlement.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nécessaire avant tout DateFormat en fr_FR (dates de mise à jour des
  // grilles tarifaires) : sans ça, le formatage lève une exception.
  await initializeDateFormatting('fr_FR');
  await Firebase.initializeApp();
  runApp(FraisTpeApp());
}

class FraisTpeApp extends StatelessWidget {
  FraisTpeApp({super.key, Entitlement? entitlement})
      : entitlement = entitlement ?? Entitlement();

  /// État du déblocage par achat unique, partagé par tous les écrans.
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frais TPE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Suit le réglage clair/sombre du téléphone.
      themeMode: ThemeMode.system,
      home: HomeScreen(entitlement: entitlement),
    );
  }
}

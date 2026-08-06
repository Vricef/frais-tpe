import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FraisTpeApp());
}

class FraisTpeApp extends StatelessWidget {
  const FraisTpeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frais TPE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Suit le réglage clair/sombre du téléphone.
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

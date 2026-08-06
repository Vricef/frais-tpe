import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FraisTpeApp());
}

class FraisTpeApp extends StatelessWidget {
  const FraisTpeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Frais TPE',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Frais TPE')),
      ),
    );
  }
}

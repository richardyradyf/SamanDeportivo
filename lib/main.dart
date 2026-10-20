
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SamanDeportivoApp());
}

class SamanDeportivoApp extends StatelessWidget {
  const SamanDeportivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samán Deportivo',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Samán Deportivo'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            '¡Bienvenido a Samán Deportivo!',
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
  
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/router/auth_gate.dart';
import 'firebase_options.dart';
import 'features/auth/controllers/sesion_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/registro_screen.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    // MultiProvider: aquí se registran TODOS los controllers globales.
    // Si alguien necesita otro, lo agrega a esta lista (avisando al Gestor).
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // lazy: false → el controller se crea al arrancar la app y empieza
          // a escuchar la sesión de inmediato (por defecto Provider lo
          // crearía recién cuando una pantalla lo pida).
          lazy: false,
          create: (_) => SesionController(),
        ),
      ],
      child: const SamanDeportivoApp(),
    ),
  );
}

class SamanDeportivoApp extends StatelessWidget {
  const SamanDeportivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samán Deportivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      home: const AuthGate(
        sinSesion: const LoginScreen(),
      ),
    );
  }
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samán Deportivo'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 20),
              const Text(
                '¡Bienvenido a Samán Deportivo!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gestiona tus actividades deportivas en la UNIMET',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistroScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Registrarme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Conexión opcional al emulador de Firebase para desarrollar.
///
/// Por defecto la app usa el proyecto real. Para usar el emulador:
///   1. `npm run emulador` (y la primera vez `npm run emulador:datos`)
///   2. `flutter run -d chrome --dart-define=USAR_EMULADOR=true`
const bool usarEmulador = bool.fromEnvironment('USAR_EMULADOR');

/// Llamar en `main()` justo después de `Firebase.initializeApp`.
Future<void> conectarEmuladorSiCorresponde() async {
  if (!usarEmulador) return;

  // El emulador de Android ve la computadora en 10.0.2.2.
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
}

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:saman_deportivo/core/config/entorno.dart';
import 'package:saman_deportivo/firebase_options.dart';

/// Alta de entrenadores compatible con Firebase Spark.
/// IMPORTANTE: el SDK cliente no tiene privilegios de Admin SDK. Las reglas
/// verifican que el usuario principal sea administrador y que usuario+cedula
/// se creen juntos. Auth y Firestore NO son una misma transacción atómica.
class SparkEntrenadorProvisioner {
  SparkEntrenadorProvisioner({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _passwordTemporal() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<String?> crear({
    required String nombre,
    required String correo,
    required String cedula,
    required String especialidad,
    required int aniosExperiencia,
  }) async {
    final email = correo.trim().toLowerCase();
    final nombreLimpio = nombre.trim();
    final cedulaLimpia = cedula.trim();
    final especialidadLimpia = especialidad.trim();

    if (nombreLimpio.length < 3 || nombreLimpio.length > 100 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email.length > 150 ||
        !RegExp(r'^\d{5,20}$').hasMatch(cedulaLimpia) ||
        especialidadLimpia.length < 2 || especialidadLimpia.length > 100 ||
        aniosExperiencia < 0 || aniosExperiencia > 60) {
      throw ArgumentError('Los datos del entrenador no son válidos.');
    }

    final administrador = _auth.currentUser;
    if (administrador == null) {
      throw StateError('Inicia sesión como administrador.');
    }
    final perfilAdmin = await _firestore.collection('usuarios')
        .doc(administrador.uid).get();
    if (perfilAdmin.data()?['rol'] != 'administrador') {
      throw StateError('Solo un administrador puede crear entrenadores.');
    }

    // Un nombre único evita reutilizar accidentalmente la sesión secundaria.
    final nombreApp = 'registroEntrenador-${DateTime.now().microsecondsSinceEpoch}';
    final app = await Firebase.initializeApp(
      name: nombreApp,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final authSecundaria = FirebaseAuth.instanceFor(app: app);
    User? creado;
    var perfilCreado = false;
    try {
      if (usarEmulador) {
        final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : 'localhost';
        await authSecundaria.useAuthEmulator(host, 9099);
      }

      final credencial = await authSecundaria.createUserWithEmailAndPassword(
        email: email,
        password: _passwordTemporal(),
      );
      creado = credencial.user;
      if (creado == null) throw StateError('Auth no devolvió el UID del entrenador.');
      final uid = creado.uid;
      final usuarioRef = _firestore.collection('usuarios').doc(uid);
      final indiceRef = _firestore.collection('cedulas').doc(cedulaLimpia);

      await _firestore.runTransaction<void>((tx) async {
        // Todas las lecturas deben ir antes de las escrituras.
        final existente = await tx.get(indiceRef);
        final usuarioExistente = await tx.get(usuarioRef);
        if (existente.exists || usuarioExistente.exists) {
          throw StateError('La cédula o el usuario ya están registrados.');
        }
        tx.set(indiceRef, {'uid': uid});
        tx.set(usuarioRef, {
          'nombre': nombreLimpio,
          'correo': email,
          'cedula': cedulaLimpia,
          'rol': 'entrenador',
          'especialidad': especialidadLimpia,
          'aniosExperiencia': aniosExperiencia,
        });
      });
      perfilCreado = true;
    } catch (error) {
      // Auth y Firestore no forman una sola transacción: rollback compensatorio.
      // Si falla, NO podemos garantizar que no quede una cuenta huérfana.
      if (!perfilCreado && creado != null) {
        try {
          await creado.delete();
        } catch (rollbackError) {
          throw StateError(
            'Falló el registro y también la reversión en Auth. '
            'Revisar la cuenta huérfana: ${creado.uid}. '
            'Error original: $error. Rollback: $rollbackError',
          );
        }
      }
      rethrow;
    } finally {
      try { await authSecundaria.signOut(); } catch (_) {/* App temporal */}
      await app.delete();
    }

    // Enviar desde la app principal; no devuelve link ni contraseña al admin.
    // Si el correo falla, la cuenta ya existe: el entrenador debe utilizar
    // Recuperar contraseña y el administrador puede reenviar invitación.
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      return null;
    }
    return null; // Firma histórica de CrearEntrenadorDialog.
  }

  Future<void> reenviarInvitacion(String correo) =>
      _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
}

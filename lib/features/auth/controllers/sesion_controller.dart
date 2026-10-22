import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/services/auth_service.dart';

enum EstadoSesion {
  /// Todavía no sabemos si hay sesión (arranque de la app o cargando perfil).
  cargando,

  sinSesion,

  /// Hay usuario en Firebase Auth pero aún no existe su documento
  /// en `usuarios` (ocurre un instante durante el registro) o sus datos
  /// son inválidos (ver [SesionController.error]).
  sinPerfil,

  /// Sesión iniciada y perfil cargado → mostrar el inicio según el rol.
  autenticado,
}

/// Controlador global de la sesión (Provider / ChangeNotifier).

class SesionController extends ChangeNotifier {
  /// Los parámetros opcionales permiten inyectar dependencias falsas en
  /// pruebas. En la app normal se usan las instancias reales.
  SesionController({AuthService? authService, FirebaseFirestore? firestore})
    : _authService = authService ?? AuthService(),
      _firestore = firestore ?? FirebaseFirestore.instance {
    // Empezamos a escuchar los cambios de sesión desde que se crea.
    _subAuth = _authService.cambiosDeSesion.listen(_alCambiarSesion);
  }

  final AuthService _authService;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _subAuth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subPerfil;

  EstadoSesion _estado = EstadoSesion.cargando;
  Persona? _persona;
  String? _error;

  // ---------- Lo que pueden leer las pantallas ----------

  EstadoSesion get estado => _estado;

  /// La persona en sesión (Estudiante, Entrenador o Administrador),
  /// o null si no hay sesión.
  Persona? get persona => _persona;

  /// Rol del usuario en sesión, o null si no hay sesión.
  Rol? get rol => _persona?.rol;

  /// Mensaje de error si el perfil no se pudo cargar.
  String? get error => _error;

  bool get estaAutenticado => _estado == EstadoSesion.autenticado;

  // ---------- Acciones ----------

  Future<void> cerrarSesion() => _authService.cerrarSesion();

  // ---------- Lógica interna ----------

  /// Se ejecuta cada vez que Firebase Auth avisa de un cambio.
  void _alCambiarSesion(User? usuario) {
    // Si había un perfil escuchándose (de otra sesión), lo soltamos.
    _subPerfil?.cancel();
    _subPerfil = null;
    _persona = null;
    _error = null;

    if (usuario == null) {
      _cambiarEstado(EstadoSesion.sinSesion);
      return;
    }

    _cambiarEstado(EstadoSesion.cargando);

    _subPerfil = _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .snapshots()
        .listen(
          (documento) => _alCambiarPerfil(usuario.uid, documento),
          onError: (Object e) {
            _error = 'No se pudo cargar el perfil: $e';
            _cambiarEstado(EstadoSesion.sinPerfil);
          },
        );
  }

  /// Convierte el documento de Firestore en una Persona.
  void _alCambiarPerfil(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data();

    if (!documento.exists || datos == null) {
      _persona = null;
      _cambiarEstado(EstadoSesion.sinPerfil);
      return;
    }

    try {
      _persona = Persona.fromMap(uid, datos);
      _error = null;
      _cambiarEstado(EstadoSesion.autenticado);
    } on ArgumentError catch (e) {
      _persona = null;
      _error = 'El perfil tiene datos inválidos: ${e.message}';
      _cambiarEstado(EstadoSesion.sinPerfil);
    }
  }

  /// Cambia el estado y avisa a todos los widgets que escuchan.
  void _cambiarEstado(EstadoSesion nuevo) {
    _estado = nuevo;
    if (kDebugMode) {
      debugPrint('[Sesion] estado=${nuevo.name} rol=${_persona?.rol.name}');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subAuth?.cancel();
    _subPerfil?.cancel();
    super.dispose();
  }
}

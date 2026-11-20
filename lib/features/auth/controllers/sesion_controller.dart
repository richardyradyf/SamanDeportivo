import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/services/auth_service.dart';

import 'espera_perfil.dart';

typedef ObservarDatosPerfil = Stream<Map<String, dynamic>?> Function(String uid);

enum EstadoSesion {
  /// Todavía no sabemos si hay sesión (arranque de la app o cargando perfil).
  cargando,

  sinSesion,

  /// Hay usuario en Firebase Auth pero no apareció su perfil tras el tiempo
  /// de gracia, o su documento contiene datos inválidos.
  sinPerfil,

  /// Sesión iniciada y perfil cargado → mostrar el inicio según el rol.
  autenticado,
}

/// Controlador global de la sesión (Provider / ChangeNotifier).

class SesionController extends ChangeNotifier {
  /// Las fuentes de UID/perfil se pueden inyectar sin inicializar Firebase,
  /// para comprobar la transición real en pruebas de widgets.
  SesionController({
    AuthService? authService,
    FirebaseFirestore? firestore,
    Stream<String?>? cambiosUid,
    ObservarDatosPerfil? observarDatosPerfil,
    Future<void> Function()? cerrarSesion,
    Duration graciaPerfil = const Duration(seconds: 10),
  }) : _esperaPerfil = EsperaPerfil(duracion: graciaPerfil) {
    final origenAuth = cambiosUid == null || cerrarSesion == null
        ? (authService ?? AuthService())
        : null;

    _cerrarSesion = cerrarSesion ?? origenAuth!.cerrarSesion;
    _observarDatosPerfil = observarDatosPerfil ?? (uid) {
      final base = firestore ?? FirebaseFirestore.instance;
      return base.collection('usuarios').doc(uid).snapshots().map(
        (snapshot) => snapshot.data(),
      );
    };

    _subAuth = (cambiosUid ??
            origenAuth!.cambiosDeSesion.map((usuario) => usuario?.uid))
        .listen(_alCambiarSesion);
  }

  late final Future<void> Function() _cerrarSesion;
  late final ObservarDatosPerfil _observarDatosPerfil;

  StreamSubscription<String?>? _subAuth;
  StreamSubscription<Map<String, dynamic>?>? _subPerfil;
  final EsperaPerfil _esperaPerfil;
  int _generacionSesion = 0;
  bool _ausenciaConfirmada = false;

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

  Future<void> cerrarSesion() => _cerrarSesion();

  // ---------- Lógica interna ----------

  /// Se ejecuta cada vez que Firebase Auth avisa de un cambio.
  void _alCambiarSesion(String? uid) {
    // Ignorar eventos tardíos de sesiones anteriores y cancelar la espera.
    final generacion = ++_generacionSesion;
    _esperaPerfil.cancelar();
    _ausenciaConfirmada = false;
    // Si había un perfil escuchándose (de otra sesión), lo soltamos.
    _subPerfil?.cancel();
    _subPerfil = null;
    _persona = null;
    _error = null;

    if (uid == null) {
      _cambiarEstado(EstadoSesion.sinSesion);
      return;
    }

    _cambiarEstado(EstadoSesion.cargando);

    _subPerfil = _observarDatosPerfil(uid).listen(
          (datos) {
            if (generacion != _generacionSesion) return;
            _alCambiarPerfil(uid, datos);
          },
          onError: (Object e) {
            if (generacion != _generacionSesion) return;
            _esperaPerfil.cancelar();
            _error = 'No se pudo cargar el perfil: $e';
            _cambiarEstado(EstadoSesion.sinPerfil);
          },
        );
  }

  /// Convierte el documento de Firestore en una Persona.
  void _alCambiarPerfil(String uid, Map<String, dynamic>? datos) {
    if (datos == null) {
      _persona = null;
      if (_ausenciaConfirmada) return;
      // Firebase Auth emite la nueva sesión antes de que termine la escritura
      // transaccional de usuarios/{uid}. Mantener el loading unos segundos.
      final generacion = _generacionSesion;
      _esperaPerfil.iniciar(() {
        if (generacion != _generacionSesion) return;
        _ausenciaConfirmada = true;
        _error = 'Tu cuenta aún no tiene un perfil en Samán Deportivo. '
            'Si el registro acaba de comenzar, intenta de nuevo en unos segundos.';
        _cambiarEstado(EstadoSesion.sinPerfil);
      });
      if (_estado != EstadoSesion.cargando) {
        _cambiarEstado(EstadoSesion.cargando);
      }
      return;
    }

    _esperaPerfil.cancelar();
    _ausenciaConfirmada = false;
    try {
      _persona = Persona.fromMap(uid, datos);
      _error = null;
      _cambiarEstado(EstadoSesion.autenticado);
    } catch (e) {
      _persona = null;
      _error = 'El perfil tiene datos inválidos: $e';
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
    ++_generacionSesion;
    _esperaPerfil.cancelar();
    _subAuth?.cancel();
    _subPerfil?.cancel();
    super.dispose();
  }
}

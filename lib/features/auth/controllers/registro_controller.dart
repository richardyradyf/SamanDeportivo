
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/estudiante.dart';
import '../../../services/auth_service.dart';
import '../../../services/usuario_service.dart';

class RegistroController extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  bool _registroExitoso = false;

  bool get cargando => _cargando;
  String? get error => _error;
  bool get registroExitoso => _registroExitoso;

  // Validar los datos del estudiante.
  String? validarDatos({
    required String nombre,
    required String cedula,
    required String carnet,
    required String correo,
    required String contrasena,
  }) {
    final nombreLimpio = nombre.trim();
    final cedulaLimpia = cedula.trim();
    final carnetLimpio = carnet.trim();
    final correoLimpio = correo.trim().toLowerCase();

    // Nombre y apellido.
    final palabras = nombreLimpio.split(RegExp(r'\s+'));

    if (palabras.length < 2 ||
        palabras.any((palabra) => palabra.length < 2) ||
        !RegExp(
          r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$',
        ).hasMatch(nombreLimpio)) {
      return 'Debes ingresar nombre y apellido válidos';
    }

    if (nombreLimpio.length > 100) {
      return 'El nombre no puede superar los 100 caracteres';
    }

    // Cédula: entre 5 y 20 dígitos.
    if (!RegExp(r'^[0-9]+$').hasMatch(cedulaLimpia)) {
      return 'La cédula debe contener solo números';
    }

    if (cedulaLimpia.length < 5 ||
        cedulaLimpia.length > 20) {
      return 'La cédula debe tener entre 5 y 20 dígitos';
    }

    // Carnet: letras, números y guiones.
    if (carnetLimpio.isEmpty) {
      return 'Debes ingresar tu número de carnet';
    }

    if (!RegExp(
      r'^[a-zA-Z0-9-]{4,24}$',
    ).hasMatch(carnetLimpio)) {
      return 'El carnet debe tener entre 4 y 24 caracteres '
          'y solo puede contener letras, números o guiones';
    }

    // Correo institucional UNIMET.
    final correoValido = RegExp(
      r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
      caseSensitive: false,
    );

    if (!correoValido.hasMatch(correoLimpio)) {
      return 'Debes utilizar un correo institucional UNIMET';
    }

    // Contraseña.
    if (contrasena.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

  // Estados utilizados por la pantalla.
  void cambiarCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  void mostrarError(String mensaje) {
    _error = mensaje;
    _registroExitoso = false;
    notifyListeners();
  }

  void limpiarEstado() {
    _error = null;
    _registroExitoso = false;
    notifyListeners();
  }

  void confirmarRegistro() {
    _error = null;
    _registroExitoso = true;
    _cargando = false;
    notifyListeners();
  }

  // Registrar al estudiante en Firebase.
  Future<void> registrarEstudiante({
    required String nombre,
    required String cedula,
    required String carnet,
    required String correo,
    required String contrasena,
  }) async {
    if (_cargando) return;

    limpiarEstado();

    final errorValidacion = validarDatos(
      nombre: nombre,
      cedula: cedula,
      carnet: carnet,
      correo: correo,
      contrasena: contrasena,
    );

    if (errorValidacion != null) {
      mostrarError(errorValidacion);
      return;
    }

    cambiarCargando(true);

    final correoNormalizado = correo.trim().toLowerCase();
    final authService = AuthService();
    final usuarioService = UsuarioService();

    User? cuentaCreada;
    bool perfilGuardado = false;

    try {
      // 1. Crear la cuenta en Firebase Authentication.
      final credencial = await authService.registrarUsuario(
        correo: correoNormalizado,
        contrasena: contrasena,
      );

      cuentaCreada = credencial.user;

      if (cuentaCreada == null) {
        throw Exception('Firebase no devolvió un usuario válido');
      }

      // 2. Crear el perfil del estudiante activo.
      final estudiante = Estudiante(
        uid: cuentaCreada.uid,
        cedula: cedula.trim(),
        nombre: nombre.trim(),
        correo: correoNormalizado,
        carnet: carnet.trim(),
      );

      // 3. Guardar el perfil en Cloud Firestore.
      await usuarioService.guardarEstudiante(estudiante);
      perfilGuardado = true;

      // 4. Confirmar el registro.
      confirmarRegistro();
    } on FirebaseAuthException catch (e) {
      mostrarError(_mensajeErrorFirebase(e.code));
    } catch (e) {
      mostrarError(
        'No se pudo completar el registro. '
        'Verifica tu conexión e inténtalo nuevamente.',
      );

      if (kDebugMode) {
        debugPrint('Error durante el registro: $e');
      }
    } finally {
      // Si la cuenta se creó pero falló el perfil,
      // intentar eliminar la cuenta incompleta.
      if (cuentaCreada != null && !perfilGuardado) {
        try {
          await cuentaCreada.delete();
        } catch (e) {
          mostrarError(
            'No se pudo guardar el perfil ni eliminar '
            'la cuenta incompleta. Contacta al administrador.',
          );

          if (kDebugMode) {
            debugPrint('Error al eliminar cuenta incompleta: $e');
          }
        }
      }

      if (_cargando) {
        cambiarCargando(false);
      }
    }
  }

  // Mensajes de errores de Firebase Authentication.
  String _mensajeErrorFirebase(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado';

      case 'invalid-email':
        return 'El correo electrónico no es válido';

      case 'weak-password':
        return 'La contraseña es demasiado débil';

      case 'network-request-failed':
        return 'Error de conexión. Revisa tu internet';

      case 'operation-not-allowed':
        return 'El registro con correo y contraseña no está habilitado';

      default:
        return 'Ocurrió un error al registrar tu cuenta';
    }
  }
}

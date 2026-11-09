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

    final palabras = nombreLimpio.split(RegExp(r'\s+'));

    if (palabras.length < 2 ||
        palabras.any((palabra) => palabra.length < 2) ||
        !RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$').hasMatch(nombreLimpio)) {
      return 'Debes ingresar nombre y apellido válidos';
    }

    if (nombreLimpio.length > 100) {
      return 'El nombre no puede superar los 100 caracteres';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(cedulaLimpia)) {
      return 'La cédula debe contener solo números';
    }

    if (cedulaLimpia.length < 5 || cedulaLimpia.length > 20) {
      return 'La cédula debe tener entre 5 y 20 dígitos';
    }

    if (carnetLimpio.isEmpty) {
      return 'Debes ingresar tu número de carnet';
    }

    if (!RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(carnetLimpio)) {
      return 'El carnet debe tener entre 4 y 24 caracteres '
          'y solo puede contener letras, números o guiones';
    }

    final correoValido = RegExp(
      r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
      caseSensitive: false,
    );

    if (!correoValido.hasMatch(correoLimpio)) {
      return 'Debes utilizar un correo institucional UNIMET';
    }

    if (contrasena.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

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
      // 1. Crear cuenta en Firebase Authentication.
      final credencial = await authService.registrarUsuario(
        correo: correoNormalizado,
        contrasena: contrasena,
      );

      cuentaCreada = credencial.user;

      if (cuentaCreada == null) {
        throw StateError('Firebase no devolvió un usuario válido');
      }

      // 2. Preparar perfil del estudiante.
      final estudiante = Estudiante(
        uid: cuentaCreada.uid,
        cedula: cedula.trim(),
        nombre: nombre.trim(),
        correo: correoNormalizado,
        carnet: carnet.trim(),
      );

      // 3. Guardar perfil e índices en Firestore.
      await usuarioService.guardarEstudiante(estudiante);
      perfilGuardado = true;

      // 4. Confirmar registro exitoso.
      confirmarRegistro();
    } on FirebaseAuthException catch (e) {
      mostrarError(_mensajeErrorFirebase(e.code));
      _registrarErrorTecnico(e);
    } on FirebaseException catch (e) {
      mostrarError(_mensajeErrorFirestore(e.code));
      _registrarErrorTecnico(e);
    } on ArgumentError catch (e) {
      mostrarError(
        'Los datos ingresados no son válidos. '
        'Revisa la cédula y el carnet.',
      );
      _registrarErrorTecnico(e);
    } on StateError catch (e) {
      // Estos mensajes vienen de validaciones
      // explícitas de nuestro servicio.
      final mensaje = e.message;

      if (mensaje.contains('ya esta registrada') ||
          mensaje.contains('ya tiene un perfil')) {
        mostrarError(mensaje);
      } else {
        mostrarError(
          'No se pudo completar el registro. '
          'Contacta al administrador si el problema continúa.',
        );
      }

      _registrarErrorTecnico(e);
    } catch (e) {
      mostrarError(
        'Ocurrió un problema inesperado durante el registro. '
        'Inténtalo nuevamente.',
      );
      _registrarErrorTecnico(e);
    } finally {
      // Si Authentication creó la cuenta, pero
      // Firestore rechazó el perfil, intentar eliminarla.
      if (cuentaCreada != null && !perfilGuardado) {
        try {
          await cuentaCreada.delete();
        } catch (e) {
          mostrarError(
            'No se pudo completar el registro y quedó una '
            'cuenta incompleta. Contacta al administrador.',
          );
          _registrarErrorTecnico(e);
        }
      }

      if (_cargando) {
        cambiarCargando(false);
      }
    }
  }

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
        return 'El registro con correo y contraseña '
            'no está habilitado';

      default:
        return 'No se pudo crear tu cuenta. '
            'Inténtalo nuevamente.';
    }
  }

  String _mensajeErrorFirestore(String codigo) {
    switch (codigo) {
      case 'permission-denied':
        return 'No se pudo validar el registro. '
            'Comprueba que la cédula y el carnet sean '
            'correctos y no estén registrados por '
            'otra persona. Si el problema continúa, '
            'contacta al administrador.';

      case 'already-exists':
        return 'Ya existe un registro con alguno '
            'de los datos proporcionados.';

      case 'unavailable':
      case 'deadline-exceeded':
        return 'No se pudo conectar con la base de datos. '
            'Revisa tu conexión e inténtalo nuevamente.';

      case 'failed-precondition':
      case 'aborted':
        return 'No se pudo completar el registro. '
            'Inténtalo nuevamente.';

      default:
        return 'No se pudo guardar el perfil. '
            'Inténtalo nuevamente o contacta al administrador.';
    }
  }

  void _registrarErrorTecnico(Object error) {
    if (kDebugMode) {
      debugPrint('Error durante el registro: $error');
    }
  }
}

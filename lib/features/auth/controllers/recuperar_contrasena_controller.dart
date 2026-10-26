import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/core/utils/errores_auth.dart';
import 'package:saman_deportivo/services/auth_service.dart';

/// Controlador de la pantalla "Recuperar contraseña" (Provider / ChangeNotifier).
///
/// Pide a Firebase que envíe el correo con el enlace para crear una nueva
/// contraseña. Guarda si está cargando, si ya se envió y el error, si lo hay.
class RecuperarContrasenaController extends ChangeNotifier {
  /// [enviarCorreo] permite inyectar una función falsa en las pruebas.
  /// En la app normal se usa AuthService.
  RecuperarContrasenaController({
    Future<void> Function(String correo)? enviarCorreo,
  }) : _enviarCorreo = enviarCorreo ?? _enviarConAuthService;

  final Future<void> Function(String correo) _enviarCorreo;

  /// El servicio se crea dentro de la función para que las pruebas
  /// no necesiten Firebase.
  static Future<void> _enviarConAuthService(String correo) async {
    await AuthService().recuperarContrasena(correo);
  }

  bool _cargando = false;
  bool _enviado = false;
  String? _error;
  bool _desechado = false;

  /// true mientras se espera la respuesta de Firebase.
  bool get cargando => _cargando;

  /// true cuando la solicitud se procesó y se muestra la confirmación.
  bool get enviado => _enviado;

  /// Mensaje de error en español, o null si no hay error.
  String? get error => _error;

  /// Pide el envío del correo. Devuelve true si se muestra la confirmación.
  ///
  /// Seguridad: si el correo no tiene cuenta (user-not-found) también se
  /// confirma, con el mismo mensaje. Así nadie puede averiguar qué correos
  /// están registrados en la plataforma.
  Future<bool> enviar(String correo) async {
    // Evita enviar dos veces si el usuario pulsa el botón repetidamente.
    if (_cargando) {
      return false;
    }

    _cargando = true;
    _error = null;
    _enviado = false;
    _avisar();

    try {
      await _enviarCorreo(correo);
      _enviado = true;
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _enviado = true;
        return true;
      }
      _error = mensajeErrorAuth(e.code);
      return false;
    } catch (e) {
      _error = mensajeDeError(e);
      return false;
    } finally {
      _cargando = false;
      _avisar();
    }
  }

  /// Quita el mensaje de error (cuando el usuario vuelve a escribir).
  void limpiarError() {
    if (_error != null) {
      _error = null;
      _avisar();
    }
  }

  /// Vuelve al formulario (botón "Usar otro correo").
  void reiniciar() {
    _enviado = false;
    _error = null;
    _avisar();
  }

  void _avisar() {
    if (!_desechado) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}

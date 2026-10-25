import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/core/utils/errores_auth.dart';
import 'package:saman_deportivo/services/auth_service.dart';

/// Controlador de la pantalla de inicio de sesión (Provider / ChangeNotifier).
///
/// Guarda el estado de la pantalla (cargando, error, contraseña oculta) y
/// llama al servicio. NO navega: cuando el inicio de sesión funciona, el
/// SesionController detecta la sesión y el AuthGate muestra la pantalla de
/// inicio que corresponde al rol.
class LoginController extends ChangeNotifier {
  /// [iniciarSesion] permite inyectar una función falsa en las pruebas.
  /// En la app normal se usa AuthService.
  LoginController({
    Future<void> Function(String correo, String contrasena)? iniciarSesion,
  }) : _iniciarSesion = iniciarSesion ?? _iniciarConAuthService;

  final Future<void> Function(String correo, String contrasena) _iniciarSesion;

  /// Se crea el servicio dentro de la función (y no al construir el
  /// controller) para que las pruebas no necesiten Firebase.
  static Future<void> _iniciarConAuthService(
    String correo,
    String contrasena,
  ) async {
    await AuthService().iniciarSesion(correo: correo, contrasena: contrasena);
  }

  bool _cargando = false;
  bool _contrasenaOculta = true;
  String? _error;
  bool _desechado = false;

  // ---------- Lo que lee la pantalla ----------

  /// true mientras se espera la respuesta de Firebase.
  bool get cargando => _cargando;

  /// true si la contraseña se muestra con puntos.
  bool get contrasenaOculta => _contrasenaOculta;

  /// Mensaje de error en español, o null si no hay error.
  String? get error => _error;

  // ---------- Acciones ----------

  /// Intenta iniciar sesión. Devuelve true si funcionó, false si falló
  /// (en ese caso el mensaje queda en [error]).
  Future<bool> iniciarSesion(String correo, String contrasena) async {
    // Evita enviar dos veces si el usuario pulsa el botón repetidamente.
    if (_cargando) {
      return false;
    }

    _cargando = true;
    _error = null;
    _avisar();

    try {
      await _iniciarSesion(correo, contrasena);
      return true;
    } catch (e) {
      _error = mensajeDeError(e);
      return false;
    } finally {
      _cargando = false;
      _avisar();
    }
  }

  /// Muestra u oculta la contraseña (el ojito del campo).
  void alternarContrasena() {
    _contrasenaOculta = !_contrasenaOculta;
    _avisar();
  }

  /// Quita el mensaje de error (por ejemplo, cuando el usuario vuelve a escribir).
  void limpiarError() {
    if (_error != null) {
      _error = null;
      _avisar();
    }
  }

  // ---------- Interno ----------

  /// Cuando el inicio de sesión funciona, el AuthGate reemplaza la pantalla
  /// y el controller se destruye ANTES de que termine este método. Si
  /// avisáramos después de destruirlo, Flutter lanzaría un error.
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

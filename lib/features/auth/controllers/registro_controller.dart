
import 'package:flutter/foundation.dart';

class RegistroController extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  bool _registroExitoso = false;

  // Estados que puede consultar la pantalla.
  bool get cargando => _cargando;
  String? get error => _error;
  bool get registroExitoso => _registroExitoso;

  // Validar los datos antes de registrar.
  String? validarDatos({
    required String nombre,
    required String cedula,
    required String carnet,
    required String correo,
    required String contrasena,
  }) {
    final palabras = nombre.trim().split(RegExp(r'\s+'));

    if (palabras.length < 2 ||
        palabras.any((palabra) => palabra.length < 2)) {
      return 'Debes ingresar nombre y apellido válidos';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(cedula.trim())) {
      return 'La cédula debe contener solo números';
    }

    if (carnet.trim().isEmpty) {
      return 'Debes ingresar tu número de carnet';
    }

    final correoValido = RegExp(
      r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
      caseSensitive: false,
    );

    if (!correoValido.hasMatch(correo.trim())) {
      return 'Debes utilizar un correo institucional UNIMET';
    }

    if (contrasena.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

  // Cambiar el estado de carga.
  void cambiarCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  // Mostrar un error durante el registro.
  void mostrarError(String mensaje) {
    _error = mensaje;
    _registroExitoso = false;
    notifyListeners();
  }

  // Limpiar los mensajes anteriores.
  void limpiarEstado() {
    _error = null;
    _registroExitoso = false;
    notifyListeners();
  }

  // Marcar el registro como exitoso.
  // Solo debe llamarse tras guardar la cuenta y el perfil.
  void confirmarRegistro() {
    _error = null;
    _registroExitoso = true;
    _cargando = false;
    notifyListeners();
  }
}

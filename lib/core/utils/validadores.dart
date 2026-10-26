/// Validaciones reutilizables para los campos de los formularios.
/// Cada método recibe lo que escribió el usuario y devuelve:
///  - null  → el valor es válido
///  - un texto → el mensaje de error que se muestra bajo el campo
/// Es justo el formato que espera el parámetro `validator` de TextFormField.
abstract final class Validadores {
  /// Forma básica de un correo: algo@dominio.ext, sin espacios.
  static final RegExp _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Correo para INICIAR SESIÓN.
  ///
  /// Solo revisa que no esté vacío y que tenga forma de correo. No exige el
  /// dominio de la UNIMET porque las cuentas de entrenadores y del
  /// administrador las crea la coordinación y pueden tener otro dominio.
  /// Quien decide si la cuenta existe es Firebase, no la pantalla.
  static String? correo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) {
      return 'Ingresa tu correo';
    }
    if (!_formatoCorreo.hasMatch(texto)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Contraseña para INICIAR SESIÓN: solo que no esté vacía.
  ///
  /// Aquí no se exige un largo mínimo: la regla de las 6 letras se aplica al
  /// crear la contraseña (registro). Al entrar, si la contraseña está mal,
  /// Firebase lo avisa.
  static String? contrasenaLogin(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    return null;
  }
}

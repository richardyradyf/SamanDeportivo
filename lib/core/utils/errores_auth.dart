import 'package:firebase_auth/firebase_auth.dart';

/// Traduce un código de error de Firebase Auth a un mensaje en español.
///
/// Se recibe el código como texto (en vez de la excepción completa) para
/// poder probar esta función sin necesidad de Firebase.
///
/// Seguridad: "correo inexistente" y "contraseña incorrecta" muestran el
/// MISMO mensaje. Si fueran distintos, cualquiera podría descubrir qué
/// correos tienen cuenta en la plataforma.
String mensajeErrorAuth(String codigo) {
  return switch (codigo) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' =>
      'Correo o contraseña incorrectos.',
    'invalid-email' => 'El correo no tiene un formato válido.',
    'user-disabled' =>
      'Esta cuenta está deshabilitada. Contacta a la coordinación de deportes.',
    'too-many-requests' =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
    'network-request-failed' =>
      'No hay conexión. Revisa tu internet e inténtalo de nuevo.',
    'operation-not-allowed' =>
      'El inicio de sesión con correo no está habilitado.',
    // Estos dos los usará el registro (Mariana).
    'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
    'weak-password' =>
      'La contraseña es muy débil. Usa al menos 6 caracteres.',
    _ => 'Ocurrió un error inesperado. Inténtalo de nuevo.',
  };
}

/// Atajo para usar dentro de un `catch`: recibe cualquier error y devuelve
/// el mensaje listo para mostrar al usuario.
String mensajeDeError(Object error) {
  if (error is FirebaseAuthException) {
    return mensajeErrorAuth(error.code);
  }
  return mensajeErrorAuth('desconocido');
}

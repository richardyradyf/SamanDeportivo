import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/utils/errores_auth.dart';

void main() {
  group('mensajeErrorAuth', () {
    test('correo inexistente y contraseña incorrecta dan el mismo mensaje', () {
      const esperado = 'Correo o contraseña incorrectos.';
      expect(mensajeErrorAuth('invalid-credential'), esperado);
      expect(mensajeErrorAuth('wrong-password'), esperado);
      expect(mensajeErrorAuth('user-not-found'), esperado);
    });

    test('traduce los errores más comunes', () {
      expect(mensajeErrorAuth('invalid-email'),
          'El correo no tiene un formato válido.');
      expect(mensajeErrorAuth('too-many-requests'),
          contains('Demasiados intentos'));
      expect(mensajeErrorAuth('network-request-failed'),
          contains('No hay conexión'));
      expect(mensajeErrorAuth('user-disabled'), contains('deshabilitada'));
    });

    test('un código desconocido da un mensaje genérico', () {
      expect(mensajeErrorAuth('codigo-raro'),
          'Ocurrió un error inesperado. Inténtalo de nuevo.');
    });
  });

  group('mensajeDeError', () {
    test('traduce una FirebaseAuthException', () {
      final error = FirebaseAuthException(code: 'wrong-password');
      expect(mensajeDeError(error), 'Correo o contraseña incorrectos.');
    });

    test('cualquier otro error da el mensaje genérico', () {
      expect(mensajeDeError(Exception('falló algo')),
          'Ocurrió un error inesperado. Inténtalo de nuevo.');
    });
  });
}

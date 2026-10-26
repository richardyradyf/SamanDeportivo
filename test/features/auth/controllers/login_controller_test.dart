import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/controllers/login_controller.dart';

void main() {
  test('estado inicial: sin carga, sin error y contraseña oculta', () {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {},
    );

    expect(controller.cargando, isFalse);
    expect(controller.error, isNull);
    expect(controller.contrasenaOculta, isTrue);
  });

  test('inicio de sesión exitoso: devuelve true y no deja error', () async {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {},
    );

    final resultado = await controller.iniciarSesion('ana@correo.com', 'clave');

    expect(resultado, isTrue);
    expect(controller.error, isNull);
    expect(controller.cargando, isFalse);
  });

  test('envía al servicio el correo y la contraseña recibidos', () async {
    String? correoRecibido;
    String? contrasenaRecibida;
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {
        correoRecibido = correo;
        contrasenaRecibida = contrasena;
      },
    );

    await controller.iniciarSesion('ana@correo.com', 'clave123');

    expect(correoRecibido, 'ana@correo.com');
    expect(contrasenaRecibida, 'clave123');
  });

  test('credenciales incorrectas: devuelve false y traduce el error', () async {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {
        throw FirebaseAuthException(code: 'wrong-password');
      },
    );

    final resultado = await controller.iniciarSesion('ana@correo.com', 'mala');

    expect(resultado, isFalse);
    expect(controller.error, 'Correo o contraseña incorrectos.');
    expect(controller.cargando, isFalse);
  });

  test('un error desconocido da el mensaje genérico', () async {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {
        throw Exception('falló algo');
      },
    );

    await controller.iniciarSesion('ana@correo.com', 'clave');

    expect(controller.error,
        'Ocurrió un error inesperado. Inténtalo de nuevo.');
  });

  test('un intento nuevo borra el error del intento anterior', () async {
    var fallar = true;
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {
        if (fallar) {
          throw FirebaseAuthException(code: 'wrong-password');
        }
      },
    );

    await controller.iniciarSesion('ana@correo.com', 'mala');
    expect(controller.error, isNotNull);

    fallar = false;
    await controller.iniciarSesion('ana@correo.com', 'buena');
    expect(controller.error, isNull);
  });

  test('ignora un segundo intento mientras ya está cargando', () async {
    final espera = Completer<void>();
    var llamadas = 0;
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) {
        llamadas++;
        return espera.future;
      },
    );

    final primero = controller.iniciarSesion('ana@correo.com', 'clave');
    expect(controller.cargando, isTrue);

    final segundo = await controller.iniciarSesion('ana@correo.com', 'clave');
    expect(segundo, isFalse);
    expect(llamadas, 1);

    espera.complete();
    expect(await primero, isTrue);
    expect(controller.cargando, isFalse);
  });

  test('avisa a la pantalla al empezar y al terminar la carga', () async {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {},
    );
    var avisos = 0;
    controller.addListener(() => avisos++);

    await controller.iniciarSesion('ana@correo.com', 'clave');

    expect(avisos, 2);
  });

  test('alternarContrasena cambia entre oculta y visible', () {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {},
    );

    controller.alternarContrasena();
    expect(controller.contrasenaOculta, isFalse);

    controller.alternarContrasena();
    expect(controller.contrasenaOculta, isTrue);
  });

  test('limpiarError quita el mensaje de error', () async {
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) async {
        throw FirebaseAuthException(code: 'wrong-password');
      },
    );

    await controller.iniciarSesion('ana@correo.com', 'mala');
    expect(controller.error, isNotNull);

    controller.limpiarError();
    expect(controller.error, isNull);
  });

  test('si se destruye durante la carga, no lanza errores al terminar',
      () async {
    final espera = Completer<void>();
    final controller = LoginController(
      iniciarSesion: (correo, contrasena) => espera.future,
    );

    final intento = controller.iniciarSesion('ana@correo.com', 'clave');
    controller.dispose(); // El AuthGate reemplazó la pantalla.
    espera.complete();

    expect(await intento, isTrue); // Termina sin excepción.
  });
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/controllers/recuperar_contrasena_controller.dart';

void main() {
  test('estado inicial: sin carga, sin envío y sin error', () {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {},
    );

    expect(controller.cargando, isFalse);
    expect(controller.enviado, isFalse);
    expect(controller.error, isNull);
  });

  test('envío exitoso: devuelve true y envía el correo recibido', () async {
    String? correoRecibido;
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async => correoRecibido = correo,
    );

    final resultado = await controller.enviar('ana@correo.unimet.edu.ve');

    expect(resultado, isTrue);
    expect(controller.enviado, isTrue);
    expect(controller.error, isNull);
    expect(controller.cargando, isFalse);
    expect(correoRecibido, 'ana@correo.unimet.edu.ve');
  });

  test('correo sin cuenta: también confirma, para no revelar quién existe',
      () async {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {
        throw FirebaseAuthException(code: 'user-not-found');
      },
    );

    final resultado = await controller.enviar('nadie@correo.com');

    expect(resultado, isTrue);
    expect(controller.enviado, isTrue);
    expect(controller.error, isNull);
  });

  test('sin conexión: devuelve false y muestra el error en español', () async {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {
        throw FirebaseAuthException(code: 'network-request-failed');
      },
    );

    final resultado = await controller.enviar('ana@correo.com');

    expect(resultado, isFalse);
    expect(controller.enviado, isFalse);
    expect(controller.error, contains('No hay conexión'));
  });

  test('un error desconocido da el mensaje genérico', () async {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {
        throw Exception('falló algo');
      },
    );

    await controller.enviar('ana@correo.com');

    expect(controller.error,
        'Ocurrió un error inesperado. Inténtalo de nuevo.');
  });

  test('ignora un segundo intento mientras ya está cargando', () async {
    final espera = Completer<void>();
    var llamadas = 0;
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) {
        llamadas++;
        return espera.future;
      },
    );

    final primero = controller.enviar('ana@correo.com');
    expect(controller.cargando, isTrue);

    final segundo = await controller.enviar('ana@correo.com');
    expect(segundo, isFalse);
    expect(llamadas, 1);

    espera.complete();
    expect(await primero, isTrue);
  });

  test('reiniciar vuelve al formulario', () async {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {},
    );

    await controller.enviar('ana@correo.com');
    expect(controller.enviado, isTrue);

    controller.reiniciar();
    expect(controller.enviado, isFalse);
  });

  test('limpiarError quita el mensaje de error', () async {
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) async {
        throw FirebaseAuthException(code: 'network-request-failed');
      },
    );

    await controller.enviar('ana@correo.com');
    expect(controller.error, isNotNull);

    controller.limpiarError();
    expect(controller.error, isNull);
  });

  test('si se destruye durante la carga, no lanza errores al terminar',
      () async {
    final espera = Completer<void>();
    final controller = RecuperarContrasenaController(
      enviarCorreo: (correo) => espera.future,
    );

    final intento = controller.enviar('ana@correo.com');
    controller.dispose();
    espera.complete();

    expect(await intento, isTrue);
  });
}

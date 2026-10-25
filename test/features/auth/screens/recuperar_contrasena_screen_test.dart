import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/auth/controllers/login_controller.dart';
import 'package:saman_deportivo/features/auth/controllers/recuperar_contrasena_controller.dart';
import 'package:saman_deportivo/features/auth/screens/login_screen.dart';
import 'package:saman_deportivo/features/auth/screens/recuperar_contrasena_screen.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester,
    RecuperarContrasenaController controlador, {
    String correoInicial = '',
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: RecuperarContrasenaScreen(
          controlador: controlador,
          correoInicial: correoInicial,
        ),
      ),
    );
  }

  testWidgets('muestra el título, el campo y el botón', (tester) async {
    await abrir(
      tester,
      RecuperarContrasenaController(enviarCorreo: (correo) async {}),
    );
    expect(find.text('Recupera tu contraseña'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);
  });

  testWidgets('con el campo vacío muestra error y no llama al servicio',
      (tester) async {
    var llamadas = 0;
    await abrir(
      tester,
      RecuperarContrasenaController(enviarCorreo: (correo) async => llamadas++),
    );
    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('un correo sin formato válido muestra su error', (tester) async {
    await abrir(
      tester,
      RecuperarContrasenaController(enviarCorreo: (correo) async {}),
    );
    await tester.enterText(find.byType(TextFormField), 'ana');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('el campo llega con el correo que se escribió en el login',
      (tester) async {
    await abrir(
      tester,
      RecuperarContrasenaController(enviarCorreo: (correo) async {}),
      correoInicial: 'ana@correo.unimet.edu.ve',
    );
    final campo = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(campo.controller?.text, 'ana@correo.unimet.edu.ve');
  });

  testWidgets('datos válidos: envía el correo normalizado y muestra la '
      'confirmación', (tester) async {
    String? correoRecibido;
    await abrir(
      tester,
      RecuperarContrasenaController(
        enviarCorreo: (correo) async => correoRecibido = correo,
      ),
    );
    await tester.enterText(
        find.byType(TextFormField), '  Ana@Correo.Unimet.edu.ve ');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(correoRecibido, 'ana@correo.unimet.edu.ve');
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('"Usar otro correo" vuelve al formulario', (tester) async {
    await abrir(
      tester,
      RecuperarContrasenaController(enviarCorreo: (correo) async {}),
    );
    await tester.enterText(
        find.byType(TextFormField), 'ana@correo.unimet.edu.ve');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar otro correo'));
    await tester.pump();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('un error de red se muestra en español', (tester) async {
    await abrir(
      tester,
      RecuperarContrasenaController(
        enviarCorreo: (correo) async {
          throw FirebaseAuthException(code: 'network-request-failed');
        },
      ),
    );
    await tester.enterText(
        find.byType(TextFormField), 'ana@correo.unimet.edu.ve');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay conexión'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('desde el login, "¿Olvidaste tu contraseña?" abre esta pantalla',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: LoginScreen(
          controlador: LoginController(iniciarSesion: (correo, clave) async {}),
        ),
      ),
    );
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/auth/controllers/login_controller.dart';
import 'package:saman_deportivo/features/auth/screens/login_screen.dart';

void main() {
  /// Abre la pantalla con un controller de prueba y un tamaño de ventana.
  Future<void> abrir(
    WidgetTester tester,
    LoginController controlador, {
    Size tamano = const Size(800, 1400),
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: LoginScreen(controlador: controlador),
      ),
    );
  }

  Future<void> llenar(WidgetTester tester, String correo, String clave) async {
    await tester.enterText(find.byType(TextFormField).at(0), correo);
    await tester.enterText(find.byType(TextFormField).at(1), clave);
  }

  testWidgets('muestra el título, los campos y los botones', (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
    );
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('con los campos vacíos muestra errores y no llama al servicio',
      (tester) async {
    var llamadas = 0;
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async => llamadas++),
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('un correo sin formato válido muestra su error', (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
    );
    await llenar(tester, 'ana', 'clave123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('datos válidos: envía el correo sin espacios y en minúsculas',
      (tester) async {
    String? correoRecibido;
    String? claveRecibida;
    await abrir(
      tester,
      LoginController(
        iniciarSesion: (correo, clave) async {
          correoRecibido = correo;
          claveRecibida = clave;
        },
      ),
    );
    await llenar(tester, '  Ana@Correo.Unimet.edu.ve ', 'clave123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(correoRecibido, 'ana@correo.unimet.edu.ve');
    expect(claveRecibida, 'clave123');
  });

  testWidgets('credenciales incorrectas: muestra el error en español',
      (tester) async {
    await abrir(
      tester,
      LoginController(
        iniciarSesion: (correo, clave) async {
          throw FirebaseAuthException(code: 'wrong-password');
        },
      ),
    );
    await llenar(tester, 'ana@correo.unimet.edu.ve', 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('el ojito muestra y oculta la contraseña', (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
    );
    bool oculta() => tester
        .widget<TextField>(
          find.descendant(
            of: find.byType(TextFormField).at(1),
            matching: find.byType(TextField),
          ),
        )
        .obscureText;
    expect(oculta(), isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(oculta(), isFalse);
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(oculta(), isTrue);
  });

  testWidgets('"Crear cuenta" abre el registro', (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
    );
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Registro de estudiante'), findsOneWidget);
  });

  testWidgets('en pantalla ancha se ve el panel de marca', (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
      tamano: const Size(1200, 800),
    );
    expect(
      find.text('Gestiona tus actividades deportivas en la UNIMET'),
      findsOneWidget,
    );
  });

  testWidgets('en pantalla angosta no se ve el panel de marca',
      (tester) async {
    await abrir(
      tester,
      LoginController(iniciarSesion: (correo, clave) async {}),
    );
    expect(
      find.text('Gestiona tus actividades deportivas en la UNIMET'),
      findsNothing,
    );
  });
}

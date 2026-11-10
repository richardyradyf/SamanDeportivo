import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/core/router/auth_gate.dart';
import 'package:saman_deportivo/features/admin/screens/inicio_admin_screen.dart';
import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';
import 'package:saman_deportivo/features/entrenador/screens/inicio_entrenador_screen.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';

/// Sesión simulada para probar AuthGate sin Firebase.
class SesionFalsa extends ChangeNotifier implements SesionController {
  SesionFalsa(this.estadoActual, {this.personaActual, this.errorActual});

  EstadoSesion estadoActual;
  Persona? personaActual;
  String? errorActual;
  int cierresDeSesion = 0;

  @override
  EstadoSesion get estado => estadoActual;

  @override
  Persona? get persona => personaActual;

  @override
  Rol? get rol => personaActual?.rol;

  @override
  String? get error => errorActual;

  @override
  bool get estaAutenticado => estadoActual == EstadoSesion.autenticado;

  @override
  Future<void> cerrarSesion() async {
    cierresDeSesion++;
  }

  void cambiar(EstadoSesion estado, {Persona? persona, String? error}) {
    estadoActual = estado;
    personaActual = persona;
    errorActual = error;
    notifyListeners();
  }
}

Persona _persona(Rol rol, {String uid = 'u1', String nombre = 'Ana Ruiz'}) {
  return Persona.fromMap(uid, {
    'rol': rol.name,
    'cedula': '12345678',
    'nombre': nombre,
    'correo': 'ana@correo.unimet.edu.ve',
  });
}

Future<void> _mostrar(
  WidgetTester tester,
  SesionFalsa sesion, {
  ObtenerInscripciones? obtenerInscripciones,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SesionController>.value(
      value: sesion,
      child: MaterialApp(
        home: AuthGate(
          sinSesion: const Text('Bienvenida'),
          construirPerfil: (persona, _) => Text('Perfil de ${persona.nombre}'),
          obtenerInscripciones: obtenerInscripciones,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mientras carga muestra un indicador', (tester) async {
    await _mostrar(tester, SesionFalsa(EstadoSesion.cargando));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sin sesión muestra la pantalla recibida', (tester) async {
    await _mostrar(tester, SesionFalsa(EstadoSesion.sinSesion));

    expect(find.text('Bienvenida'), findsOneWidget);
  });

  testWidgets('sin perfil muestra el error y permite cerrar sesión', (
    tester,
  ) async {
    final sesion = SesionFalsa(
      EstadoSesion.sinPerfil,
      errorActual: 'El perfil tiene datos inválidos',
    );

    await _mostrar(tester, sesion);

    expect(find.text('No pudimos cargar tu perfil'), findsOneWidget);
    expect(find.text('El perfil tiene datos inválidos'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));

    expect(sesion.cierresDeSesion, 1);
  });

  testWidgets('el estudiante entra a su inicio con su nombre', (tester) async {
    await _mostrar(
      tester,
      SesionFalsa(
        EstadoSesion.autenticado,
        personaActual: _persona(Rol.estudiante),
      ),
    );

    final inicio = tester.widget<InicioEstudianteScreen>(
      find.byType(InicioEstudianteScreen),
    );

    expect(inicio.nombre, 'Ana Ruiz');
    expect(inicio.perfil, isNotNull);
  });

  testWidgets('el entrenador entra a su inicio', (tester) async {
    await _mostrar(
      tester,
      SesionFalsa(
        EstadoSesion.autenticado,
        personaActual: _persona(Rol.entrenador),
      ),
    );

    expect(find.byType(InicioEntrenadorScreen), findsOneWidget);
    expect(find.byType(InicioEstudianteScreen), findsNothing);
  });

  testWidgets('el administrador entra a su inicio', (tester) async {
    await _mostrar(
      tester,
      SesionFalsa(
        EstadoSesion.autenticado,
        personaActual: _persona(Rol.administrador),
      ),
    );

    expect(find.byType(InicioAdminScreen), findsOneWidget);
  });

  testWidgets('AuthGate inyecta perfil en administrador', (tester) async {
    await _mostrar(
      tester,
      SesionFalsa(
        EstadoSesion.autenticado,
        personaActual: _persona(Rol.administrador),
      ),
    );

    final pantalla = tester.widget<InicioAdminScreen>(
      find.byType(InicioAdminScreen),
    );

    expect(pantalla.perfil, isA<Text>());
    expect((pantalla.perfil! as Text).data, 'Perfil de Ana Ruiz');
  });

  testWidgets('autenticado sin persona sigue cargando', (tester) async {
    await _mostrar(tester, SesionFalsa(EstadoSesion.autenticado));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('cambia de pantalla cuando cambia la sesión', (tester) async {
    final sesion = SesionFalsa(EstadoSesion.cargando);

    await _mostrar(tester, sesion);

    sesion.cambiar(
      EstadoSesion.autenticado,
      persona: _persona(Rol.administrador),
    );

    await tester.pump();

    expect(find.byType(InicioAdminScreen), findsOneWidget);

    sesion.cambiar(EstadoSesion.sinSesion);

    await tester.pump();

    expect(find.byType(InicioAdminScreen), findsNothing);
    expect(find.text('Bienvenida'), findsOneWidget);
  });

  // -------------------------------------------------------
  // Pruebas nuevas del módulo de inscripciones
  // -------------------------------------------------------

  testWidgets('AuthGate solicita inscripciones con el UID del estudiante', (
    tester,
  ) async {
    String? uidConsultado;

    Stream<List<Inscripcion>> obtenerInscripciones(String uid) {
      uidConsultado = uid;
      return Stream.value(<Inscripcion>[]);
    }

    await _mostrar(
      tester,
      SesionFalsa(
        EstadoSesion.autenticado,
        personaActual: _persona(Rol.estudiante, uid: 'EST001'),
      ),
      obtenerInscripciones: obtenerInscripciones,
    );

    expect(uidConsultado, 'EST001');

    final inicio = tester.widget<InicioEstudianteScreen>(
      find.byType(InicioEstudianteScreen),
    );

    expect(inicio.inscripcionesStream, isNotNull);
  });

  testWidgets('AuthGate no solicita inscripciones para otros roles', (
    tester,
  ) async {
    var cantidadConsultas = 0;

    Stream<List<Inscripcion>> obtenerInscripciones(String uid) {
      cantidadConsultas++;
      return Stream.value(<Inscripcion>[]);
    }

    final sesion = SesionFalsa(
      EstadoSesion.autenticado,
      personaActual: _persona(Rol.entrenador),
    );

    await _mostrar(tester, sesion, obtenerInscripciones: obtenerInscripciones);

    expect(cantidadConsultas, 0);

    sesion.cambiar(
      EstadoSesion.autenticado,
      persona: _persona(Rol.administrador),
    );

    await tester.pump();

    expect(cantidadConsultas, 0);
  });
}

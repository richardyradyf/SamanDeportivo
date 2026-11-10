import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/core/router/auth_gate.dart';
import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

class SesionPrueba extends ChangeNotifier implements SesionController {
  @override
  EstadoSesion get estado => EstadoSesion.autenticado;

  @override
  Persona? get persona => Persona.fromMap('EST001', {
    'rol': 'estudiante',
    'cedula': '12345678',
    'nombre': 'Estudiante Prueba',
    'correo': 'prueba@unimet.edu.ve',
  });

  @override
  Rol? get rol => Rol.estudiante;

  @override
  String? get error => null;

  @override
  bool get estaAutenticado => true;

  @override
  Future<void> cerrarSesion() async {}
}

Inscripcion crearInscripcion() {
  return Inscripcion(
    id: 'EST001_TEN-01',
    estudianteUid: 'EST001',
    estudianteCedula: '12345678',
    estudianteNombre: 'Estudiante Prueba',
    estudianteCarnet: '20260001',
    estudianteCorreo: 'prueba@unimet.edu.ve',
    deporteId: 'TEN-01',
    deporteNombre: 'Tenis',
    estado: EstadoInscripcion.pendiente,
    fechaInscripcion: DateTime(2026, 11, 6),
    fechaLimitePago: DateTime(2026, 11, 7),
  );
}

Future<void> prepararPantalla(
  WidgetTester tester, {
  required CancelarInscripcion cancelar,
}) async {
  final inscripcion = crearInscripcion();

  await tester.pumpWidget(
    ChangeNotifierProvider<SesionController>(
      create: (_) => SesionPrueba(),
      child: MaterialApp(
        home: AuthGate(
          sinSesion: const Text('Login'),
          construirPerfil: (persona, sesion) => const Text('Perfil de prueba'),
          obtenerInscripciones: (uid) => Stream.value([inscripcion]),
          cancelarInscripcion: cancelar,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> abrirInscripciones(WidgetTester tester) async {
  // LayoutResponsivo utiliza NavigationRail en tablet
  // y NavigationBar en dispositivos móviles.
  final navegacionLateral = find.byType(NavigationRail);

  if (navegacionLateral.evaluate().isNotEmpty) {
    final rail = tester.widget<NavigationRail>(navegacionLateral);

    rail.onDestinationSelected!(3);
  } else {
    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));

    barra.onDestinationSelected!(3);
  }

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AuthGate conecta la accion de cancelar', (tester) async {
    var cancelaciones = 0;

    await prepararPantalla(
      tester,
      cancelar: (String inscripcionId, {required String responsableUid}) async {
        cancelaciones++;
      },
    );

    final inicio = tester.widget<InicioEstudianteScreen>(
      find.byType(InicioEstudianteScreen),
    );

    expect(inicio.onCancelarInscripcion, isNotNull);
    expect(cancelaciones, 0);
  });

  testWidgets('Volver no ejecuta la cancelacion', (tester) async {
    var cancelaciones = 0;

    await prepararPantalla(
      tester,
      cancelar: (String inscripcionId, {required String responsableUid}) async {
        cancelaciones++;
      },
    );

    await abrirInscripciones(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cancelar inscripción'),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        '¿Deseas cancelar tu inscripción en Tenis?\n\n'
        'Esta acción liberará tu cupo.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(cancelaciones, 0);
    expect(find.text('Confirmar cancelación'), findsNothing);
  });

  testWidgets('Confirmar ejecuta la cancelacion y muestra exito', (
    tester,
  ) async {
    var cancelaciones = 0;
    String? idRecibido;
    String? uidRecibido;

    await prepararPantalla(
      tester,
      cancelar: (String inscripcionId, {required String responsableUid}) async {
        cancelaciones++;
        idRecibido = inscripcionId;
        uidRecibido = responsableUid;
      },
    );

    await abrirInscripciones(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cancelar inscripción'),
    );

    await tester.pumpAndSettle();

    expect(cancelaciones, 0);

    await tester.tap(find.text('Confirmar cancelación'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(cancelaciones, 1);
    expect(idRecibido, 'EST001_TEN-01');
    expect(uidRecibido, 'EST001');

    expect(
      find.text('Tu inscripción fue cancelada correctamente.'),
      findsOneWidget,
    );
  });

  testWidgets('Si falla la cancelacion muestra el error', (tester) async {
    await prepararPantalla(
      tester,
      cancelar: (String inscripcionId, {required String responsableUid}) async {
        throw const InscripcionException(
          'No tienes permiso para cancelar esta inscripción.',
        );
      },
    );

    await abrirInscripciones(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cancelar inscripción'),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar cancelación'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('No tienes permiso para cancelar esta inscripción.'),
      findsOneWidget,
    );

    expect(
      find.text('Tu inscripción fue cancelada correctamente.'),
      findsNothing,
    );
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/screens/mis_inscripciones_screen.dart';

void main() {
  Inscripcion crearInscripcion() {
    return Inscripcion(
      id: 'EST001_TEN-01',
      estudianteUid: 'EST001',
      estudianteCedula: '12345678',
      estudianteNombre: 'Estudiante Prueba',
      estudianteCarnet: '20260001',
      estudianteCorreo: 'prueba@correo.com',
      deporteId: 'TEN-01',
      deporteNombre: 'Tenis',
      estado: EstadoInscripcion.pendiente,
      fechaInscripcion: DateTime(2026, 11, 6),
      fechaLimitePago: DateTime(2026, 11, 7),
    );
  }

  testWidgets('Muestra mensaje cuando no hay inscripciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(),
        ),
      ),
    );

    expect(
      find.text('No tienes inscripciones registradas'),
      findsOneWidget,
    );
  });

  testWidgets('Muestra los datos de una inscripción', (
    tester,
  ) async {
    final inscripcion = crearInscripcion();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(
            inscripciones: [inscripcion],
          ),
        ),
      ),
    );

    expect(find.text('Tenis'), findsOneWidget);
    expect(find.text('Código: TEN-01'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(
      find.text('Fecha límite de pago: 07/11/2026'),
      findsOneWidget,
    );

    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(
        OutlinedButton,
        'Cancelar inscripción',
      ),
    );

    expect(boton.onPressed, isNull);
  });

  testWidgets('Permite solicitar una cancelación', (
    tester,
  ) async {
    final inscripcion = crearInscripcion();
    var cancelacionSolicitada = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(
            inscripciones: [inscripcion],
            onCancelar: (_) {
              cancelacionSolicitada = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cancelar inscripción'));

    expect(cancelacionSolicitada, true);
  });

  testWidgets('Muestra las inscripciones desde un Stream', (
    tester,
  ) async {
    final inscripcion = crearInscripcion();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(
            inscripcionesStream: Stream.value([inscripcion]),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tenis'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('No permite cancelar una inscripción cancelada', (
    tester,
  ) async {
    final inscripcion = crearInscripcion().conEstado(
      EstadoInscripcion.cancelada,
      responsableUid: 'EST001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(
            inscripciones: [inscripcion],
            onCancelar: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Cancelar inscripción'), findsNothing);
  });
}

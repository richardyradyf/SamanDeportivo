import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/estudiante/inscripciones/models/inscripcion_local.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/screens/mis_inscripciones_screen.dart';

void main() {
  testWidgets('Muestra un mensaje cuando no hay inscripciones', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MisInscripcionesScreen())),
    );

    expect(find.text('No tienes inscripciones registradas'), findsOneWidget);
  });

  testWidgets('Muestra una inscripción pendiente', (tester) async {
    final inscripcion = InscripcionLocal.nueva(
      id: 'INS001',
      estudianteId: 'EST001',
      deporteId: 'FUT001',
      fecha: DateTime(2026, 11, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MisInscripcionesScreen(inscripciones: [inscripcion]),
        ),
      ),
    );

    expect(find.text('Deporte: FUT001'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);

    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancelar inscripcion'),
    );

    expect(boton.onPressed, isNull);
  });

  testWidgets('Permite solicitar una cancelación', (tester) async {
    final inscripcion = InscripcionLocal.nueva(
      id: 'INS002',
      estudianteId: 'EST001',
      deporteId: 'TEN001',
      fecha: DateTime(2026, 11, 6),
    );

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

    await tester.tap(find.text('Cancelar inscripcion'));

    expect(cancelacionSolicitada, true);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/inscripciones/presentation/inscripciones_admin_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

Inscripcion _registro({
  required String id,
  required String nombre,
  required String cedula,
  required String deporte,
  required EstadoInscripcion estado,
}) {
  return Inscripcion(
    id: id,
    estudianteUid: id,
    estudianteCedula: cedula,
    estudianteNombre: nombre,
    estudianteCarnet: '20260001',
    estudianteCorreo: '$id@unimet.edu.ve',
    deporteId: deporte == 'Fútbol sala' ? 'FUT-01' : 'TEN-01',
    deporteNombre: deporte,
    estado: estado,
    fechaInscripcion: DateTime(2026, 11, 9),
    fechaLimitePago: DateTime(2026, 11, 10),
  );
}

final _registros = [
  _registro(
    id: 'est-a',
    nombre: 'María Pérez',
    cedula: '12345678',
    deporte: 'Fútbol sala',
    estado: EstadoInscripcion.confirmada,
  ),
  _registro(
    id: 'est-b',
    nombre: 'Carlos Díaz',
    cedula: '87654321',
    deporte: 'Tenis',
    estado: EstadoInscripcion.pendiente,
  ),
];

Future<void> _mostrar(
  WidgetTester tester, {
  Stream<List<Inscripcion>>? flujo,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InscripcionesAdminScreen(
          flujo: flujo ?? Stream.value(_registros),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra inscripciones reales del flujo inyectado', (
    tester,
  ) async {
    await _mostrar(tester);
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.text('Carlos Díaz'), findsOneWidget);
    expect(find.text('2 inscripciones encontradas'), findsOneWidget);
  });

  testWidgets('filtra por cédula', (tester) async {
    await _mostrar(tester);
    await tester.enterText(
      find.byKey(const Key('ins-admin-busqueda')),
      '12345678',
    );
    await tester.pumpAndSettle();
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.text('Carlos Díaz'), findsNothing);
    expect(find.text('1 inscripción encontrada'), findsOneWidget);
  });

  testWidgets('filtra por nombre de deporte', (tester) async {
    await _mostrar(tester);
    await tester.enterText(
      find.byKey(const Key('ins-admin-busqueda')),
      'tenis',
    );
    await tester.pumpAndSettle();
    expect(find.text('María Pérez'), findsNothing);
    expect(find.text('Carlos Díaz'), findsOneWidget);
  });

  testWidgets('filtra por estado confirmado', (tester) async {
    await _mostrar(tester);
    await tester.tap(find.byKey(const Key('ins-admin-estado')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmada').last);
    await tester.pumpAndSettle();
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.text('Carlos Díaz'), findsNothing);
  });

  testWidgets('distingue colección vacía', (tester) async {
    await _mostrar(tester, flujo: Stream.value(<Inscripcion>[]));
    expect(find.text('No hay inscripciones registradas.'), findsOneWidget);
  });

  testWidgets('no convierte error de permisos en cero', (tester) async {
    await _mostrar(
      tester,
      flujo: Stream<List<Inscripcion>>.error(StateError('permission-denied')),
    );
    expect(
      find.textContaining('No se pudieron consultar las inscripciones'),
      findsOneWidget,
    );
    expect(find.text('0 inscripciones encontradas'), findsNothing);
  });
}

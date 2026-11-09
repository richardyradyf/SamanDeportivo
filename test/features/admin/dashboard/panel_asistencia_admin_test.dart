import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/admin/dashboard/data/firestore_asistencia_admin_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/panel_asistencia_admin.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/enums.dart';

Asistencia registro(String uid, EstadoAsistencia estado, String deporte) {
  return Asistencia(
    id: '${deporte}_2026-11-09_$uid',
    inscripcionId: '${uid}_$deporte',
    estudianteUid: uid,
    estudianteNombre: uid,
    deporteId: deporte,
    entrenadorUid: 'ent-1',
    fecha: DateTime(2026, 11, 9),
    estado: estado,
  );
}

Future<void> mostrar(
  WidgetTester tester, {
  ConsultarAsistenciaAdmin? consultar,
}) async {
  tester.view.physicalSize = const Size(1100, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PanelAsistenciaAdmin(consultar: consultar),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin Firebase avisa que falta conexión', (tester) async {
    await mostrar(tester);
    expect(find.byKey(const Key('h3-asistencia-no-conectada')), findsOneWidget);
  });

  testWidgets('fuente válida muestra porcentaje y totales', (tester) async {
    await mostrar(
      tester,
      consultar: (_, _) => Stream.value(
        LecturaAsistenciaAdmin(
          registros: [
            registro('a', EstadoAsistencia.presente, 'FUT-01'),
            registro('b', EstadoAsistencia.presente, 'FUT-01'),
            registro('c', EstadoAsistencia.ausente, 'FUT-01'),
            registro('d', EstadoAsistencia.presente, 'BAL-01'),
          ],
        ),
      ),
    );
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Presentes: 3'), findsOneWidget);
    expect(find.text('Total de registros: 4'), findsOneWidget);

    await tester.tap(find.text('Todos los deportes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FUT-01').last);
    await tester.pumpAndSettle();
    expect(find.text('66.7%'), findsOneWidget);
  });

  testWidgets('sin datos muestra ausencia, no 0 %', (tester) async {
    await mostrar(
      tester,
      consultar: (_, _) =>
          Stream.value(const LecturaAsistenciaAdmin(registros: [])),
    );
    expect(find.byKey(const Key('h3-asistencia-sin-datos')), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
  });

  testWidgets('error de permisos no se representa como cero', (tester) async {
    await mostrar(
      tester,
      consultar: (_, _) => Stream.error(StateError('permission-denied')),
    );
    expect(find.byKey(const Key('h3-asistencia-error')), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
  });

  testWidgets('cambiar período ejecuta una consulta nueva', (tester) async {
    final rangos = <int>[];
    await mostrar(
      tester,
      consultar: (desde, hasta) {
        rangos.add(hasta.difference(desde).inDays);
        return Stream.value(const LecturaAsistenciaAdmin(registros: []));
      },
    );
    expect(rangos, [30]);
    await tester.tap(find.text('Últimos 30 días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 7 días').last);
    await tester.pumpAndSettle();
    expect(rangos, [30, 7]);
  });

  testWidgets('muestra registros omitidos sin atribuir ausencias', (
    tester,
  ) async {
    await mostrar(
      tester,
      consultar: (_, _) => Stream.value(
        const LecturaAsistenciaAdmin(registros: [], omitidos: 2),
      ),
    );
    expect(find.byKey(const Key('h3-asistencia-omitidos')), findsOneWidget);
    expect(find.byKey(const Key('h3-asistencia-sin-datos')), findsOneWidget);
  });
}

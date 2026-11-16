import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/admin/dashboard/data/firestore_asistencia_admin_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/panel_asistencia_admin.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

Asistencia registro(
  String uid,
  EstadoAsistencia estado,
  String deporte, {
  DateTime? fecha,
}) {
  return Asistencia(
    id: '${deporte}_2026-11-09_$uid',
    inscripcionId: '${uid}_$deporte',
    estudianteUid: uid,
    estudianteNombre: uid,
    deporteId: deporte,
    entrenadorUid: 'ent-1',
    fecha: fecha ?? DateTime(2026, 11, 9),
    estado: estado,
  );
}

Deporte deporte(String codigo, String nombre, DateTime creadoEn) => Deporte(
  codigo: codigo,
  nombre: nombre,
  descripcion: 'Disciplina deportiva',
  disciplina: Disciplina.colectivo,
  costo: 0,
  cupoMaximo: 20,
  creadoEn: creadoEn,
);

Future<void> mostrar(
  WidgetTester tester, {
  ConsultarAsistenciaAdmin? consultar,
  Stream<List<Deporte>>? deportes,
}) async {
  tester.view.physicalSize = const Size(1100, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PanelAsistenciaAdmin(
            consultar: consultar,
            deportes: deportes,
            ahora: () => DateTime(2026, 11, 15),
          ),
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

  testWidgets('sin datos muestra 0 % e indica que no hay registros', (tester) async {
    await mostrar(
      tester,
      consultar: (_, _) =>
          Stream.value(const LecturaAsistenciaAdmin(registros: [])),
    );
    expect(find.byKey(const Key('h3-asistencia-sin-datos')), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
  });

  testWidgets('error de permisos no se representa como cero', (tester) async {
    await mostrar(
      tester,
      consultar: (_, _) => Stream.error(StateError('permission-denied')),
    );
    expect(find.byKey(const Key('h3-asistencia-error')), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
  });

  testWidgets('usa tres meses calendario y permite cambiar el período', (
    tester,
  ) async {
    final rangos = <(DateTime, DateTime)>[];
    await mostrar(
      tester,
      consultar: (desde, hasta) {
        rangos.add((desde, hasta));
        return Stream.value(const LecturaAsistenciaAdmin(registros: []));
      },
    );
    expect(rangos, [(DateTime(2026, 8, 15), DateTime(2026, 11, 16))]);
    await tester.tap(find.text('Últimos 3 meses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 7 días').last);
    await tester.pumpAndSettle();
    expect(rangos, [
      (DateTime(2026, 8, 15), DateTime(2026, 11, 16)),
      (DateTime(2026, 11, 9), DateTime(2026, 11, 16)),
    ]);
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

  testWidgets('desglosa todos los deportes, incluso los que no tienen registros', (
    tester,
  ) async {
    await mostrar(
      tester,
      deportes: Stream.value([
        deporte('FUT-01', 'Fútbol', DateTime(2026, 11, 1)),
        deporte('BAL-01', 'Baloncesto', DateTime(2026, 10, 1)),
        deporte('TEN-01', 'Tenis', DateTime(2026, 11, 14)),
      ]),
      consultar: (_, _) => Stream.value(
        LecturaAsistenciaAdmin(
          registros: [
            registro('a', EstadoAsistencia.presente, 'FUT-01'),
            registro('b', EstadoAsistencia.ausente, 'FUT-01'),
            registro('c', EstadoAsistencia.presente, 'BAL-01'),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('h4-asistencia-deporte-FUT-01')), findsOneWidget);
    expect(find.byKey(const Key('h4-asistencia-deporte-BAL-01')), findsOneWidget);
    expect(find.byKey(const Key('h4-asistencia-deporte-TEN-01')), findsOneWidget);
    expect(find.text('0.0% (0 registros)'), findsOneWidget);
    expect(find.text('66.7%'), findsOneWidget);
  });

  testWidgets('ignora registros anteriores a la fecha de creación', (
    tester,
  ) async {
    await mostrar(
      tester,
      deportes: Stream.value([
        deporte('FUT-01', 'Fútbol', DateTime(2026, 11, 5, 12)),
      ]),
      consultar: (_, _) => Stream.value(
        LecturaAsistenciaAdmin(
          registros: [
            registro(
              'antes',
              EstadoAsistencia.ausente,
              'FUT-01',
              fecha: DateTime(2026, 10, 10),
            ),
            registro('despues', EstadoAsistencia.presente, 'FUT-01'),
          ],
        ),
      ),
    );
    expect(find.text('100.0%'), findsOneWidget);
    expect(find.text('Total de registros: 1'), findsOneWidget);
  });

  testWidgets('error del catálogo no se informa como 0 %', (tester) async {
    await mostrar(
      tester,
      deportes: Stream.error(StateError('permission-denied')),
      consultar: (_, _) => Stream.value(
        const LecturaAsistenciaAdmin(registros: []),
      ),
    );
    expect(find.byKey(const Key('h4-asistencia-error-deportes')), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
  });
}

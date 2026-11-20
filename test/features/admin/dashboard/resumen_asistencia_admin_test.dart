import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/enums.dart';

Asistencia asistencia(
  String uid,
  EstadoAsistencia estado, {
  String deporte = 'FUT-01',
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

void main() {
  test('sin registros: 0 % con total cero y sin división inválida', () {
    final resumen = ResumenAsistenciaAdmin.calcular([]);
    expect(resumen.total, 0);
    expect(resumen.porcentaje, 0);
  });

  test('3 presentes y 1 ausente producen 75 %', () {
    final resumen = ResumenAsistenciaAdmin.calcular([
      asistencia('a', EstadoAsistencia.presente),
      asistencia('b', EstadoAsistencia.presente),
      asistencia('c', EstadoAsistencia.presente),
      asistencia('d', EstadoAsistencia.ausente),
    ]);
    expect(resumen.presentes, 3);
    expect(resumen.ausentes, 1);
    expect(resumen.total, 4);
    expect(resumen.porcentaje, 75);
  });

  test('todos ausentes producen 0 % real', () {
    final resumen = ResumenAsistenciaAdmin.calcular([
      asistencia('a', EstadoAsistencia.ausente),
    ]);
    expect(resumen.porcentaje, 0);
  });

  test('filtrar un deporte no incluye sesiones de otros', () {
    final resumen = ResumenAsistenciaAdmin.calcular([
      asistencia('a', EstadoAsistencia.presente),
      asistencia('b', EstadoAsistencia.ausente, deporte: 'BAL-01'),
    ], deporteId: 'FUT-01');
    expect(resumen.total, 1);
    expect(resumen.porcentaje, 100);
  });

  test('tres meses calendario ajustan el día 31 al fin del mes', () {
    expect(
      ResumenAsistenciaAdmin.inicioTresMeses(DateTime(2026, 5, 31)),
      DateTime(2026, 2, 28),
    );
    expect(
      ResumenAsistenciaAdmin.inicioTresMeses(DateTime(2026, 11, 15)),
      DateTime(2026, 8, 15),
    );
  });

  test('no cuenta asistencias anteriores a la creación de un deporte', () {
    final resumen = ResumenAsistenciaAdmin.calcular(
      [
        asistencia(
          'antes',
          EstadoAsistencia.ausente,
          fecha: DateTime(2026, 9, 1),
        ),
        asistencia(
          'mismo-dia',
          EstadoAsistencia.presente,
          fecha: DateTime(2026, 11, 5),
        ),
        asistencia(
          'despues',
          EstadoAsistencia.presente,
          fecha: DateTime(2026, 11, 9),
        ),
      ],
      desde: DateTime(2026, 8, 15),
      hasta: DateTime(2026, 11, 16),
      creadoEnPorDeporte: {'FUT-01': DateTime(2026, 11, 5, 17)},
    );
    expect(resumen.presentes, 2);
    expect(resumen.ausentes, 0);
    expect(resumen.porcentaje, 100);
  });

  test('total y deporte aplican la ventana inclusiva/exclusiva', () {
    final registros = [
      asistencia(
        'antes-ventana',
        EstadoAsistencia.ausente,
        fecha: DateTime(2026, 8, 14),
      ),
      asistencia(
        'dentro',
        EstadoAsistencia.presente,
        fecha: DateTime(2026, 11, 15),
      ),
      asistencia(
        'futuro',
        EstadoAsistencia.ausente,
        fecha: DateTime(2026, 11, 16),
      ),
      asistencia(
        'otro',
        EstadoAsistencia.ausente,
        deporte: 'BAL-01',
        fecha: DateTime(2026, 11, 9),
      ),
    ];
    final total = ResumenAsistenciaAdmin.calcular(
      registros,
      desde: DateTime(2026, 8, 15),
      hasta: DateTime(2026, 11, 16),
    );
    final futbol = ResumenAsistenciaAdmin.calcular(
      registros,
      desde: DateTime(2026, 8, 15),
      hasta: DateTime(2026, 11, 16),
      deporteId: 'FUT-01',
    );
    expect(total.total, 2);
    expect(total.porcentaje, 50);
    expect(futbol.total, 1);
    expect(futbol.porcentaje, 100);
  });
}

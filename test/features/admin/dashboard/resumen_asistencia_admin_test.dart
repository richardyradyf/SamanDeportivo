import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/enums.dart';

Asistencia asistencia(
  String uid,
  EstadoAsistencia estado, {
  String deporte = 'FUT-01',
}) {
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

void main() {
  test('sin registros: porcentaje desconocido, no 0 %', () {
    final resumen = ResumenAsistenciaAdmin.calcular([]);
    expect(resumen.total, 0);
    expect(resumen.porcentaje, isNull);
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
}

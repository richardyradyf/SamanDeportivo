import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/entrenador/asistencia/domain/resumen_asistencia.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/enums.dart';

Asistencia _registro(String uid, EstadoAsistencia estado) =>
    Asistencia.registrar(
      inscripcionId: '${uid}_BAL-01',
      estudianteUid: uid,
      estudianteNombre: uid,
      deporteId: 'BAL-01',
      entrenadorUid: 'ent-1',
      fecha: DateTime(2026, 11, 8),
      estado: estado,
    );

void main() {
  group('porcentajeAsistencia', () {
    test('sin registros es 0', () {
      expect(porcentajeAsistencia([]), 0);
    });

    test('cuenta solo los presentes', () {
      final registros = [
        _registro('a', EstadoAsistencia.presente),
        _registro('b', EstadoAsistencia.ausente),
        _registro('c', EstadoAsistencia.presente),
      ];
      expect(porcentajeAsistencia(registros), 67);
    });

    test('todos presentes es 100', () {
      expect(
        porcentajeAsistencia([_registro('a', EstadoAsistencia.presente)]),
        100,
      );
    });
  });

  group('PeriodoHistorial.rango', () {
    final domingo = DateTime(2026, 11, 8, 18, 30);

    test('día: desde las 00:00 hasta el día siguiente', () {
      final r = PeriodoHistorial.dia.rango(domingo);
      expect(r.desde, DateTime(2026, 11, 8));
      expect(r.hasta, DateTime(2026, 11, 9));
    });

    test('semana: empieza el lunes', () {
      final r = PeriodoHistorial.semana.rango(domingo);
      expect(r.desde, DateTime(2026, 11, 2));
      expect(r.hasta, DateTime(2026, 11, 9));
    });

    test('mes: del día 1 al primero del mes siguiente', () {
      final r = PeriodoHistorial.mes.rango(domingo);
      expect(r.desde, DateTime(2026, 11, 1));
      expect(r.hasta, DateTime(2026, 12, 1));
    });
  });
}
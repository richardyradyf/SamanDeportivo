import 'dart:math' as math;

import 'package:saman_deportivo/models/asistencia.dart';

/// Promedio de asistencia por REGISTROS de sesiones (no por estudiantes únicos).
/// Una muestra vacía informa 0 %, y `total == 0` permite distinguirla de
/// una muestra con ausencias reales. Los errores de lectura se manejan aparte.
class ResumenAsistenciaAdmin {
  const ResumenAsistenciaAdmin({
    required this.presentes,
    required this.ausentes,
  });

  final int presentes;
  final int ausentes;

  int get total => presentes + ausentes;

  double get porcentaje => total == 0 ? 0 : presentes * 100 / total;

  /// Inicio del intervalo móvil de tres meses de calendario.
  /// Si el día no existe en el mes de destino (31 de mayo -> febrero),
  /// se usa el último día de ese mes.
  static DateTime inicioTresMeses(DateTime hoy) {
    final ultimoDia = DateTime(hoy.year, hoy.month - 2, 0).day;
    return DateTime(hoy.year, hoy.month - 3, math.min(hoy.day, ultimoDia));
  }

  static ResumenAsistenciaAdmin calcular(
    Iterable<Asistencia> registros, {
    String? deporteId,
    DateTime? desde,
    DateTime? hasta,
    Map<String, DateTime> creadoEnPorDeporte = const {},
  }) {
    var presentes = 0;
    var ausentes = 0;

    for (final registro in registros) {
      if (deporteId != null && registro.deporteId != deporteId) continue;
      if (desde != null && registro.fecha.isBefore(desde)) continue;
      if (hasta != null && !registro.fecha.isBefore(hasta)) continue;

      // Las asistencias se almacenan a medianoche, mientras que creadoEn
      // puede tener hora. Se compara desde el día de creación inclusive.
      final creadoEn = creadoEnPorDeporte[registro.deporteId];
      if (creadoEn != null) {
        final diaDeCreacion = DateTime(
          creadoEn.year,
          creadoEn.month,
          creadoEn.day,
        );
        if (registro.fecha.isBefore(diaDeCreacion)) continue;
      }

      if (registro.estuvoPresente) {
        presentes++;
      } else {
        ausentes++;
      }
    }

    return ResumenAsistenciaAdmin(presentes: presentes, ausentes: ausentes);
  }
}

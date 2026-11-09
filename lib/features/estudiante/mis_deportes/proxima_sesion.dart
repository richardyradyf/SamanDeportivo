import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

/// La próxima sesión de entrenamiento del estudiante, entre todos sus
/// deportes ("Tu próxima actividad" del Figma).
class ProximaSesion {
  const ProximaSesion({
    required this.deporte,
    required this.horario,
    required this.inicio,
  });

  final Deporte deporte;
  final HorarioSesion horario;

  /// Día y hora en que empieza.
  final DateTime inicio;
}

DateTime _alMinuto(DateTime dia, int minutos) =>
    DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);

/// La sesión más cercana a [ahora] entre los horarios semanales de
/// [deportes]. Una sesión que está ocurriendo todavía cuenta; una que ya
/// terminó hoy pasa a la semana siguiente. Null si no hay horarios.
ProximaSesion? proximaSesion(List<Deporte> deportes, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  ProximaSesion? mejor;
  for (final deporte in deportes) {
    for (final horario in deporte.horarios) {
      // DiaSemana empieza en lunes (0); DateTime.weekday, en lunes (1).
      var dias = (horario.dia.index - (ahora.weekday - 1)) % 7;
      if (dias == 0 && !_alMinuto(hoy, horario.finEnMinutos).isAfter(ahora)) {
        dias = 7;
      }
      final dia = DateTime(hoy.year, hoy.month, hoy.day + dias);
      final inicio = _alMinuto(dia, horario.inicioEnMinutos);
      if (mejor == null || inicio.isBefore(mejor.inicio)) {
        mejor = ProximaSesion(deporte: deporte, horario: horario, inicio: inicio);
      }
    }
  }
  return mejor;
}

/// "Hoy · 16:00", "Mañana · 16:00" o "Jueves · 16:00".
String cuandoEs(DateTime inicio, DateTime ahora) {
  // En UTC para que un cambio de horario de verano no mueva la cuenta.
  final hoy = DateTime.utc(ahora.year, ahora.month, ahora.day);
  final dia = DateTime.utc(inicio.year, inicio.month, inicio.day);
  final dias = dia.difference(hoy).inDays;
  final hora =
      '${inicio.hour.toString().padLeft(2, '0')}:'
      '${inicio.minute.toString().padLeft(2, '0')}';
  final nombre = switch (dias) {
    0 => 'Hoy',
    1 => 'Mañana',
    _ => DiaSemana.values[inicio.weekday - 1].etiqueta,
  };
  return '$nombre · $hora';
}

/// Asistencia del estudiante en un deporte: sesiones con registro y en
/// cuántas estuvo presente.
class ResumenAsistenciaDeporte {
  const ResumenAsistenciaDeporte({required this.presentes, required this.total});

  final int presentes;
  final int total;

  /// De 0 a 100, redondeado. Sin registros es 0.
  int get porcentaje => total == 0 ? 0 : (100 * presentes / total).round();

  /// Agrupa los registros por deporte.
  static Map<String, ResumenAsistenciaDeporte> porDeporte(
    List<Asistencia> registros,
  ) {
    final presentes = <String, int>{};
    final totales = <String, int>{};
    for (final registro in registros) {
      totales.update(registro.deporteId, (n) => n + 1, ifAbsent: () => 1);
      if (registro.estuvoPresente) {
        presentes.update(registro.deporteId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return {
      for (final codigo in totales.keys)
        codigo: ResumenAsistenciaDeporte(
          presentes: presentes[codigo] ?? 0,
          total: totales[codigo]!,
        ),
    };
  }
}

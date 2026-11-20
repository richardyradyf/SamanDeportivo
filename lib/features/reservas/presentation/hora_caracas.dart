/// Fechas y horas de las reservas en la hora de la universidad.
///
/// Las reservas guardan instantes exactos y las validaciones de
/// [ValidacionesReserva] comparan las clases en hora de Caracas (UTC-04).
/// Las pantallas usan estas funciones para construir y mostrar las horas en
/// esa misma zona, sin importar la zona del dispositivo.
abstract final class HoraCaracas {
  /// Venezuela usa UTC-04 todo el año (mismo valor que las validaciones).
  static const desfase = Duration(hours: 4);

  /// El instante en que comienza [hora]:[minuto] del día [dia] en Caracas.
  /// Solo se usan el año, mes y día de [dia].
  static DateTime instante(DateTime dia, int hora, [int minuto = 0]) =>
      DateTime.utc(dia.year, dia.month, dia.day, hora, minuto).add(desfase);

  /// [instante] expresado como fecha y hora de pared en Caracas. El
  /// resultado es UTC solo como contenedor: sus campos son la hora local.
  static DateTime enCaracas(DateTime instante) =>
      instante.toUtc().subtract(desfase);

  /// El día de Caracas en que cae [instante], a medianoche (campos locales).
  static DateTime diaDe(DateTime instante) {
    final local = enCaracas(instante);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Minutos desde la medianoche de Caracas.
  static int minutosDelDia(DateTime instante) {
    final local = enCaracas(instante);
    return local.hour * 60 + local.minute;
  }

  /// "16:00".
  static String hora(DateTime instante) {
    final local = enCaracas(instante);
    return '${_dos(local.hour)}:${_dos(local.minute)}';
  }

  /// "16:00 - 18:00".
  static String rango(DateTime inicio, DateTime fin) =>
      '${hora(inicio)} - ${hora(fin)}';

  /// "16/11/2026".
  static String fecha(DateTime instante) {
    final local = enCaracas(instante);
    return '${_dos(local.day)}/${_dos(local.month)}/${local.year}';
  }

  /// "Lun 16/11" para los chips de días.
  static String diaCorto(DateTime dia) {
    const nombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${nombres[dia.weekday - 1]} ${_dos(dia.day)}/${_dos(dia.month)}';
  }

  /// "lunes 16/11/2026" para títulos y el detalle.
  static String diaLargo(DateTime instante) {
    const nombres = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    final local = enCaracas(instante);
    return '${nombres[local.weekday - 1]} ${fecha(instante)}';
  }

  /// "09:30" a partir de minutos desde la medianoche.
  static String desdeMinutos(int minutos) =>
      '${_dos(minutos ~/ 60)}:${_dos(minutos % 60)}';

  static String _dos(int n) => n.toString().padLeft(2, '0');
}

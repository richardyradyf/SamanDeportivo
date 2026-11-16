import 'package:flutter/material.dart';

/// El calendario de clases y reservas usa la hora de Venezuela (UTC-04),
/// independientemente de la zona horaria del dispositivo del estudiante.
abstract final class HorarioReservaCaracas {
  static const desfaseUtc = Duration(hours: 4);

  static DateTime fechaLocal(DateTime instante) =>
      instante.toUtc().subtract(desfaseUtc);

  static DateTime inicioDelDia(DateTime dia) =>
      DateTime.utc(dia.year, dia.month, dia.day).add(desfaseUtc);

  static DateTime combinar(DateTime dia, TimeOfDay hora) => DateTime.utc(
    dia.year,
    dia.month,
    dia.day,
    hora.hour,
    hora.minute,
  ).add(desfaseUtc);

  static String fecha(DateTime dia) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${dia.day} de ${meses[dia.month - 1]} de ${dia.year}';
  }

  static String hora(DateTime instante) {
    final local = fechaLocal(instante);
    final horas = local.hour.toString().padLeft(2, '0');
    final minutos = local.minute.toString().padLeft(2, '0');
    return '$horas:$minutos';
  }

  static String fechaHora(DateTime instante) {
    final local = fechaLocal(instante);
    return '${fecha(local)} · ${hora(instante)}';
  }
}

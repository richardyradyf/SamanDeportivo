import 'package:saman_deportivo/models/asistencia.dart';

/// Período del historial de asistencia (RF-14).
enum PeriodoHistorial {
  dia('Día'),
  semana('Semana'),
  mes('Mes');

  const PeriodoHistorial(this.etiqueta);

  final String etiqueta;

  /// Rango [desde, hasta) que contiene a [ref]. La semana empieza el lunes.
  ({DateTime desde, DateTime hasta}) rango(DateTime ref) {
    final d = DateTime(ref.year, ref.month, ref.day);
    final lunes = d.day - (d.weekday - 1);
    return switch (this) {
      PeriodoHistorial.dia => (
          desde: d,
          hasta: DateTime(d.year, d.month, d.day + 1),
        ),
      PeriodoHistorial.semana => (
          desde: DateTime(d.year, d.month, lunes),
          hasta: DateTime(d.year, d.month, lunes + 7),
        ),
      PeriodoHistorial.mes => (
          desde: DateTime(d.year, d.month),
          hasta: DateTime(d.year, d.month + 1),
        ),
    };
  }
}

/// Porcentaje (0 a 100, redondeado) de registros con asistencia presente.
int porcentajeAsistencia(List<Asistencia> registros) => registros.isEmpty
    ? 0
    : (100 * registros.where((a) => a.estuvoPresente).length / registros.length)
        .round();
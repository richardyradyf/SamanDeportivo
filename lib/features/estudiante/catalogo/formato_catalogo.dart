import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

/// Estado de los cupos de un deporte, como las etiquetas del Figma
/// ("Badge / Disponible", "Badge / Pocos cupos", "Badge / Completo").
enum EstadoCupos {
  disponible,
  pocos,
  completo;

  /// Desde cuántos cupos libres se avisa que quedan pocos.
  static const int limitePocos = 3;

  static EstadoCupos de(Deporte deporte) {
    final libres = deporte.cuposDisponibles;
    if (libres <= 0) return EstadoCupos.completo;
    if (libres <= limitePocos) return EstadoCupos.pocos;
    return EstadoCupos.disponible;
  }
}

/// Texto de la etiqueta de cupos. El estado siempre va con texto, nunca
/// solo con color (regla del Figma).
String textoCupos(Deporte deporte) {
  final libres = deporte.cuposDisponibles;
  if (libres <= 0) return 'Sin cupos';
  if (libres == 1) return '1 cupo disponible';
  return '$libres cupos disponibles';
}

/// Resumen de los horarios para la tarjeta, como en el Figma:
/// "Lun / Mié · 16:00". Si las sesiones empiezan a horas distintas,
/// muestra la primera hora y "y más".
String resumenHorarios(List<HorarioSesion> horarios) {
  if (horarios.isEmpty) return 'Horario por definir';

  final ordenados = [...horarios]
    ..sort((a, b) {
      final porDia = a.dia.index.compareTo(b.dia.index);
      return porDia != 0 ? porDia : a.inicioEnMinutos - b.inicioEnMinutos;
    });

  final dias = <DiaSemana>{for (final h in ordenados) h.dia}
      .map((dia) => dia.abreviatura)
      .join(' / ');
  final horas = <String>{for (final h in ordenados) h.horaInicio};
  final hora = horas.length == 1
      ? ordenados.first.horaInicio
      : '${ordenados.first.horaInicio} y más';

  return '$dias · $hora';
}

/// Promedio con una cifra decimal y coma, como se escribe en español: "4,5".
String textoPromedio(double promedio) =>
    promedio.toStringAsFixed(1).replaceAll('.', ',');

/// Calificación del deporte para la tarjeta y el detalle (RF-17):
/// "4,5 · 12 reseñas", "5,0 · 1 reseña" o "Sin calificaciones".
String textoCalificacion(Deporte deporte) {
  final total = deporte.totalResenas;
  if (total <= 0) return 'Sin calificaciones';
  final resenas = total == 1 ? '1 reseña' : '$total reseñas';
  return '${textoPromedio(deporte.promedioCalificacion)} · $resenas';
}

/// Fecha corta para las reseñas: "07/11/2026".
String fechaCorta(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Nombre corto de la disciplina para los chips de filtro.
String etiquetaCortaDisciplina(Disciplina disciplina) {
  return switch (disciplina) {
    Disciplina.colectivo => 'Colectivo',
    Disciplina.individual => 'Individual',
    Disciplina.raqueta => 'Raqueta',
    Disciplina.combate => 'Combate',
    Disciplina.acuatico => 'Acuático',
  };
}

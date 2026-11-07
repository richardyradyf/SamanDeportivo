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

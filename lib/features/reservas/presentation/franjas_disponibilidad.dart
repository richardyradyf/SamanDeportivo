import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';

/// Lo que se muestra en cada franja de la vista de disponibilidad.
enum EstadoFranja {
  disponible('Disponible'),
  clase('Clase'),
  reserva('Reservado'),
  pasada('Ya pasó');

  const EstadoFranja(this.etiqueta);

  final String etiqueta;
}

/// Parte del día para filtrar la vista de disponibilidad.
enum ParteDelDia {
  todo('Todo el día', 6, 22),
  manana('Mañana', 6, 12),
  tarde('Tarde', 12, 18),
  noche('Noche', 18, 22);

  const ParteDelDia(this.etiqueta, this.horaInicio, this.horaFin);

  final String etiqueta;

  /// Horas de Caracas, de [horaInicio] incluida a [horaFin] excluida.
  final int horaInicio;
  final int horaFin;
}

/// Una hora de un espacio en un día concreto.
class FranjaHoraria {
  const FranjaHoraria({
    required this.inicio,
    required this.fin,
    required this.estado,
    this.descripcion,
  });

  final DateTime inicio;
  final DateTime fin;
  final EstadoFranja estado;

  /// Nombre del deporte cuando la ocupa una clase.
  final String? descripcion;

  bool get sePuedeReservar => estado == EstadoFranja.disponible;
}

/// Divide [dia] (en hora de Caracas) en franjas de una hora dentro de
/// [parte] y marca cada una según los [bloques] ocupados.
///
/// Los bloques salen de [ValidacionesReserva.consultarOcupaciones]: aquí no
/// se decide qué choca con qué, solo cómo se dibuja. Si una franja cruza
/// una clase y una reserva, se muestra como clase.
List<FranjaHoraria> franjasDelDia({
  required DateTime dia,
  required List<BloqueOcupado> bloques,
  required DateTime ahora,
  ParteDelDia parte = ParteDelDia.todo,
}) {
  final franjas = <FranjaHoraria>[];
  for (var hora = parte.horaInicio; hora < parte.horaFin; hora++) {
    final inicio = HoraCaracas.instante(dia, hora);
    final fin = HoraCaracas.instante(dia, hora + 1);

    BloqueOcupado? clase;
    BloqueOcupado? reserva;
    for (final bloque in bloques) {
      if (!ValidacionesReserva.seSolapan(inicio, fin, bloque.inicio, bloque.fin)) {
        continue;
      }
      if (bloque.origen == OrigenOcupacion.clase) {
        clase ??= bloque;
      } else {
        reserva ??= bloque;
      }
    }

    final EstadoFranja estado;
    if (clase != null) {
      estado = EstadoFranja.clase;
    } else if (reserva != null) {
      estado = EstadoFranja.reserva;
    } else if (!inicio.isAfter(ahora)) {
      estado = EstadoFranja.pasada;
    } else {
      estado = EstadoFranja.disponible;
    }
    franjas.add(FranjaHoraria(
      inicio: inicio,
      fin: fin,
      estado: estado,
      descripcion: clase?.descripcion,
    ));
  }
  return franjas;
}

/// Resumen de un espacio para su tarjeta: si está libre ahora mismo y, si
/// no, hasta qué hora está ocupado.
class ResumenEspacioHoy {
  const ResumenEspacioHoy({
    required this.libreAhora,
    required this.ocupadasHoy,
    this.ocupadoHasta,
  });

  final bool libreAhora;

  /// Bloques ocupados que todavía no terminan hoy.
  final int ocupadasHoy;
  final DateTime? ocupadoHasta;

  static ResumenEspacioHoy de(List<BloqueOcupado> bloques, DateTime ahora) {
    BloqueOcupado? actual;
    var restantes = 0;
    for (final bloque in bloques) {
      if (bloque.fin.isAfter(ahora)) restantes++;
      if (!bloque.inicio.isAfter(ahora) && bloque.fin.isAfter(ahora)) {
        if (actual == null || bloque.fin.isAfter(actual.fin)) actual = bloque;
      }
    }
    return ResumenEspacioHoy(
      libreAhora: actual == null,
      ocupadasHoy: restantes,
      ocupadoHasta: actual?.fin,
    );
  }
}

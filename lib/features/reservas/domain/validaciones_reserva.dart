import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

class ReservaEspacioException implements Exception {
  const ReservaEspacioException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

enum OrigenOcupacion { reserva, clase }

/// Elemento mínimo de la agenda pública: ni UID ni datos del estudiante.
class BloqueOcupado {
  const BloqueOcupado({
    required this.espacioId,
    required this.inicio,
    required this.fin,
    required this.origen,
    required this.descripcion,
  });

  final String espacioId;
  final DateTime inicio;
  final DateTime fin;
  final OrigenOcupacion origen;
  final String descripcion;
}

/// Reglas puras para todos los roles. Se deben aplicar también en la
/// transacción que confirma la reserva; un formulario nunca es una garantía
/// suficiente contra dos solicitudes simultáneas.
abstract final class ValidacionesReserva {
  static const maximoEstudiante = Duration(hours: 2);
  static const anticipacionEstudiante = Duration(days: 21);

  // Venezuela utiliza UTC-04 para la zona America/Caracas. La conversión a
  // zona horaria debe mantenerse centralizada para una migración futura.
  static const _desfaseCaracas = Duration(hours: 4);

  static bool seSolapan(
    DateTime inicioA,
    DateTime finA,
    DateTime inicioB,
    DateTime finB,
  ) => inicioA.isBefore(finB) && inicioB.isBefore(finA);

  /// Lista los bloques ocupados de un espacio para una vista de calendario.
  /// La pantalla consulta un rango visible de hasta 31 días; esto NO limita
  /// la duración ni anticipación de reservas de entrenadores y administradores.
  static List<BloqueOcupado> consultarOcupaciones({
    required EspacioDeportivo espacio,
    required DateTime desde,
    required DateTime hasta,
    required Iterable<Deporte> deportes,
    required Iterable<OcupacionEspacio> ocupaciones,
  }) {
    if (!hasta.isAfter(desde) ||
        hasta.difference(desde) > const Duration(days: 31)) {
      throw ArgumentError('Consulta un período entre 1 minuto y 31 días.');
    }
    final bloques = <BloqueOcupado>[];

    for (final reserva in ocupaciones) {
      if (reserva.espacioId == espacio.id &&
          seSolapan(desde, hasta, reserva.inicio, reserva.fin)) {
        bloques.add(BloqueOcupado(
          espacioId: espacio.id,
          inicio: reserva.inicio,
          fin: reserva.fin,
          origen: OrigenOcupacion.reserva,
          descripcion: 'Reservado',
        ));
      }
    }

    final localDesde = desde.toUtc().subtract(_desfaseCaracas);
    final localHasta = hasta.toUtc().subtract(_desfaseCaracas);
    var dia = DateTime.utc(localDesde.year, localDesde.month, localDesde.day);
    final ultimo = DateTime.utc(
      localHasta.year,
      localHasta.month,
      localHasta.day,
    );
    while (!dia.isAfter(ultimo)) {
      for (final deporte in deportes) {
        if (!deporte.activo) continue;
        for (final horario in deporte.horarios) {
          if (!_correspondeAlEspacio(espacio, horario) ||
              horario.dia.index + 1 != dia.weekday ||
              !horario.esValido) {
            continue;
          }
          final inicioClase = dia.add(Duration(
            minutes: horario.inicioEnMinutos,
          )).add(_desfaseCaracas);
          final finClase = dia.add(Duration(
            minutes: horario.finEnMinutos,
          )).add(_desfaseCaracas);
          if (seSolapan(desde, hasta, inicioClase, finClase)) {
            bloques.add(BloqueOcupado(
              espacioId: espacio.id,
              inicio: inicioClase,
              fin: finClase,
              origen: OrigenOcupacion.clase,
              descripcion: deporte.nombre,
            ));
          }
        }
      }
      dia = dia.add(const Duration(days: 1));
    }

    bloques.sort((a, b) => a.inicio.compareTo(b.inicio));
    return bloques;
  }

  static void validarSolicitud({
    required EspacioDeportivo espacio,
    required Rol rol,
    required DateTime inicio,
    required DateTime fin,
    required DateTime ahora,
    required String motivo,
    required Iterable<Deporte> deportes,
    required Iterable<OcupacionEspacio> ocupaciones,
    String? reservaExcluidaId,
  }) {
    if (!espacio.activo) {
      throw const ReservaEspacioException('El espacio no está disponible.');
    }
    if (!inicio.isAfter(ahora)) {
      throw const ReservaEspacioException(
        'Las reservas deben comenzar en una fecha futura.',
      );
    }
    if (!fin.isAfter(inicio)) {
      throw const ReservaEspacioException(
        'La hora de finalización debe ser posterior a la de inicio.',
      );
    }
    final motivoLimpio = motivo.trim();
    if (motivoLimpio.length < 3 || motivoLimpio.length > 200) {
      throw const ReservaEspacioException(
        'El motivo debe tener entre 3 y 200 caracteres.',
      );
    }
    if (rol == Rol.estudiante) {
      if (fin.difference(inicio) > maximoEstudiante) {
        throw const ReservaEspacioException(
          'Los estudiantes pueden reservar como máximo 2 horas.',
        );
      }
      if (fin.isAfter(ahora.add(anticipacionEstudiante))) {
        throw const ReservaEspacioException(
          'Los estudiantes solo pueden reservar dentro de 3 semanas.',
        );
      }
    }

    for (final ocupacion in ocupaciones) {
      if (ocupacion.espacioId == espacio.id &&
          ocupacion.id != reservaExcluidaId &&
          seSolapan(inicio, fin, ocupacion.inicio, ocupacion.fin)) {
        throw const ReservaEspacioException(
          'Ese espacio ya tiene una reserva durante el horario solicitado.',
        );
      }
    }

    for (final deporte in deportes) {
      if (!deporte.activo) continue;
      for (final horario in deporte.horarios) {
        if (_correspondeAlEspacio(espacio, horario) &&
            _cruzaClaseSemanal(inicio, fin, horario)) {
          throw ReservaEspacioException(
            'El espacio está ocupado por ${deporte.nombre} en ese horario.',
          );
        }
      }
    }
  }

  static bool _correspondeAlEspacio(
    EspacioDeportivo espacio,
    HorarioSesion horario,
  ) {
    if (horario.espacioId != null) {
      return espacio.id == horario.espacioId;
    }
    // Solo por compatibilidad con las clases del Hito 3 sin espacioId.
    return espacio.nombre.trim().toLowerCase() ==
        horario.lugar.trim().toLowerCase();
  }

  /// Busca la siguiente sesión semanal en hora Caracas y, si hace falta, la
  /// de la semana siguiente. Es O(1) incluso para reservas muy largas.
  static bool _cruzaClaseSemanal(
    DateTime inicio,
    DateTime fin,
    HorarioSesion horario,
  ) {
    if (!horario.esValido) return false;
    final inicioCaracas = inicio.toUtc().subtract(_desfaseCaracas);
    final diaInicial = DateTime.utc(
      inicioCaracas.year,
      inicioCaracas.month,
      inicioCaracas.day,
    );
    final diasHastaClase =
        (horario.dia.index + 1 - diaInicial.weekday + 7) % 7;
    final primeraClase = diaInicial.add(
      Duration(days: diasHastaClase, minutes: horario.inicioEnMinutos),
    ).add(_desfaseCaracas);
    final duracion = Duration(
      minutes: horario.finEnMinutos - horario.inicioEnMinutos,
    );

    for (final semanas in [0, 1]) {
      final comienzo = primeraClase.add(Duration(days: 7 * semanas));
      if (seSolapan(inicio, fin, comienzo, comienzo.add(duracion))) {
        return true;
      }
    }
    return false;
  }
}

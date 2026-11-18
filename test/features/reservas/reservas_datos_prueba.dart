import 'dart:async';

import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/data/reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Lunes 16/11/2026 en Caracas.
final lunes = DateTime.utc(2026, 11, 16);

/// Instante de [hora]:[minuto] de [dia] en Caracas.
DateTime en(DateTime dia, int hora, [int minuto = 0]) =>
    HoraCaracas.instante(dia, hora, minuto);

final tenis1 = EspacioDeportivo(
  id: 'tenis-1',
  nombre: 'Cancha de tenis 1',
  tipo: 'Cancha de tenis',
  creadoEn: DateTime(2026, 11, 1),
);
final tenis2 = EspacioDeportivo(
  id: 'tenis-2',
  nombre: 'Cancha de tenis 2',
  tipo: 'Cancha de tenis',
  creadoEn: DateTime(2026, 11, 1),
);
final gimnasio = EspacioDeportivo(
  id: 'gym-1',
  nombre: 'Gimnasio 1',
  tipo: 'Gimnasio',
  creadoEn: DateTime(2026, 11, 1),
);
final inactivo = EspacioDeportivo(
  id: 'futbol-1',
  nombre: 'Cancha de fútbol 1',
  tipo: 'Cancha de fútbol',
  activo: false,
  creadoEn: DateTime(2026, 11, 1),
);

/// Tenis los lunes de 16:00 a 18:00 en la cancha 1.
final tenis = Deporte(
  codigo: 'TEN-01',
  nombre: 'Tenis',
  descripcion: 'Clases de tenis.',
  disciplina: Disciplina.raqueta,
  costo: 15,
  cupoMaximo: 10,
  creadoEn: DateTime(2026, 11, 1),
  horarios: const [
    HorarioSesion(
      dia: DiaSemana.lunes,
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha de tenis 1',
      espacioId: 'tenis-1',
    ),
  ],
);

/// Reserva de otra persona: lunes de 10:00 a 12:00 en la cancha 1.
final ocupacionLunes = OcupacionEspacio(
  id: 'r-otra',
  espacioId: 'tenis-1',
  inicio: en(lunes, 10),
  fin: en(lunes, 12),
);

ReservaEspacio reserva(
  String id, {
  required DateTime inicio,
  required DateTime fin,
  String espacioId = 'tenis-1',
  EstadoReservaEspacio estado = EstadoReservaEspacio.activa,
  String motivo = 'Práctica libre',
}) => ReservaEspacio(
  id: id,
  espacioId: espacioId,
  usuarioUid: 'est-1',
  rol: Rol.estudiante,
  inicio: inicio,
  fin: fin,
  motivo: motivo,
  estado: estado,
  creadoEn: DateTime.utc(2026, 11, 10, 14),
  actualizadoEn: estado == EstadoReservaEspacio.cancelada
      ? DateTime.utc(2026, 11, 12, 14)
      : null,
);

class EspaciosFalsos implements EspacioRepository {
  EspaciosFalsos(this.lista);

  final List<EspacioDeportivo> lista;

  @override
  Stream<List<EspacioDeportivo>> observarTodos() => Stream.value(lista);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Reservas no usa ${invocation.memberName}');
}

class DeportesFalsos implements DeporteRepository {
  DeportesFalsos(this.lista);

  final List<Deporte> lista;

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value(lista);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Reservas no usa ${invocation.memberName}');
}

class DisponibilidadFalsa implements DisponibilidadRepository {
  DisponibilidadFalsa(this.ocupaciones, {this.fallar = false});

  final List<OcupacionEspacio> ocupaciones;
  final bool fallar;

  @override
  Stream<List<OcupacionEspacio>> observarOcupaciones({
    required String espacioId,
    required DateTime desde,
    required DateTime hasta,
  }) {
    if (fallar) return Stream.error(Exception('sin conexión'));
    return Stream.value([
      for (final o in ocupaciones)
        if (o.espacioId == espacioId &&
            o.inicio.isBefore(hasta) &&
            o.fin.isAfter(desde))
          o,
    ]);
  }
}

class ReservasFalsas implements ReservasRepository {
  ReservasFalsas({
    this.propias = const [],
    this.errorAlCrear,
    this.pendiente,
  });

  final List<ReservaEspacio> propias;

  /// Si se pasa, [crear] lo lanza.
  final Object? errorAlCrear;

  /// Si se pasa, [crear] espera a que se complete (para ver la carga).
  final Completer<void>? pendiente;

  final creadas = <({String espacioId, DateTime inicio, DateTime fin, String motivo})>[];
  final canceladas = <String>[];

  @override
  Stream<List<ReservaEspacio>> observarPropias(String usuarioUid) =>
      Stream.value(propias);

  @override
  Future<String> crear({
    required String espacioId,
    required DateTime inicio,
    required DateTime fin,
    required String motivo,
  }) async {
    final espera = pendiente;
    if (espera != null) await espera.future;
    final error = errorAlCrear;
    if (error != null) throw error;
    creadas.add((espacioId: espacioId, inicio: inicio, fin: fin, motivo: motivo));
    return 'nueva-${creadas.length}';
  }

  @override
  Future<void> cancelar(String reservaId) async {
    canceladas.add(reservaId);
  }
}

/// Error de la transacción, como el que da el repositorio real.
const choque = ReservaEspacioException(
  'Ese espacio ya tiene una reserva durante el horario solicitado.',
);

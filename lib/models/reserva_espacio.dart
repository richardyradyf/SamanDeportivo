import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';
import 'enums.dart';

enum EstadoReservaEspacio { activa, cancelada }

/// Reserva personal de una instalación. La identidad del propietario se guarda
/// únicamente en `reservasEspacios`, nunca en la vista de disponibilidad.
class ReservaEspacio {
  const ReservaEspacio({
    required this.id,
    required this.espacioId,
    required this.usuarioUid,
    required this.rol,
    required this.inicio,
    required this.fin,
    required this.motivo,
    required this.creadoEn,
    this.estado = EstadoReservaEspacio.activa,
    this.actualizadoEn,
  });

  final String id;
  final String espacioId;
  final String usuarioUid;
  final Rol rol;
  final DateTime inicio;
  final DateTime fin;
  final String motivo;
  final EstadoReservaEspacio estado;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;

  bool get estaActiva => estado == EstadoReservaEspacio.activa;

  Map<String, dynamic> toMap() => {
    'espacioId': espacioId,
    'usuarioUid': usuarioUid,
    'rol': rol.name,
    'inicio': Timestamp.fromDate(inicio),
    'fin': Timestamp.fromDate(fin),
    'motivo': motivo.trim(),
    'estado': estado.name,
    'creadoEn': Timestamp.fromDate(creadoEn),
    'actualizadoEn': actualizadoEn == null
        ? null
        : Timestamp.fromDate(actualizadoEn!),
  };

  factory ReservaEspacio.fromMap(String id, Map<String, dynamic> datos) {
    return ReservaEspacio(
      id: id,
      espacioId: datos['espacioId'] as String? ?? '',
      usuarioUid: datos['usuarioUid'] as String? ?? '',
      rol: Rol.desdeTexto(datos['rol'] as String?),
      inicio: leerFecha(datos['inicio']),
      fin: leerFecha(datos['fin']),
      motivo: datos['motivo'] as String? ?? '',
      estado: EstadoReservaEspacio.values.byName(
        datos['estado'] as String? ?? 'activa',
      ),
      creadoEn: leerFecha(datos['creadoEn']),
      actualizadoEn: leerFechaOpcional(datos['actualizadoEn']),
    );
  }

  ReservaEspacio cancelar(DateTime fecha) => ReservaEspacio(
    id: id,
    espacioId: espacioId,
    usuarioUid: usuarioUid,
    rol: rol,
    inicio: inicio,
    fin: fin,
    motivo: motivo,
    creadoEn: creadoEn,
    estado: EstadoReservaEspacio.cancelada,
    actualizadoEn: fecha,
  );
}

/// Ocupación pública sin nombre, cédula, correo, teléfono, UID ni motivo.
/// El documento tiene el mismo ID de la reserva privada de la cual proviene.
class OcupacionEspacio {
  const OcupacionEspacio({
    required this.id,
    required this.espacioId,
    required this.inicio,
    required this.fin,
  });

  final String id;
  final String espacioId;
  final DateTime inicio;
  final DateTime fin;

  Map<String, dynamic> toMap() => {
    'espacioId': espacioId,
    'inicio': Timestamp.fromDate(inicio),
    'fin': Timestamp.fromDate(fin),
  };

  factory OcupacionEspacio.fromMap(String id, Map<String, dynamic> datos) {
    return OcupacionEspacio(
      id: id,
      espacioId: datos['espacioId'] as String? ?? '',
      inicio: leerFecha(datos['inicio']),
      fin: leerFecha(datos['fin']),
    );
  }
}

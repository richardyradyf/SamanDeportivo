import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';
import 'enums.dart';

/// Asistencia de un estudiante a una sesión (RF-14).
/// Colección `asistencias`; el ID es `{codigo}_{AAAA-MM-DD}_{estudianteUid}`,
/// así no se registra dos veces al mismo estudiante el mismo día.
class Asistencia {
  final String id;
  final String inscripcionId;
  final String estudianteUid;
  final String estudianteNombre;
  final String deporteId;
  final String entrenadorUid;

  /// Día del entrenamiento a las 00:00.
  final DateTime fecha;
  final EstadoAsistencia estado;

  const Asistencia({
    required this.id,
    required this.inscripcionId,
    required this.estudianteUid,
    required this.estudianteNombre,
    required this.deporteId,
    required this.entrenadorUid,
    required this.fecha,
    required this.estado,
  });

  static String idPara(String codigoDeporte, DateTime fecha, String estudianteUid) =>
      '${codigoDeporte}_${fechaComoId(fecha)}_$estudianteUid';

  /// Crea el registro con el ID correcto y la fecha sin hora.
  factory Asistencia.registrar({
    required String inscripcionId,
    required String estudianteUid,
    required String estudianteNombre,
    required String deporteId,
    required String entrenadorUid,
    required DateTime fecha,
    required EstadoAsistencia estado,
  }) {
    final dia = soloDia(fecha);
    return Asistencia(
      id: idPara(deporteId, dia, estudianteUid),
      inscripcionId: inscripcionId,
      estudianteUid: estudianteUid,
      estudianteNombre: estudianteNombre,
      deporteId: deporteId,
      entrenadorUid: entrenadorUid,
      fecha: dia,
      estado: estado,
    );
  }

  bool get estuvoPresente => estado == EstadoAsistencia.presente;

  Map<String, dynamic> toMap() {
    return {
      'inscripcionId': inscripcionId,
      'estudianteUid': estudianteUid,
      'estudianteNombre': estudianteNombre,
      'deporteId': deporteId,
      'entrenadorUid': entrenadorUid,
      'fecha': Timestamp.fromDate(fecha),
      'estado': estado.name,
    };
  }

  factory Asistencia.fromMap(String id, Map<String, dynamic> datos) {
    return Asistencia(
      id: id,
      inscripcionId: datos['inscripcionId'] as String? ?? '',
      estudianteUid: datos['estudianteUid'] as String? ?? '',
      estudianteNombre: datos['estudianteNombre'] as String? ?? '',
      deporteId: datos['deporteId'] as String? ?? '',
      entrenadorUid: datos['entrenadorUid'] as String? ?? '',
      fecha: leerFecha(datos['fecha']),
      estado: EstadoAsistencia.desdeTexto(datos['estado'] as String?),
    );
  }
}

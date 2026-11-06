import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';
import 'deporte.dart';
import 'enums.dart';
import 'estudiante.dart';

/// Un cambio de estado de la inscripción: cuándo y quién (RF-08).
class CambioEstado {
  final EstadoInscripcion estado;
  final DateTime fecha;
  final String responsableUid;

  const CambioEstado({
    required this.estado,
    required this.fecha,
    required this.responsableUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'estado': estado.name,
      'fecha': Timestamp.fromDate(fecha),
      'responsableUid': responsableUid,
    };
  }

  factory CambioEstado.fromMap(Map<String, dynamic> datos) {
    return CambioEstado(
      estado: EstadoInscripcion.desdeTexto(datos['estado'] as String?),
      fecha: leerFecha(datos['fecha']),
      responsableUid: datos['responsableUid'] as String? ?? '',
    );
  }
}

/// Inscripción de un estudiante en un deporte (RF-07 a RF-10).
/// Colección `inscripciones`; el ID es `{estudianteUid}_{codigoDeporte}`,
/// lo que impide inscribirse dos veces en el mismo deporte.
class Inscripcion {
  final String id;
  final String estudianteUid;

  // Copias del estudiante para la nómina del entrenador (RF-13).
  final String estudianteCedula;
  final String estudianteNombre;
  final String estudianteCarnet;
  final String estudianteCorreo;

  /// Código del deporte.
  final String deporteId;
  final String deporteNombre;
  final String? entrenadorUid;

  final EstadoInscripcion estado;

  /// Motivo de rechazo o expiración.
  final String? motivo;
  final DateTime fechaInscripcion;
  final DateTime fechaLimitePago;
  final String? pagoId;
  final List<CambioEstado> historial;

  const Inscripcion({
    required this.id,
    required this.estudianteUid,
    required this.estudianteCedula,
    required this.estudianteNombre,
    required this.estudianteCarnet,
    required this.estudianteCorreo,
    required this.deporteId,
    required this.deporteNombre,
    required this.estado,
    required this.fechaInscripcion,
    required this.fechaLimitePago,
    this.entrenadorUid,
    this.motivo,
    this.pagoId,
    this.historial = const [],
  });

  /// Tiempo para pagar antes de que la inscripción expire.
  static const Duration plazoDePago = Duration(hours: 24);

  static String idPara(String estudianteUid, String codigoDeporte) =>
      '${estudianteUid}_$codigoDeporte';

  /// Crea una inscripción nueva en estado pendiente.
  factory Inscripcion.nueva({
    required Estudiante estudiante,
    required Deporte deporte,
    DateTime? ahora,
  }) {
    final fecha = ahora ?? DateTime.now();
    return Inscripcion(
      id: idPara(estudiante.uid, deporte.codigo),
      estudianteUid: estudiante.uid,
      estudianteCedula: estudiante.cedula,
      estudianteNombre: estudiante.nombre,
      estudianteCarnet: estudiante.carnet,
      estudianteCorreo: estudiante.correo,
      deporteId: deporte.codigo,
      deporteNombre: deporte.nombre,
      entrenadorUid: deporte.entrenadorUid,
      estado: EstadoInscripcion.pendiente,
      fechaInscripcion: fecha,
      fechaLimitePago: fecha.add(plazoDePago),
      historial: [
        CambioEstado(
          estado: EstadoInscripcion.pendiente,
          fecha: fecha,
          responsableUid: estudiante.uid,
        ),
      ],
    );
  }

  bool get ocupaCupo => estado.ocupaCupo;

  /// Pendiente y fuera de plazo: hay que pasarla a expirada.
  bool estaVencida([DateTime? ahora]) =>
      estado == EstadoInscripcion.pendiente &&
      (ahora ?? DateTime.now()).isAfter(fechaLimitePago);

  /// Devuelve una copia con el nuevo estado y lo agrega al historial.
  Inscripcion conEstado(
    EstadoInscripcion nuevo, {
    required String responsableUid,
    String? motivo,
    String? pagoId,
    DateTime? fecha,
  }) {
    final cuando = fecha ?? DateTime.now();
    return Inscripcion(
      id: id,
      estudianteUid: estudianteUid,
      estudianteCedula: estudianteCedula,
      estudianteNombre: estudianteNombre,
      estudianteCarnet: estudianteCarnet,
      estudianteCorreo: estudianteCorreo,
      deporteId: deporteId,
      deporteNombre: deporteNombre,
      entrenadorUid: entrenadorUid,
      estado: nuevo,
      motivo: motivo ?? this.motivo,
      fechaInscripcion: fechaInscripcion,
      fechaLimitePago: fechaLimitePago,
      pagoId: pagoId ?? this.pagoId,
      historial: [
        ...historial,
        CambioEstado(estado: nuevo, fecha: cuando, responsableUid: responsableUid),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estudianteUid': estudianteUid,
      'estudianteCedula': estudianteCedula,
      'estudianteNombre': estudianteNombre,
      'estudianteCarnet': estudianteCarnet,
      'estudianteCorreo': estudianteCorreo,
      'deporteId': deporteId,
      'deporteNombre': deporteNombre,
      'entrenadorUid': entrenadorUid,
      'estado': estado.name,
      'motivo': motivo,
      'fechaInscripcion': Timestamp.fromDate(fechaInscripcion),
      'fechaLimitePago': Timestamp.fromDate(fechaLimitePago),
      'pagoId': pagoId,
      'historial': historial.map((c) => c.toMap()).toList(),
    };
  }

  factory Inscripcion.fromMap(String id, Map<String, dynamic> datos) {
    final historial = (datos['historial'] as List<dynamic>? ?? const [])
        .map((c) => CambioEstado.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();

    return Inscripcion(
      id: id,
      estudianteUid: datos['estudianteUid'] as String? ?? '',
      estudianteCedula: datos['estudianteCedula'] as String? ?? '',
      estudianteNombre: datos['estudianteNombre'] as String? ?? '',
      estudianteCarnet: datos['estudianteCarnet'] as String? ?? '',
      estudianteCorreo: datos['estudianteCorreo'] as String? ?? '',
      deporteId: datos['deporteId'] as String? ?? '',
      deporteNombre: datos['deporteNombre'] as String? ?? '',
      entrenadorUid: datos['entrenadorUid'] as String?,
      estado: EstadoInscripcion.desdeTexto(datos['estado'] as String?),
      motivo: datos['motivo'] as String?,
      fechaInscripcion: leerFecha(datos['fechaInscripcion']),
      fechaLimitePago: leerFecha(datos['fechaLimitePago']),
      pagoId: datos['pagoId'] as String?,
      historial: historial,
    );
  }
}

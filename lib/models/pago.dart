import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';
import 'enums.dart';

/// Pago de la reserva de un cupo con PayPal (RF-11, RF-12).
/// Colección `pagos`. No guarda datos de tarjeta (RNF-03).
class Pago {
  final String id;
  final String inscripcionId;
  final String estudianteUid;
  final String deporteId;
  final String deporteNombre;

  /// ID de la orden en PayPal.
  final String paypalOrderId;

  /// ID de la captura en PayPal; sirve de comprobante.
  final String? paypalCaptureId;
  final double monto;
  final String moneda;
  final EstadoPago estado;
  final DateTime fecha;

  const Pago({
    required this.id,
    required this.inscripcionId,
    required this.estudianteUid,
    required this.deporteId,
    required this.deporteNombre,
    required this.paypalOrderId,
    required this.monto,
    required this.estado,
    required this.fecha,
    this.paypalCaptureId,
    this.moneda = 'USD',
  });

  bool get estaAprobado => estado == EstadoPago.aprobado;

  Map<String, dynamic> toMap() {
    return {
      'inscripcionId': inscripcionId,
      'estudianteUid': estudianteUid,
      'deporteId': deporteId,
      'deporteNombre': deporteNombre,
      'paypalOrderId': paypalOrderId,
      'paypalCaptureId': paypalCaptureId,
      'monto': monto,
      'moneda': moneda,
      'estado': estado.name,
      'fecha': Timestamp.fromDate(fecha),
    };
  }

  factory Pago.fromMap(String id, Map<String, dynamic> datos) {
    return Pago(
      id: id,
      inscripcionId: datos['inscripcionId'] as String? ?? '',
      estudianteUid: datos['estudianteUid'] as String? ?? '',
      deporteId: datos['deporteId'] as String? ?? '',
      deporteNombre: datos['deporteNombre'] as String? ?? '',
      paypalOrderId: datos['paypalOrderId'] as String? ?? '',
      paypalCaptureId: datos['paypalCaptureId'] as String?,
      monto: leerDecimal(datos['monto']),
      moneda: datos['moneda'] as String? ?? 'USD',
      estado: EstadoPago.desdeTexto(datos['estado'] as String?),
      fecha: leerFecha(datos['fecha']),
    );
  }
}

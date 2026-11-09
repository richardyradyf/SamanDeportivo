import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

/// Lo que devuelve pago_resultado.html al terminar en PayPal.
class ResultadoPaypal {
  const ResultadoPaypal({
    required this.estado,
    this.orderId,
    this.captureId,
    this.monto,
  });

  factory ResultadoPaypal.desdeMapa(Map<String, String?> m) => ResultadoPaypal(
        estado: m['estado'] ?? 'ERROR',
        orderId: m['orderId'],
        captureId: m['captureId'],
        monto: double.tryParse(m['monto'] ?? ''),
      );

  final String estado;
  final String? orderId;
  final String? captureId;
  final double? monto;

  bool get completado =>
      estado == 'COMPLETED' && orderId != null && captureId != null;
  bool get cancelado => estado == 'CANCELLED';
}

/// En web usa la página servida por la propia app (sirve también en local).
/// En Android usa la publicada, o la que se pase con --dart-define=URL_PAGOS.
Uri urlPagar({
  required String inscripcionId,
  required double monto,
  required String deporte,
}) {
  final base = kIsWeb
      ? Uri.base.resolve('pagar.html')
      : Uri.parse(const String.fromEnvironment(
          'URL_PAGOS',
          defaultValue: 'https://saman-deportivo.web.app/pagar.html',
        ));
  return base.replace(queryParameters: {
    'inscripcion': inscripcionId,
    'monto': monto.toStringAsFixed(2),
    'deporte': deporte,
  });
}

/// Arma el pago aprobado que se guarda en `pagos/{orderId}`.
/// El monto es el costo del deporte: las reglas exigen que coincidan.
Pago pagoDesdePaypal({
  required Inscripcion inscripcion,
  required ResultadoPaypal resultado,
  required double monto,
  DateTime? ahora,
}) {
  final orderId = resultado.orderId!;
  return Pago(
    id: orderId,
    inscripcionId: inscripcion.id,
    estudianteUid: inscripcion.estudianteUid,
    deporteId: inscripcion.deporteId,
    deporteNombre: inscripcion.deporteNombre,
    paypalOrderId: orderId,
    paypalCaptureId: resultado.captureId,
    monto: monto,
    estado: EstadoPago.aprobado,
    fecha: ahora ?? DateTime.now(),
  );
}

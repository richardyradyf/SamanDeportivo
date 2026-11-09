import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

Inscripcion _inscripcion() => Inscripcion(
      id: 'est-1_BAL-01',
      estudianteUid: 'est-1',
      estudianteCedula: '28000001',
      estudianteNombre: 'Ana Pérez',
      estudianteCarnet: '20231001',
      estudianteCorreo: 'ana@correo.unimet.edu.ve',
      deporteId: 'BAL-01',
      deporteNombre: 'Baloncesto',
      estado: EstadoInscripcion.pendiente,
      fechaInscripcion: DateTime(2026, 11, 8, 10),
      fechaLimitePago: DateTime(2026, 11, 9, 10),
    );

void main() {
  group('ResultadoPaypal', () {
    test('un pago completado trae orderId y captureId', () {
      final r = ResultadoPaypal.desdeMapa({
        'estado': 'COMPLETED',
        'orderId': 'ORDEN-1',
        'captureId': 'CAP-1',
        'monto': '10.00',
      });
      expect(r.completado, isTrue);
      expect(r.cancelado, isFalse);
      expect(r.monto, 10);
    });

    test('sin captureId no cuenta como completado', () {
      final r = ResultadoPaypal.desdeMapa({
        'estado': 'COMPLETED',
        'orderId': 'ORDEN-1',
      });
      expect(r.completado, isFalse);
    });

    test('reconoce la cancelación', () {
      final r = ResultadoPaypal.desdeMapa({'estado': 'CANCELLED'});
      expect(r.cancelado, isTrue);
      expect(r.completado, isFalse);
    });

    test('sin estado se trata como error', () {
      final r = ResultadoPaypal.desdeMapa({});
      expect(r.estado, 'ERROR');
      expect(r.completado, isFalse);
    });
  });

  group('pagoDesdePaypal', () {
    test('arma un pago aprobado con el orderId como ID', () {
      final pago = pagoDesdePaypal(
        inscripcion: _inscripcion(),
        resultado: const ResultadoPaypal(
          estado: 'COMPLETED',
          orderId: 'ORDEN-1',
          captureId: 'CAP-1',
          monto: 10,
        ),
        monto: 10,
        ahora: DateTime(2026, 11, 8, 12),
      );
      expect(pago.id, 'ORDEN-1');
      expect(pago.paypalOrderId, 'ORDEN-1');
      expect(pago.paypalCaptureId, 'CAP-1');
      expect(pago.inscripcionId, 'est-1_BAL-01');
      expect(pago.estudianteUid, 'est-1');
      expect(pago.deporteId, 'BAL-01');
      expect(pago.monto, 10);
      expect(pago.estado, EstadoPago.aprobado);
    });
  });

  group('urlPagar', () {
    test('lleva la inscripción, el monto y el deporte', () {
      final url = urlPagar(
        inscripcionId: 'est-1_BAL-01',
        monto: 10,
        deporte: 'Baloncesto',
      );
      expect(url.path, endsWith('pagar.html'));
      expect(url.queryParameters['inscripcion'], 'est-1_BAL-01');
      expect(url.queryParameters['monto'], '10.00');
      expect(url.queryParameters['deporte'], 'Baloncesto');
    });
  });
}
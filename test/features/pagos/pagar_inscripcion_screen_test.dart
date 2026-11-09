import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';
import 'package:saman_deportivo/features/pagos/presentation/pagar_inscripcion_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

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

/// Reemplaza a PayPal: dos botones que simulan cómo terminó el pago.
Widget _vistaFalsa(Uri url, ValueChanged<ResultadoPaypal> onTerminar) {
  return Column(
    children: [
      TextButton(
        onPressed: () => onTerminar(const ResultadoPaypal(
          estado: 'COMPLETED',
          orderId: 'ORDEN-1',
          captureId: 'CAP-1',
          monto: 10,
        )),
        child: const Text('Simular aprobado'),
      ),
      TextButton(
        onPressed: () =>
            onTerminar(const ResultadoPaypal(estado: 'CANCELLED')),
        child: const Text('Simular cancelado'),
      ),
    ],
  );
}

Future<void> _mostrar(WidgetTester tester, ConfirmarPago confirmar) {
  return tester.pumpWidget(MaterialApp(
    home: PagarInscripcionScreen(
      inscripcion: _inscripcion(),
      monto: 10,
      confirmar: confirmar,
      construirVista: _vistaFalsa,
    ),
  ));
}

void main() {
  testWidgets('pago aprobado: registra el pago y lo confirma', (tester) async {
    final llamadas = <ResultadoPaypal>[];
    await _mostrar(tester, (inscripcion, resultado, monto) async {
      expect(inscripcion.id, 'est-1_BAL-01');
      expect(monto, 10);
      llamadas.add(resultado);
    });

    expect(find.text('Baloncesto'), findsOneWidget);
    expect(find.text('Monto: 10.00 USD'), findsOneWidget);

    await tester.tap(find.text('Simular aprobado'));
    await tester.pumpAndSettle();

    expect(llamadas, hasLength(1));
    expect(llamadas.single.captureId, 'CAP-1');
    expect(find.text('¡Pago aprobado! Tu inscripción quedó confirmada.'),
        findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('pago cancelado: no registra nada', (tester) async {
    var llamadas = 0;
    await _mostrar(tester, (_, _, _) async => llamadas++);

    await tester.tap(find.text('Simular cancelado'));
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.text('Cancelaste el pago. No se cobró nada.'), findsOneWidget);
    expect(find.text('Pagar de nuevo'), findsOneWidget);
  });

  testWidgets('si falla al guardar, permite reintentar sin volver a pagar',
      (tester) async {
    var intentos = 0;
    await _mostrar(tester, (_, _, _) async {
      intentos++;
      if (intentos == 1) throw Exception('sin conexión');
    });

    await tester.tap(find.text('Simular aprobado'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no se pudo guardar'), findsOneWidget);
    expect(find.textContaining('CAP-1'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('¡Pago aprobado! Tu inscripción quedó confirmada.'),
        findsOneWidget);
  });

  testWidgets('muestra el motivo si la inscripción no se puede confirmar',
      (tester) async {
    await _mostrar(tester, (_, _, _) async {
      throw const InscripcionException('El plazo de pago ya venció.');
    });

    await tester.tap(find.text('Simular aprobado'));
    await tester.pumpAndSettle();

    expect(find.textContaining('El plazo de pago ya venció.'), findsOneWidget);
  });
}
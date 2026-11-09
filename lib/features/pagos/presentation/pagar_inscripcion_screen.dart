import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';
import 'package:saman_deportivo/features/pagos/presentation/vista_paypal.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

/// Registra un pago aprobado: crea el pago y confirma la inscripción.
typedef ConfirmarPago = Future<void> Function(
  Inscripcion inscripcion,
  ResultadoPaypal resultado,
  double monto,
);

/// Construye la vista de PayPal. En las pruebas se pasa una falsa.
typedef ConstructorVistaPaypal = Widget Function(
  Uri url,
  ValueChanged<ResultadoPaypal> onTerminar,
);

/// Pago de una inscripción pendiente con PayPal (RF-11).
/// Muestra pagar.html (botones del JS SDK) y, si PayPal aprueba, registra
/// el pago con [confirmar]. Devuelve `true` al cerrarse si quedó registrado.
class PagarInscripcionScreen extends StatefulWidget {
  const PagarInscripcionScreen({
    super.key,
    required this.inscripcion,
    required this.monto,
    required this.confirmar,
    this.construirVista,
  });

  final Inscripcion inscripcion;

  /// Costo del deporte. Es lo que se cobra y lo que validan las reglas.
  final double monto;
  final ConfirmarPago confirmar;
  final ConstructorVistaPaypal? construirVista;

  @override
  State<PagarInscripcionScreen> createState() => _PagarInscripcionScreenState();
}

class _PagarInscripcionScreenState extends State<PagarInscripcionScreen> {
  late final Uri _url = urlPagar(
    inscripcionId: widget.inscripcion.id,
    monto: widget.monto,
    deporte: widget.inscripcion.deporteNombre,
  );

  int _intento = 0;
  bool _mostrarPaypal = true;
  bool _guardando = false;
  bool _aprobado = false;
  bool _error = false;
  String? _mensaje;

  /// Pago que PayPal ya cobró pero que todavía no se pudo registrar.
  ResultadoPaypal? _sinRegistrar;

  void _mostrar(String mensaje, {required bool error}) {
    setState(() {
      _mostrarPaypal = false;
      _mensaje = mensaje;
      _error = error;
    });
  }

  void _alTerminar(ResultadoPaypal resultado) {
    if (!mounted) return;
    if (resultado.cancelado) {
      _mostrar('Cancelaste el pago. No se cobró nada.', error: false);
      return;
    }
    if (!resultado.completado) {
      _mostrar('PayPal no completó el pago. Puedes intentarlo de nuevo.',
          error: true);
      return;
    }
    final cobrado = resultado.monto;
    if (cobrado != null && (cobrado - widget.monto).abs() > 0.005) {
      _mostrar(
        'El monto cobrado no coincide con el costo del deporte. '
        'Comprobante: ${resultado.captureId}. Contacta a la administración.',
        error: true,
      );
      return;
    }
    _sinRegistrar = resultado;
    _registrar();
  }

  Future<void> _registrar() async {
    final resultado = _sinRegistrar;
    if (resultado == null) return;
    setState(() {
      _mostrarPaypal = false;
      _guardando = true;
      _mensaje = null;
    });
    try {
      await widget.confirmar(widget.inscripcion, resultado, widget.monto);
      if (!mounted) return;
      setState(() {
        _aprobado = true;
        _sinRegistrar = null;
        _mensaje = '¡Pago aprobado! Tu inscripción quedó confirmada.';
        _error = false;
      });
    } on InscripcionException catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = 'PayPal cobró el pago, pero no se pudo confirmar la '
            'inscripción: ${e.mensaje}\nComprobante: ${resultado.captureId}';
        _error = true;
      });
    } catch (e) {
      // El detalle va a la consola (F12) para poder diagnosticarlo.
      debugPrint('No se pudo registrar el pago: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'PayPal cobró el pago, pero no se pudo guardar. Revisa tu '
            'conexión y toca «Reintentar».\nComprobante: ${resultado.captureId}';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _pagarDeNuevo() => setState(() {
        _intento++;
        _mostrarPaypal = true;
        _mensaje = null;
        _error = false;
      });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ConstructorVistaPaypal construir = widget.construirVista ??
        ((url, onTerminar) => VistaPaypal(url: url, onTerminar: onTerminar));

    final encabezado = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.inscripcion.deporteNombre,
              style: tema.textTheme.headlineSmall),
          Text('Monto: ${widget.monto.toStringAsFixed(2)} USD'),
        ],
      ),
    );

    if (_mostrarPaypal) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagar inscripción')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            encabezado,
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_intento),
                child: construir(_url, _alTerminar),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar inscripción')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_guardando) const LinearProgressIndicator(),
          encabezado,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _guardando ? 'Registrando tu pago…' : (_mensaje ?? ''),
              style: TextStyle(color: _error ? tema.colorScheme.error : null),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_aprobado)
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Listo'),
                  )
                else if (_sinRegistrar != null)
                  FilledButton(
                    onPressed: _guardando ? null : _registrar,
                    child: const Text('Reintentar'),
                  )
                else ...[
                  FilledButton(
                    onPressed: _pagarDeNuevo,
                    child: const Text('Pagar de nuevo'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Volver'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/inscripcion.dart';
import '../data/paypal_gateway.dart';

/// Pago de una inscripción pendiente. Devuelve `true` al cerrarse si se aprobó.
class PagarInscripcionScreen extends StatefulWidget {
  const PagarInscripcionScreen({
    super.key,
    required this.inscripcion,
    this.monto,
    this.gateway,
    this.abrirUrl,
  });

  final Inscripcion inscripcion;

  /// Solo se muestra; el monto real lo decide el servidor.
  final double? monto;
  final PagoGateway? gateway;
  final Future<bool> Function(Uri)? abrirUrl;

  @override
  State<PagarInscripcionScreen> createState() => _PagarInscripcionScreenState();
}

class _PagarInscripcionScreenState extends State<PagarInscripcionScreen> {
  late final PagoGateway _gateway = widget.gateway ?? PaypalGateway();
  String? _pagoId;
  String? _mensaje;
  bool _error = false;
  bool _cargando = false;
  bool _confirmado = false;

  Future<void> _ejecutar(Future<String> Function() accion) async {
    setState(() {
      _cargando = true;
      _mensaje = null;
    });
    try {
      final texto = await accion();
      if (!mounted) return;
      setState(() {
        _mensaje = texto;
        _error = false;
      });
    } on PagoException catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = e.mensaje;
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _pagar() => _ejecutar(() async {
        final orden = await _gateway.crearOrden(widget.inscripcion.id);
        _pagoId = orden.pagoId;
        final Future<bool> Function(Uri) abrir = widget.abrirUrl ??
            (u) => launchUrl(u, mode: LaunchMode.externalApplication);
        if (!await abrir(Uri.parse(orden.urlAprobacion))) {
          throw const PagoException('No se pudo abrir PayPal.');
        }
        return 'Completa el pago en PayPal y vuelve aquí para tocar «Ya pagué».';
      });

  Future<void> _yaPague() => _ejecutar(() async {
        await _gateway.capturar(_pagoId!);
        _confirmado = true;
        return '¡Pago aprobado! Tu inscripción quedó confirmada.';
      });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar inscripción')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_cargando) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(widget.inscripcion.deporteNombre, style: tema.textTheme.headlineSmall),
            if (widget.monto != null)
              Text('Monto: ${widget.monto!.toStringAsFixed(2)} USD'),
            const SizedBox(height: 16),
            if (_mensaje != null)
              Text(_mensaje!,
                  style: TextStyle(color: _error ? tema.colorScheme.error : null)),
            const Spacer(),
            if (_confirmado)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Listo'),
              )
            else ...[
              FilledButton(
                onPressed: _cargando ? null : _pagar,
                child: Text(_pagoId == null ? 'Pagar con PayPal' : 'Pagar de nuevo'),
              ),
              if (_pagoId != null)
                FilledButton.tonal(
                  onPressed: _cargando ? null : _yaPague,
                  child: const Text('Ya pagué'),
                ),
              TextButton(
                onPressed: _cargando ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
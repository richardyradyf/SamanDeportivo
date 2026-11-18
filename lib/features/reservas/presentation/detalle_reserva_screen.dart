import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Detalle de una reserva propia.
///
/// Si se pasa [onCancelar] y la reserva todavía no empieza, muestra
/// «Cancelar reserva» con confirmación. Devuelve `true` al cerrarse si se
/// canceló.
class DetalleReservaScreen extends StatefulWidget {
  const DetalleReservaScreen({
    super.key,
    required this.reserva,
    required this.espacio,
    required this.reloj,
    this.tipoEspacio,
    this.onCancelar,
  });

  final ReservaEspacio reserva;

  /// Nombre del espacio.
  final String espacio;
  final String? tipoEspacio;
  final DateTime Function() reloj;
  final Future<void> Function(String reservaId)? onCancelar;

  @override
  State<DetalleReservaScreen> createState() => _DetalleReservaScreenState();
}

class _DetalleReservaScreenState extends State<DetalleReservaScreen> {
  bool _cancelando = false;
  String? _error;

  bool get _sePuedeCancelar =>
      widget.onCancelar != null &&
      widget.reserva.estaActiva &&
      widget.reserva.inicio.isAfter(widget.reloj());

  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: Text(
          'Se liberará ${widget.espacio} el '
          '${HoraCaracas.diaLargo(widget.reserva.inicio)} de '
          '${HoraCaracas.rango(widget.reserva.inicio, widget.reserva.fin)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() {
      _cancelando = true;
      _error = null;
    });
    try {
      await widget.onCancelar!(widget.reserva.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReservaEspacioException catch (e) {
      if (!mounted) return;
      setState(() {
        _cancelando = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cancelando = false;
        _error = 'No se pudo cancelar la reserva. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final reserva = widget.reserva;
    final ahora = widget.reloj();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la reserva')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.espacio,
                                style: tema.textTheme.titleLarge,
                              ),
                              if (widget.tipoEspacio != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.tipoEspacio!,
                                  style: tema.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        EtiquetaReserva.estado(reserva, ahora),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DatoReserva(
                      icono: Icons.event_outlined,
                      texto: HoraCaracas.diaLargo(reserva.inicio),
                    ),
                    DatoReserva(
                      icono: Icons.schedule_outlined,
                      texto: HoraCaracas.rango(reserva.inicio, reserva.fin),
                    ),
                    DatoReserva(
                      icono: Icons.notes_outlined,
                      texto: reserva.motivo.isEmpty
                          ? 'Sin motivo'
                          : reserva.motivo,
                    ),
                    DatoReserva(
                      icono: Icons.history,
                      texto: 'Creada el ${HoraCaracas.fecha(reserva.creadoEn)}',
                    ),
                    if (!reserva.estaActiva && reserva.actualizadoEn != null)
                      DatoReserva(
                        icono: Icons.cancel_outlined,
                        texto:
                            'Cancelada el '
                            '${HoraCaracas.fecha(reserva.actualizadoEn!)}',
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      RecuadroAviso(texto: _error!, error: true),
                    ],
                    if (_sePuedeCancelar) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        key: const Key('cancelarReserva'),
                        onPressed: _cancelando ? null : _cancelar,
                        icon: _cancelando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar reserva'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

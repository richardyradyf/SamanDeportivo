import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Separa las reservas en próximas (activas que no han terminado, de la más
/// cercana a la más lejana) y pasadas (terminadas o canceladas, de la más
/// reciente a la más antigua).
({List<ReservaEspacio> proximas, List<ReservaEspacio> pasadas}) separarReservas(
  List<ReservaEspacio> reservas,
  DateTime ahora,
) {
  final proximas = <ReservaEspacio>[];
  final pasadas = <ReservaEspacio>[];
  for (final reserva in reservas) {
    if (reserva.estaActiva && reserva.fin.isAfter(ahora)) {
      proximas.add(reserva);
    } else {
      pasadas.add(reserva);
    }
  }
  proximas.sort((a, b) => a.inicio.compareTo(b.inicio));
  pasadas.sort((a, b) => b.inicio.compareTo(a.inicio));
  return (proximas: proximas, pasadas: pasadas);
}

/// Pantalla D: reservas del usuario en sesión.
class MisReservasView extends StatefulWidget {
  const MisReservasView({
    super.key,
    required this.observar,
    required this.espacios,
    required this.reloj,
    required this.onAbrir,
    required this.onNuevaReserva,
  });

  /// Abre la consulta en tiempo real de las reservas del usuario; null si
  /// no hay sesión.
  final Stream<List<ReservaEspacio>> Function()? observar;
  final List<EspacioDeportivo> espacios;
  final DateTime Function() reloj;
  final ValueChanged<ReservaEspacio> onAbrir;
  final VoidCallback onNuevaReserva;

  @override
  State<MisReservasView> createState() => _MisReservasViewState();
}

class _MisReservasViewState extends State<MisReservasView> {
  Stream<List<ReservaEspacio>>? _reservas;

  @override
  void initState() {
    super.initState();
    _reservas = widget.observar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _reservas;
    if (stream == null) {
      return const AvisoReservas(
        icono: Icons.lock_outline,
        titulo: 'Inicia sesión para ver tus reservas',
      );
    }
    return StreamBuilder<List<ReservaEspacio>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return AvisoReservas(
            icono: Icons.error_outline,
            titulo: 'No pudimos cargar tus reservas',
            mensaje: error is ReservaEspacioException
                ? error.mensaje
                : 'Revisa tu conexión e inténtalo de nuevo.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final ahora = widget.reloj();
        final (:proximas, :pasadas) = separarReservas(snapshot.data!, ahora);
        if (proximas.isEmpty && pasadas.isEmpty) {
          return AvisoReservas(
            icono: Icons.event_available_outlined,
            titulo: 'Todavía no tienes reservas',
            mensaje: 'Reserva una cancha o el gimnasio y aparecerá aquí.',
            accion: FilledButton(
              onPressed: widget.onNuevaReserva,
              child: const Text('Nueva reserva'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Seccion(
                      titulo: 'Próximas',
                      vacio: 'No tienes reservas próximas.',
                      reservas: proximas,
                      espacios: widget.espacios,
                      ahora: ahora,
                      onAbrir: widget.onAbrir,
                    ),
                    const SizedBox(height: 24),
                    _Seccion(
                      titulo: 'Pasadas',
                      vacio: 'Aún no tienes reservas pasadas.',
                      reservas: pasadas,
                      espacios: widget.espacios,
                      ahora: ahora,
                      onAbrir: widget.onAbrir,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Nombre del espacio de una reserva, aunque ya no esté en el catálogo.
String nombreEspacio(List<EspacioDeportivo> espacios, String espacioId) {
  for (final espacio in espacios) {
    if (espacio.id == espacioId) return espacio.nombre;
  }
  return 'Espacio no disponible';
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.vacio,
    required this.reservas,
    required this.espacios,
    required this.ahora,
    required this.onAbrir,
  });

  final String titulo;
  final String vacio;
  final List<ReservaEspacio> reservas;
  final List<EspacioDeportivo> espacios;
  final DateTime ahora;
  final ValueChanged<ReservaEspacio> onAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${titulo.toUpperCase()} (${reservas.length})',
          style: tema.textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        if (reservas.isEmpty)
          Text(vacio, style: tema.textTheme.bodySmall)
        else
          for (final reserva in reservas)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TarjetaReserva(
                reserva: reserva,
                espacio: nombreEspacio(espacios, reserva.espacioId),
                ahora: ahora,
                onTap: () => onAbrir(reserva),
              ),
            ),
      ],
    );
  }
}

class _TarjetaReserva extends StatelessWidget {
  const _TarjetaReserva({
    required this.reserva,
    required this.espacio,
    required this.ahora,
    required this.onTap,
  });

  final ReservaEspacio reserva;
  final String espacio;
  final DateTime ahora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(espacio, style: tema.textTheme.titleMedium),
                  ),
                  const SizedBox(width: 12),
                  EtiquetaReserva.estado(reserva, ahora),
                ],
              ),
              const SizedBox(height: 10),
              DatoReserva(
                icono: Icons.event_outlined,
                texto: HoraCaracas.diaLargo(reserva.inicio),
              ),
              Row(
                children: [
                  Expanded(
                    child: DatoReserva(
                      icono: Icons.schedule_outlined,
                      texto: HoraCaracas.rango(reserva.inicio, reserva.fin),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

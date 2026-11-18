import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/franjas_disponibilidad.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Pantalla A: las instalaciones activas con su disponibilidad de hoy.
class ExplorarEspaciosView extends StatelessWidget {
  const ExplorarEspaciosView({
    super.key,
    required this.espacios,
    required this.deportes,
    required this.disponibilidad,
    required this.reloj,
    required this.onVerDisponibilidad,
    required this.onReservar,
  });

  final List<EspacioDeportivo> espacios;
  final List<Deporte> deportes;
  final DisponibilidadRepository disponibilidad;
  final DateTime Function() reloj;
  final ValueChanged<EspacioDeportivo> onVerDisponibilidad;
  final ValueChanged<EspacioDeportivo> onReservar;

  @override
  Widget build(BuildContext context) {
    if (espacios.isEmpty) {
      return const AvisoReservas(
        icono: Icons.stadium_outlined,
        titulo: 'Todavía no hay espacios disponibles',
        mensaje: 'Cuando la administración registre instalaciones, '
            'aparecerán aquí.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 16.0;
        final columnas = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final ancho =
            (constraints.maxWidth - 32 - separacion * (columnas - 1)) /
            columnas;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Wrap(
            spacing: separacion,
            runSpacing: separacion,
            children: [
              for (final espacio in espacios)
                SizedBox(
                  width: ancho,
                  child: TarjetaEspacio(
                    key: ValueKey(espacio.id),
                    espacio: espacio,
                    deportes: deportes,
                    disponibilidad: disponibilidad,
                    reloj: reloj,
                    onVerDisponibilidad: () => onVerDisponibilidad(espacio),
                    onReservar: () => onReservar(espacio),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de un espacio: nombre, tipo y si está libre ahora.
class TarjetaEspacio extends StatefulWidget {
  const TarjetaEspacio({
    super.key,
    required this.espacio,
    required this.deportes,
    required this.disponibilidad,
    required this.reloj,
    required this.onVerDisponibilidad,
    required this.onReservar,
  });

  final EspacioDeportivo espacio;
  final List<Deporte> deportes;
  final DisponibilidadRepository disponibilidad;
  final DateTime Function() reloj;
  final VoidCallback onVerDisponibilidad;
  final VoidCallback onReservar;

  @override
  State<TarjetaEspacio> createState() => _TarjetaEspacioState();
}

class _TarjetaEspacioState extends State<TarjetaEspacio> {
  late DateTime _desde;
  late DateTime _hasta;
  Stream<List<OcupacionEspacio>>? _ocupaciones;

  @override
  void initState() {
    super.initState();
    final hoy = HoraCaracas.diaDe(widget.reloj());
    _desde = HoraCaracas.instante(hoy, 0);
    _hasta = _desde.add(const Duration(days: 1));
    try {
      _ocupaciones = widget.disponibilidad.observarOcupaciones(
        espacioId: widget.espacio.id,
        desde: _desde,
        hasta: _hasta,
      );
    } catch (_) {
      _ocupaciones = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final espacio = widget.espacio;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.suave,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stadium_outlined, color: AppColors.primario),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(espacio.nombre, style: tema.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(espacio.tipo, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (espacio.descripcion.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                espacio.descripcion,
                style: tema.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            _disponibilidadHoy(context),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: widget.onVerDisponibilidad,
                  child: const Text('Ver disponibilidad'),
                ),
                FilledButton(
                  onPressed: widget.onReservar,
                  child: const Text('Reservar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _disponibilidadHoy(BuildContext context) {
    final stream = _ocupaciones;
    if (stream == null) {
      return Text(
        'Disponibilidad no disponible por ahora.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return StreamBuilder<List<OcupacionEspacio>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'No pudimos consultar la disponibilidad.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bloques = ValidacionesReserva.consultarOcupaciones(
          espacio: widget.espacio,
          desde: _desde,
          hasta: _hasta,
          deportes: widget.deportes,
          ocupaciones: snapshot.data!,
        );
        final resumen = ResumenEspacioHoy.de(bloques, widget.reloj());
        final ocupado = resumen.ocupadoHasta;
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtiquetaReserva(
              texto: ocupado == null
                  ? 'Disponible ahora'
                  : 'Ocupado hasta las ${HoraCaracas.hora(ocupado)}',
              fondo: ocupado == null
                  ? AppColors.disponibleFondo
                  : AppColors.pocosCuposFondo,
              color: ocupado == null
                  ? AppColors.disponibleTexto
                  : AppColors.pocosCuposTexto,
            ),
            Text(
              resumen.ocupadasHoy == 0
                  ? 'Sin ocupación el resto del día'
                  : resumen.ocupadasHoy == 1
                  ? '1 bloque ocupado hoy'
                  : '${resumen.ocupadasHoy} bloques ocupados hoy',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

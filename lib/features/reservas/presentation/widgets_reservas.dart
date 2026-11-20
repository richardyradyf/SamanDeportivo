import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/features/reservas/presentation/franjas_disponibilidad.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Etiqueta redondeada de color, igual a la de cupos del catálogo.
class EtiquetaReserva extends StatelessWidget {
  const EtiquetaReserva({
    super.key,
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;

  /// Colores de una franja de la vista de disponibilidad.
  factory EtiquetaReserva.franja(EstadoFranja estado, {Key? key}) {
    final (fondo, color, icono) = switch (estado) {
      EstadoFranja.disponible => (
        AppColors.disponibleFondo,
        AppColors.disponibleTexto,
        Icons.check_circle_outline,
      ),
      EstadoFranja.clase => (
        AppColors.info.withValues(alpha: 0.12),
        AppColors.info,
        Icons.sports_outlined,
      ),
      EstadoFranja.reserva => (
        AppColors.pocosCuposFondo,
        AppColors.pocosCuposTexto,
        Icons.event_busy_outlined,
      ),
      EstadoFranja.pasada => (
        AppColors.borde,
        AppColors.textoSecundario,
        Icons.history,
      ),
    };
    return EtiquetaReserva(
      key: key,
      texto: estado.etiqueta,
      fondo: fondo,
      color: color,
      icono: icono,
    );
  }

  /// Estado de una reserva en "Mis reservas".
  factory EtiquetaReserva.estado(
    ReservaEspacio reserva,
    DateTime ahora, {
    Key? key,
  }) {
    if (!reserva.estaActiva) {
      return EtiquetaReserva(
        key: key,
        texto: 'Cancelada',
        fondo: AppColors.completoFondo,
        color: AppColors.completoTexto,
      );
    }
    if (!reserva.fin.isAfter(ahora)) {
      return EtiquetaReserva(
        key: key,
        texto: 'Finalizada',
        fondo: AppColors.borde,
        color: AppColors.textoSecundario,
      );
    }
    if (!reserva.inicio.isAfter(ahora)) {
      return EtiquetaReserva(
        key: key,
        texto: 'En curso',
        fondo: AppColors.info.withValues(alpha: 0.12),
        color: AppColors.info,
      );
    }
    return EtiquetaReserva(
      key: key,
      texto: 'Activa',
      fondo: AppColors.disponibleFondo,
      color: AppColors.disponibleTexto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(texto, style: estilo, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Línea de dato con icono, como en las tarjetas de inscripciones.
class DatoReserva extends StatelessWidget {
  const DatoReserva({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppColors.textoSecundario),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje centrado para estados vacíos y errores.
class AvisoReservas extends StatelessWidget {
  const AvisoReservas({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 4),
              Text(
                mensaje!,
                style: tema.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

/// Recuadro de aviso (límites del estudiante o error de una reserva).
class RecuadroAviso extends StatelessWidget {
  const RecuadroAviso({
    super.key,
    required this.texto,
    this.error = false,
  });

  final String texto;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.peligro : AppColors.info;
    final fondo = error ? AppColors.completoFondo : AppColors.info.withValues(alpha: 0.08);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: error ? AppColors.peligro : AppColors.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

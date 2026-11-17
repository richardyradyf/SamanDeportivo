import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

class MisInscripcionesScreen extends StatelessWidget {
  const MisInscripcionesScreen({
    super.key,
    this.inscripciones = const [],
    this.inscripcionesStream,
    this.onCancelar,
    this.onCancelarInscripcion,
  });

  /// Lista de inscripciones utilizada cuando no se recibe un Stream.
  final List<Inscripcion> inscripciones;

  /// Flujo de inscripciones del estudiante autenticado.
  final Stream<List<Inscripcion>>? inscripcionesStream;

  /// Acción para solicitar una cancelación.
  final ValueChanged<Inscripcion>? onCancelar;

  /// Nombre alternativo utilizado por InicioEstudianteScreen.
  final ValueChanged<Inscripcion>? onCancelarInscripcion;

  /// Ancho máximo de la lista en escritorio, para que las tarjetas no se
  /// estiren de lado a lado de la pantalla.
  static const double anchoMaximo = 720;

  /// Fondo y texto de la etiqueta de estado, con los colores del tema.
  static (Color, Color) coloresEstado(EstadoInscripcion estado) {
    return switch (estado) {
      EstadoInscripcion.pendiente => (
        AppColors.pocosCuposFondo,
        AppColors.pocosCuposTexto,
      ),
      EstadoInscripcion.confirmada => (
        AppColors.disponibleFondo,
        AppColors.disponibleTexto,
      ),
      EstadoInscripcion.rechazada ||
      EstadoInscripcion.cancelada => (
        AppColors.completoFondo,
        AppColors.completoTexto,
      ),
      EstadoInscripcion.expirada => (AppColors.borde, AppColors.textoSecundario),
    };
  }

  Color obtenerColor(EstadoInscripcion estado) => coloresEstado(estado).$2;

  String formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mis inscripciones', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Consulta el estado de tus inscripciones deportivas.',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: inscripcionesStream == null
                    ? _construirContenido(context, inscripciones)
                    : StreamBuilder<List<Inscripcion>>(
                        stream: inscripcionesStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'No se pudieron cargar tus inscripciones.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return _construirContenido(context, snapshot.data!);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirContenido(BuildContext context, List<Inscripcion> datos) {
    if (datos.isEmpty) {
      return _construirEstadoVacio(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: datos.length,
      itemBuilder: (context, index) {
        return _construirTarjeta(context, datos[index]);
      },
    );
  }

  Widget _construirEstadoVacio(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: tema.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes inscripciones registradas',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando te inscribas en una disciplina, '
              'podrás consultar su estado aquí.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjeta(BuildContext context, Inscripcion inscripcion) {
    final tema = Theme.of(context);
    final cancelar = onCancelarInscripcion ?? onCancelar;
    final puedeCancelar = inscripcion.ocupaCupo && cancelar != null;
    final (fondoEstado, textoEstado) = coloresEstado(inscripcion.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre a la izquierda y estado a la derecha; en pantallas
            // angostas el nombre se parte en dos líneas y el estado no se sale.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    inscripcion.deporteNombre,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fondoEstado,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    inscripcion.estado.etiqueta,
                    style: tema.textTheme.labelMedium?.copyWith(
                      color: textoEstado,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Dato(icono: Icons.tag, texto: 'Código: ${inscripcion.deporteId}'),
            _Dato(
              icono: Icons.event_outlined,
              texto:
                  'Fecha de inscripción: '
                  '${formatearFecha(inscripcion.fechaInscripcion)}',
            ),
            if (inscripcion.estado == EstadoInscripcion.pendiente)
              _Dato(
                icono: Icons.schedule_outlined,
                texto:
                    'Fecha límite de pago: '
                    '${formatearFecha(inscripcion.fechaLimitePago)}',
                color: AppColors.pocosCuposTexto,
              ),
            if (inscripcion.motivo != null && inscripcion.motivo!.isNotEmpty)
              _Dato(
                icono: Icons.info_outline,
                texto: 'Motivo: ${inscripcion.motivo}',
              ),
            if (inscripcion.ocupaCupo) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: puedeCancelar ? () => cancelar(inscripcion) : null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar inscripción'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una línea de la tarjeta: icono pequeño y texto.
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.color});

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colorTexto = color ?? AppColors.textoSecundario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: colorTexto),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodyMedium?.copyWith(color: colorTexto),
            ),
          ),
        ],
      ),
    );
  }
}

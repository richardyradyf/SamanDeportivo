import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';

import 'fuentes_dashboard.dart';
import 'widgets_dashboard.dart';

/// Pantalla principal del administrador: datos reales, sin métricas simuladas.
class DashboardAdminScreen extends StatelessWidget {
  const DashboardAdminScreen({
    super.key,
    required this.nombre,
    this.repositorio,
  });

  final String nombre;
  final DashboardRepository? repositorio;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PanelBienvenida.componer('Hola', nombre),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Resumen de la actividad deportiva',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FuentesDashboard(
                repositorio: repositorio,
                construir: (context, resumen) =>
                    _ContenidoDashboard(resumen: resumen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContenidoDashboard extends StatelessWidget {
  const _ContenidoDashboard({required this.resumen});

  final ResumenDashboard resumen;

  @override
  Widget build(BuildContext context) {
    final deportes = resumen.ocupacionDeportes.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CuadriculaIndicadores(
          indicadores: [
            TarjetaIndicador(
              id: 'deportes',
              etiqueta: 'Deportes activos',
              valor: '${resumen.deportesActivos}',
              icono: Icons.sports_soccer_outlined,
              aclaracion: '${resumen.deportesTotales} registrados en total',
            ),
            TarjetaIndicador(
              id: 'entrenadores',
              etiqueta: 'Entrenadores registrados',
              valor: '${resumen.entrenadores}',
              icono: Icons.badge_outlined,
            ),
            TarjetaIndicador(
              id: 'estudiantes',
              etiqueta: 'Estudiantes registrados',
              valor: '${resumen.estudiantes}',
              icono: Icons.school_outlined,
              aclaracion: '${resumen.estudiantesActivos} activos',
            ),
            TarjetaIndicador(
              id: 'disponibles',
              etiqueta: 'Cupos disponibles',
              valor: '${resumen.cuposDisponibles}',
              icono: Icons.event_available_outlined,
              aclaracion: 'Solo deportes activos',
            ),
            TarjetaIndicador(
              id: 'ocupacion',
              etiqueta: 'Ocupación de cupos',
              valor: '${resumen.porcentajeOcupacion.toStringAsFixed(1)}%',
              icono: Icons.pie_chart_outline,
              aclaracion:
                  '${resumen.cuposOcupados} de ${resumen.cuposTotales} cupos',
            ),
            TarjetaIndicador(
              id: 'confirmados',
              etiqueta: 'Cupos confirmados',
              valor: '${resumen.cuposConfirmados}',
              icono: Icons.verified_outlined,
              aclaracion: 'No incluye reservas pendientes',
            ),
          ],
        ),
        const SizedBox(height: 22),
        PanelAnalitico(
          titulo: 'Ocupación por deporte',
          child: deportes.isEmpty
              ? const Text('Aún no hay deportes activos.')
              : Column(
                  children: [
                    for (final deporte in deportes) ...[
                      Row(
                        children: [
                          Expanded(child: Text(deporte.nombre)),
                          Text('${deporte.ocupados}/${deporte.capacidad}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: deporte.porcentaje / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => LayoutResponsivo.irA(context, 1),
              icon: const Icon(Icons.sports_soccer_outlined),
              label: const Text('Gestionar deportes'),
            ),
            FilledButton.icon(
              onPressed: () => LayoutResponsivo.irA(context, 5),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Ver analítica'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Los cupos ocupados incluyen pendientes y confirmados. '
          'La cifra no equivale a ingresos ni a pagos aprobados.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

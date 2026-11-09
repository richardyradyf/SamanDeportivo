import 'package:saman_deportivo/features/admin/dashboard/presentation/panel_asistencia_admin.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/panel_indicadores_operativos.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';

import 'fuentes_dashboard.dart';
import 'widgets_dashboard.dart';

/// A3.1: análisis descriptivo de catálogo, ocupación y disciplinas.
/// Las búsquedas, inscripciones y pagos requieren los módulos que los
/// registran. Nunca calculamos una métrica sustituta engañosa.
class AnaliticaAdminScreen extends StatelessWidget {
  const AnaliticaAdminScreen({super.key, this.repositorio});

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
                'Analítica',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Indicadores operativos calculados con los datos actuales.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FuentesDashboard(
                repositorio: repositorio,
                construir: (context, resumen) =>
                    _ContenidoAnalitica(resumen: resumen),
              ),
              const SizedBox(height: 16),
              const PanelAsistenciaAdmin(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContenidoAnalitica extends StatelessWidget {
  const _ContenidoAnalitica({required this.resumen});

  final ResumenDashboard resumen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CuadriculaIndicadores(
          indicadores: [
            TarjetaIndicador(
              id: 'sin-entrenador',
              etiqueta: 'Deportes activos sin entrenador',
              valor: '${resumen.deportesSinEntrenador}',
              icono: Icons.person_off_outlined,
            ),
            TarjetaIndicador(
              id: 'completos',
              etiqueta: 'Deportes sin cupos',
              valor: '${resumen.deportesCompletos}',
              icono: Icons.event_busy_outlined,
            ),
            TarjetaIndicador(
              id: 'ocupados',
              etiqueta: 'Reservas que ocupan cupo',
              valor: '${resumen.cuposOcupados}',
              icono: Icons.confirmation_num_outlined,
              aclaracion: 'Incluye reservas pendientes',
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, dimensiones) {
            final ancho = dimensiones.maxWidth < 860
                ? dimensiones.maxWidth
                : (dimensiones.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: ancho,
                  child: PanelAnalitico(
                    titulo: 'Ocupación de los deportes activos',
                    child: OcupacionPorDeporte(resumen: resumen),
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: PanelAnalitico(
                    titulo: 'Deportes activos por disciplina',
                    child: DistribucionDisciplinas(resumen: resumen),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const PanelIndicadoresOperativos(),
      ],
    );
  }
}

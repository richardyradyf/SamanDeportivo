import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/widgets_dashboard.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_entrenador.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/proxima_sesion.dart';

/// Dashboard del entrenador: saludo, próxima sesión, sus números y
/// accesos rápidos. Recibe el resumen ya calculado para poder probarla
/// sin Firebase.
class DashboardEntrenadorScreen extends StatefulWidget {
  const DashboardEntrenadorScreen({
    super.key,
    required this.nombre,
    required this.resumen,
    this.ahora,
  });

  final String nombre;
  final Stream<ResumenEntrenador> resumen;

  /// Para las pruebas; si es null se usa la hora actual.
  final DateTime? ahora;

  /// Posición de cada sección en el menú del entrenador.
  static const indiceEstudiantes = 2;
  static const indiceAsistencia = 3;

  @override
  State<DashboardEntrenadorScreen> createState() =>
      _DashboardEntrenadorScreenState();
}

class _DashboardEntrenadorScreenState extends State<DashboardEntrenadorScreen> {
  late final Stream<ResumenEntrenador> _resumen = widget.resumen;

  @override
  Widget build(BuildContext context) {
    return PanelBienvenida(
      saludo: PanelBienvenida.componer('Hola', widget.nombre),
      contenido: StreamBuilder<ResumenEntrenador>(
        stream: _resumen,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('No se pudo cargar tu resumen.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TarjetaProximaSesion(
                proxima: r.proxima,
                ahora: widget.ahora ?? DateTime.now(),
              ),
              const SizedBox(height: 16),
              CuadriculaIndicadores(
                indicadores: [
                  TarjetaIndicador(
                    id: 'ent-disciplinas',
                    etiqueta: 'Disciplinas activas',
                    valor: '${r.disciplinas}',
                    icono: Icons.sports,
                  ),
                  TarjetaIndicador(
                    id: 'ent-confirmados',
                    etiqueta: 'Estudiantes confirmados',
                    valor: '${r.inscritosConfirmados}',
                    icono: Icons.groups,
                  ),
                  TarjetaIndicador(
                    id: 'ent-sesiones',
                    etiqueta: 'Sesiones por semana',
                    valor: '${r.sesionesPorSemana}',
                    icono: Icons.event_repeat,
                  ),
                  TarjetaIndicador(
                    id: 'ent-asistencia',
                    etiqueta: 'Asistencia',
                    valor: '${r.porcentajeAsistencia} %',
                    icono: Icons.fact_check,
                    aclaracion: 'Últimos 3 meses',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => LayoutResponsivo.irA(
                      context,
                      DashboardEntrenadorScreen.indiceAsistencia,
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Tomar asistencia'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => LayoutResponsivo.irA(
                      context,
                      DashboardEntrenadorScreen.indiceEstudiantes,
                    ),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Estudiantes'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta "Próxima sesión": deporte, cuándo, horario y lugar.
class TarjetaProximaSesion extends StatelessWidget {
  const TarjetaProximaSesion({
    super.key,
    required this.proxima,
    required this.ahora,
  });

  final ProximaSesion? proxima;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final sesion = proxima;
    return Card(
      color: AppColors.suave,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.event, size: 36, color: AppColors.primario),
            const SizedBox(width: 16),
            Expanded(
              child: sesion == null
                  ? const Text('No tienes sesiones programadas.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Próxima sesión', style: texto.labelLarge),
                        Text(sesion.deporte.nombre, style: texto.titleLarge),
                        Text(cuandoEs(sesion.inicio, ahora)),
                        Text(
                          '${sesion.horario.horaInicio} - '
                          '${sesion.horario.horaFin} · ${sesion.horario.lugar}',
                          style: texto.bodySmall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

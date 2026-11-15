import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/estrellas.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// "Mis disciplinas" del entrenador: sus deportes activos con horarios,
/// cupos y calificación. Recibe el stream para poder probarla sin Firebase.
class MisDisciplinasScreen extends StatefulWidget {
  const MisDisciplinasScreen({super.key, required this.deportes, this.onAbrir});

  final Stream<List<Deporte>> deportes;

  /// Al tocar una tarjeta (abre el detalle con las reseñas).
  final ValueChanged<Deporte>? onAbrir;

  @override
  State<MisDisciplinasScreen> createState() => _MisDisciplinasScreenState();
}

class _MisDisciplinasScreenState extends State<MisDisciplinasScreen> {
  // Se guarda una sola vez: si el padre se redibuja, no se vuelve a
  // suscribir a Firestore.
  late final Stream<List<Deporte>> _deportes = widget.deportes;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Deporte>>(
      stream: _deportes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar tus disciplinas.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final activos = snapshot.data!.where((d) => d.activo).toList();
        if (activos.isEmpty) {
          return const Center(
            child: Text('Todavía no tienes disciplinas asignadas.'),
          );
        }
        return LayoutBuilder(
          builder: (context, restricciones) {
            const espacio = 16.0;
            final ancho = restricciones.maxWidth;
            final columnas = ancho >= LayoutResponsivo.anchoEscritorio
                ? 3
                : ancho >= LayoutResponsivo.anchoTablet
                ? 2
                : 1;
            final anchoTarjeta = (ancho - espacio * (columnas + 1)) / columnas;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(espacio),
              child: Wrap(
                spacing: espacio,
                runSpacing: espacio,
                children: [
                  for (final deporte in activos)
                    SizedBox(
                      width: anchoTarjeta,
                      child: TarjetaDisciplina(
                        deporte: deporte,
                        onTap: widget.onAbrir == null
                            ? null
                            : () => widget.onAbrir!(deporte),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Tarjeta de un deporte: nombre, código, calificación, horarios y cupos.
class TarjetaDisciplina extends StatelessWidget {
  const TarjetaDisciplina({super.key, required this.deporte, this.onTap});

  final Deporte deporte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final ocupacion = deporte.cupoMaximo == 0
        ? 0.0
        : deporte.cuposOcupados / deporte.cupoMaximo;
    final casiLleno = ocupacion >= 0.8;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deporte.nombre, style: texto.titleMedium),
              Text(
                '${deporte.codigo} · ${deporte.disciplina.etiqueta}',
                style: texto.bodySmall?.copyWith(
                  color: AppColors.textoSecundario,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Estrellas(valor: deporte.promedioCalificacion),
                  const SizedBox(width: 6),
                  Text('(${deporte.totalResenas})', style: texto.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              if (deporte.horarios.isEmpty)
                const Text('Sin horarios asignados'),
              for (final horario in deporte.horarios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.textoSecundario,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${horario.resumen} · ${horario.lugar}'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Cupos: ${deporte.cuposOcupados} de ${deporte.cupoMaximo} '
                '(${deporte.cuposConfirmados} confirmados)',
                style: texto.bodySmall,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: ocupacion.clamp(0.0, 1.0),
                color: casiLleno ? AppColors.advertencia : AppColors.primario,
                backgroundColor: AppColors.suave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

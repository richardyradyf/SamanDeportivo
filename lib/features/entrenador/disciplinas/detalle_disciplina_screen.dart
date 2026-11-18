import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/estrellas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Detalle de una disciplina del entrenador: datos, horarios, cupos,
/// calificación y los comentarios visibles de los estudiantes.
class DetalleDisciplinaScreen extends StatefulWidget {
  const DetalleDisciplinaScreen({
    super.key,
    required this.deporte,
    required this.resenas,
  });

  final Deporte deporte;

  /// Reseñas visibles del deporte (sin las ocultas por el administrador).
  final Stream<List<Resena>> resenas;

  @override
  State<DetalleDisciplinaScreen> createState() =>
      _DetalleDisciplinaScreenState();
}

class _DetalleDisciplinaScreenState extends State<DetalleDisciplinaScreen> {
  late final Stream<List<Resena>> _resenas = widget.resenas;

  @override
  Widget build(BuildContext context) {
    final deporte = widget.deporte;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(deporte.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${deporte.codigo} · ${deporte.disciplina.etiqueta}',
                  style: texto.bodyMedium?.copyWith(
                    color: AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 8),
                Text(deporte.descripcion),
                const SizedBox(height: 24),
                Text('Horarios', style: texto.titleMedium),
                const SizedBox(height: 8),
                if (deporte.horarios.isEmpty)
                  const Text('Sin horarios asignados'),
                for (final horario in deporte.horarios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(horario.resumen),
                    subtitle: Text(horario.lugar),
                  ),
                const SizedBox(height: 16),
                Text('Cupos', style: texto.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${deporte.cuposConfirmados} confirmados · '
                  '${deporte.cuposDisponibles} disponibles de '
                  '${deporte.cupoMaximo}',
                ),
                const SizedBox(height: 24),
                Text('Calificación', style: texto.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Estrellas(valor: deporte.promedioCalificacion, tamano: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${deporte.promedioCalificacion.toStringAsFixed(1)} '
                      '(${deporte.totalResenas} reseñas)',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Comentarios', style: texto.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<List<Resena>>(
                  stream: _resenas,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('No se pudieron cargar las reseñas.');
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final visibles =
                        snapshot.data!.where((r) => !r.oculta).toList()
                          ..sort((a, b) => b.fecha.compareTo(a.fecha));
                    if (visibles.isEmpty) {
                      return const Text('Todavía no hay reseñas.');
                    }
                    return Column(
                      children: [
                        for (final resena in visibles)
                          TarjetaResena(resena: resena),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un comentario: quién, cuántas estrellas, cuándo y qué dijo.
class TarjetaResena extends StatelessWidget {
  const TarjetaResena({super.key, required this.resena});

  final Resena resena;

  static String fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/'
      '${f.month.toString().padLeft(2, '0')}/${f.year}';

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(resena.estudianteNombre, style: texto.titleSmall),
                ),
                Text(fecha(resena.fecha), style: texto.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Estrellas(valor: resena.puntuacion.toDouble()),
            if (resena.comentario.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(resena.comentario),
            ],
          ],
        ),
      ),
    );
  }
}

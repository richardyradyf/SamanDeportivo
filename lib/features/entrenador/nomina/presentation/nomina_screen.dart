import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/entrenador/widgets/con_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

/// Nómina del entrenador (RF-13): inscritos confirmados de uno de sus deportes.
class NominaScreen extends StatelessWidget {
  const NominaScreen({
    super.key,
    required this.deportes,
    required this.confirmadas,
  });

  final Stream<List<Deporte>> deportes;
  final ConfirmadasDeDeporte confirmadas;

  @override
  Widget build(BuildContext context) {
    return ConDeporte(
      deportes: deportes,
      builder: (context, deporte) => StreamBuilder<List<Inscripcion>>(
        stream: confirmadas(deporte.codigo),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar la nómina.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = [...snapshot.data!]
            ..sort((a, b) => a.estudianteNombre.compareTo(b.estudianteNombre));
          if (lista.isEmpty) {
            return const Center(child: Text('Todavía no hay inscritos confirmados.'));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text(
                '${lista.length} inscritos confirmados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final i in lista)
                Card(
                  child: ListTile(
                    title: Text(i.estudianteNombre),
                    subtitle: Text(
                      'Cédula ${i.estudianteCedula} · Carnet ${i.estudianteCarnet}\n'
                      '${i.estudianteCorreo}',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
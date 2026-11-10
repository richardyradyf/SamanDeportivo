import 'package:flutter/material.dart';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

/// Inscripciones confirmadas de un deporte (nómina y asistencia).
typedef ConfirmadasDeDeporte = Stream<List<Inscripcion>> Function(
  String codigoDeporte,
);

/// Selector con los deportes del entrenador; construye el contenido del elegido.
class ConDeporte extends StatefulWidget {
  const ConDeporte({super.key, required this.deportes, required this.builder});

  final Stream<List<Deporte>> deportes;
  final Widget Function(BuildContext context, Deporte deporte) builder;

  @override
  State<ConDeporte> createState() => _ConDeporteState();
}

class _ConDeporteState extends State<ConDeporte> {
  late final Stream<List<Deporte>> _deportes = widget.deportes;
  String? _codigo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Deporte>>(
      stream: _deportes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudieron cargar tus deportes.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snapshot.data!;
        if (lista.isEmpty) {
          return const Center(child: Text('Todavía no tienes deportes asignados.'));
        }
        final actual = lista.firstWhere(
          (d) => d.codigo == _codigo,
          orElse: () => lista.first,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButton<String>(
                isExpanded: true,
                value: actual.codigo,
                items: [
                  for (final d in lista)
                    DropdownMenuItem(
                      value: d.codigo,
                      child: Text('${d.nombre} (${d.codigo})'),
                    ),
                ],
                onChanged: (c) => setState(() => _codigo = c),
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(actual.codigo),
                child: widget.builder(context, actual),
              ),
            ),
          ],
        );
      },
    );
  }
}
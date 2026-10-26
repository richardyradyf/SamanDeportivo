import 'package:flutter/material.dart';

/// Aviso del inicio del estudiante cuando todavía no está inscrito en
/// ninguna disciplina (pantalla "Inicio · sin inscripciones" del Figma).
class SinInscripcionesCard extends StatelessWidget {
  const SinInscripcionesCard({super.key, required this.onExplorar});

  /// Qué hacer al pulsar "Explorar deportes".
  final VoidCallback onExplorar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Todavía no estás inscrito en ninguna disciplina.',
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Explora los deportes disponibles y encuentra uno que se ajuste '
              'a tu horario.',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onExplorar,
              child: const Text('Explorar deportes'),
            ),
          ],
        ),
      ),
    );
  }
}

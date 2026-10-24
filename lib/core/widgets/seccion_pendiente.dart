import 'package:flutter/material.dart';

class SeccionPendiente extends StatelessWidget {
  const SeccionPendiente({
    super.key,
    required this.titulo,
    required this.icono,
  });

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(titulo, style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Esta sección estará disponible próximamente.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

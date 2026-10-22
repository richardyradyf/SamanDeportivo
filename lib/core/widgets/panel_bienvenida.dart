import 'package:flutter/material.dart';

import 'package:saman_deportivo/models/enums.dart';

/// Primera pestaña de cada pantalla de inicio: saluda a la persona por su
/// nombre y le recuerda con qué rol entró.
class PanelBienvenida extends StatelessWidget {
  const PanelBienvenida({
    super.key,
    required this.nombre,
    required this.rol,
    required this.mensaje,
  });

  final String nombre;
  final Rol rol;

  /// Texto corto con lo que esa persona puede hacer en la app.
  final String mensaje;

  /// "Ana María Pérez" -> "Ana". Si no hay nombre, solo "¡Hola!".
  String get saludo {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    final primerNombre = partes.first;
    return primerNombre.isEmpty ? '¡Hola!' : '¡Hola, $primerNombre!';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports, size: 72, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                saludo,
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Chip(label: Text(rol.etiqueta)),
              const SizedBox(height: 16),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

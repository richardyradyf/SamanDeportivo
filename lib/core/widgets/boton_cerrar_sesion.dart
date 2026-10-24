import 'package:flutter/material.dart';

/// Botón de la barra superior que pide confirmación antes de cerrar sesión,
/// para que un toque accidental no saque a la persona de la app.
class BotonCerrarSesion extends StatelessWidget {
  const BotonCerrarSesion({super.key, required this.onConfirmar});

  /// Se llama solo si la persona confirma en el diálogo.
  final VoidCallback onConfirmar;

  Future<void> _confirmar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado == true) onConfirmar();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Cerrar sesión',
      onPressed: () => _confirmar(context),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';

import 'perfil_screen.dart';

/// Conecta el perfil de Alexander con la sesión global de Gabriel.
/// No reemplaza el AuthGate ni la navegación definitiva.
class PerfilConSesionScreen extends StatelessWidget {
  const PerfilConSesionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();

    switch (sesion.estado) {
      case EstadoSesion.cargando:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case EstadoSesion.sinSesion:
        return const Scaffold(
          body: Center(child: Text('Inicia sesión para ver tu perfil.')),
        );

      case EstadoSesion.sinPerfil:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sesion.error ??
                      'No encontramos un perfil asociado a esta cuenta.',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await sesion.cerrarSesion();
                  },
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        );

      case EstadoSesion.autenticado:
        final persona = sesion.persona;

        if (persona == null) {
          return const Scaffold(
            body: Center(child: Text('Perfil no disponible')),
          );
        }

        return Scaffold(
          body: PerfilScreen(
            key: ValueKey(persona.uid),
            uid: persona.uid,
            cerrarSesion: sesion.cerrarSesion,
          ),
        );
    }
  }
}

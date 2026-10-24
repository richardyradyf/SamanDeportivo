import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/features/admin/screens/inicio_admin_screen.dart';
import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';
import 'package:saman_deportivo/features/entrenador/screens/inicio_entrenador_screen.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/features/perfil/presentation/perfil_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/persona.dart';

/// Construye la pestaña "Perfil" para la persona en sesión.
typedef ConstructorPerfil =
    Widget Function(Persona persona, SesionController sesion);

/// Puerta de entrada de la app: escucha al [SesionController] y decide
/// qué pantalla mostrar según el estado de la sesión y el rol.
///
/// - cargando     → indicador de carga
/// - sinSesion    → [sinSesion] (bienvenida o login)
/// - sinPerfil    → mensaje de error con opción de cerrar sesión
/// - autenticado  → inicio del estudiante, entrenador o administrador
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.sinSesion,
    this.construirPerfil = _perfilDeFirestore,
  });

  /// Pantalla para quien no ha iniciado sesión. Se recibe desde afuera
  /// para no depender de una pantalla concreta mientras el login no esté.
  final Widget sinSesion;

  /// Permite cambiar el perfil real (que usa Firestore) por uno falso en
  /// las pruebas.
  final ConstructorPerfil construirPerfil;

  static Widget _perfilDeFirestore(Persona persona, SesionController sesion) {
    return PerfilScreen(
      key: ValueKey(persona.uid),
      uid: persona.uid,
      cerrarSesion: sesion.cerrarSesion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();
    final persona = sesion.persona;

    switch (sesion.estado) {
      case EstadoSesion.cargando:
        return const _Cargando();
      case EstadoSesion.sinSesion:
        return sinSesion;
      case EstadoSesion.sinPerfil:
        return _SinPerfil(
          mensaje: sesion.error,
          onCerrarSesion: sesion.cerrarSesion,
        );
      case EstadoSesion.autenticado:
        // No debería pasar, pero si el estado llega antes que la persona
        // esperamos en vez de fallar.
        if (persona == null) return const _Cargando();
        return _inicioSegunRol(persona, sesion);
    }
  }

  Widget _inicioSegunRol(Persona persona, SesionController sesion) {
    // La llave con el uid reinicia la navegación si cambia el usuario.
    final llave = ValueKey(persona.uid);

    return switch (persona.rol) {
      Rol.estudiante => InicioEstudianteScreen(
        key: llave,
        nombre: persona.nombre,
        onCerrarSesion: sesion.cerrarSesion,
        perfil: construirPerfil(persona, sesion),
      ),
      Rol.entrenador => InicioEntrenadorScreen(
        key: llave,
        nombre: persona.nombre,
        onCerrarSesion: sesion.cerrarSesion,
        perfil: construirPerfil(persona, sesion),
      ),
      Rol.administrador => InicioAdminScreen(
        key: llave,
        nombre: persona.nombre,
        onCerrarSesion: sesion.cerrarSesion,
      ),
    };
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SinPerfil extends StatelessWidget {
  const _SinPerfil({required this.mensaje, required this.onCerrarSesion});

  final String? mensaje;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 56,
                  color: tema.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pudimos cargar tu perfil',
                  style: tema.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  mensaje ??
                      'Tu cuenta todavía no tiene un perfil registrado. '
                          'Si acabas de registrarte, espera unos segundos.',
                  style: tema.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

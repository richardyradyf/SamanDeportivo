import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/features/admin/screens/inicio_admin_screen.dart';
import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';
import 'package:saman_deportivo/features/entrenador/screens/inicio_entrenador_screen.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/features/perfil/presentation/perfil_screen.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

typedef ConstructorPerfil = Widget Function(
  Persona persona,
  SesionController sesion,
);

typedef ObtenerInscripciones = Stream<List<Inscripcion>> Function(
  String estudianteUid,
);

typedef CancelarInscripcion = Future<void> Function(
  String inscripcionId, {
  required String responsableUid,
});

typedef InscribirEstudiante = Future<Inscripcion> Function({
  required Estudiante estudiante,
  required Deporte deporte,
});

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.sinSesion,
    this.construirPerfil = _perfilDeFirestore,
    this.obtenerInscripciones,
    this.cancelarInscripcion,
    this.inscribirEstudiante,
  });

  final Widget sinSesion;
  final ConstructorPerfil construirPerfil;
  final ObtenerInscripciones? obtenerInscripciones;

  /// Función opcional para cancelar una inscripción.
  final CancelarInscripcion? cancelarInscripcion;
  final InscribirEstudiante? inscribirEstudiante;

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
        if (persona == null) {
          return const _Cargando();
        }

        return _inicioSegunRol(context, persona, sesion);
    }
  }

  Widget _inicioSegunRol(
    BuildContext context,
    Persona persona,
    SesionController sesion,
  ) {
    final llave = ValueKey(persona.uid);

    return switch (persona.rol) {
      Rol.estudiante => InicioEstudianteScreen(
        uid: persona.uid,
        onInscribirse: persona is Estudiante && inscribirEstudiante != null
            ? (deporte) =>
                  inscribirEstudiante!(estudiante: persona, deporte: deporte)
            : null,
        key: llave,
        nombre: persona.nombre,
        onCerrarSesion: sesion.cerrarSesion,
        perfil: construirPerfil(persona, sesion),
        inscripcionesStream: obtenerInscripciones?.call(persona.uid),
        onCancelarInscripcion: cancelarInscripcion == null
            ? null
            : (inscripcion) {
                _solicitarCancelacion(context, inscripcion, persona.uid);
              },
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
        perfil: construirPerfil(persona, sesion),
      ),
    };
  }

  Future<void> _solicitarCancelacion(
    BuildContext context,
    Inscripcion inscripcion,
    String estudianteUid,
  ) async {
    // Verificar que el estudiante sea propietario
    // de la inscripción antes de solicitar cancelación.
    if (inscripcion.estudianteUid != estudianteUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes cancelar una inscripción de otro estudiante.',
          ),
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar inscripción'),
        content: Text(
          '¿Deseas cancelar tu inscripción en '
          '${inscripcion.deporteNombre}?\n\n'
          'Esta acción liberará tu cupo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );

    // El estudiante decidió no cancelar.
    if (confirmado != true || !context.mounted) {
      return;
    }

    try {
      await cancelarInscripcion!(inscripcion.id, responsableUid: estudianteUid);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu inscripción fue cancelada correctamente.'),
        ),
      );
    } on InscripcionException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.mensaje)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cancelar la inscripción. '
            'Intenta nuevamente.',
          ),
        ),
      );
    }
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

import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/features/estudiante/widgets/sin_inscripciones_card.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Pantalla de inicio del estudiante, según el Figma:
/// Inicio, Explorar, Mis deportes, Inscripciones y Perfil.
///
/// Recibe por parámetro lo que necesita (nombre y cómo cerrar sesión) en
/// vez de buscar la sesión por su cuenta: así se puede probar sin Firebase.
/// Quien le pasa esos datos es el AuthGate.
class InicioEstudianteScreen extends StatelessWidget {
  const InicioEstudianteScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.perfil,
    this.reloj,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  /// Pantalla de perfil (módulo de Alexander). Mientras no exista, se
  /// muestra un aviso de "próximamente".
  final Widget? perfil;

  /// De dónde sale la hora para el saludo. En las pruebas se pasa una hora
  /// fija; en la app se usa la hora real.
  final DateTime Function()? reloj;

  static const indiceExplorar = 1;

  @override
  Widget build(BuildContext context) {
    final ahora = (reloj ?? DateTime.now)();
    final saludo = PanelBienvenida.componer(
      PanelBienvenida.saludoSegunHora(ahora),
      nombre,
    );

    return LayoutResponsivo(
      titulo: 'Samán',
      subtitulo: Rol.estudiante.etiqueta,
      acciones: [BotonCerrarSesion(onConfirmar: onCerrarSesion)],
      destinos: [
        DestinoNavegacion(
          etiqueta: 'Inicio',
          icono: Icons.home_outlined,
          iconoSeleccionado: Icons.home,
          // Por ahora siempre "sin inscripciones": la próxima actividad y
          // "Mis disciplinas" llegan cuando exista el módulo de inscripciones.
          pantalla: Builder(
            builder: (context) => PanelBienvenida(
              saludo: '$saludo 👋',
              contenido: SinInscripcionesCard(
                onExplorar: () => LayoutResponsivo.irA(context, indiceExplorar),
              ),
            ),
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Explorar',
          icono: Icons.search,
          iconoSeleccionado: Icons.search,
          pantalla: SeccionPendiente(titulo: 'Explorar', icono: Icons.search),
        ),
        const DestinoNavegacion(
          etiqueta: 'Mis deportes',
          icono: Icons.sports_soccer_outlined,
          iconoSeleccionado: Icons.sports_soccer,
          pantalla: SeccionPendiente(
            titulo: 'Mis deportes',
            icono: Icons.sports_soccer,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Inscripciones',
          icono: Icons.assignment_outlined,
          iconoSeleccionado: Icons.assignment,
          pantalla: SeccionPendiente(
            titulo: 'Inscripciones',
            icono: Icons.assignment,
          ),
        ),
        DestinoNavegacion(
          etiqueta: 'Perfil',
          icono: Icons.person_outline,
          iconoSeleccionado: Icons.person,
          pantalla:
              perfil ??
              const SeccionPendiente(titulo: 'Perfil', icono: Icons.person),
        ),
      ],
    );
  }
}

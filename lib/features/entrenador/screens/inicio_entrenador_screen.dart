import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Pantalla de inicio del entrenador, según el Figma: Dashboard,
/// Mis disciplinas, Estudiantes, Asistencia, Historial y Perfil.
///
/// Son 6 secciones: en el móvil el menú es desplegable (ver
/// [LayoutResponsivo]).
class InicioEntrenadorScreen extends StatelessWidget {
  const InicioEntrenadorScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.perfil,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  /// Pantalla de perfil (módulo de Alexander). Mientras no exista, se
  /// muestra un aviso de "próximamente".
  final Widget? perfil;

  @override
  Widget build(BuildContext context) {
    return LayoutResponsivo(
      titulo: 'Samán',
      subtitulo: Rol.entrenador.etiqueta,
      acciones: [BotonCerrarSesion(onConfirmar: onCerrarSesion)],
      destinos: [
        DestinoNavegacion(
          etiqueta: 'Dashboard',
          icono: Icons.dashboard_outlined,
          iconoSeleccionado: Icons.dashboard,
          // La próxima sesión y las estadísticas llegan con los módulos de
          // horarios y asistencia.
          pantalla: PanelBienvenida(
            saludo: PanelBienvenida.componer('Hola', nombre),
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Mis disciplinas',
          icono: Icons.sports_outlined,
          iconoSeleccionado: Icons.sports,
          pantalla: SeccionPendiente(
            titulo: 'Mis disciplinas',
            icono: Icons.sports,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Estudiantes',
          icono: Icons.groups_outlined,
          iconoSeleccionado: Icons.groups,
          pantalla: SeccionPendiente(
            titulo: 'Estudiantes',
            icono: Icons.groups,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Asistencia',
          icono: Icons.fact_check_outlined,
          iconoSeleccionado: Icons.fact_check,
          pantalla: SeccionPendiente(
            titulo: 'Asistencia',
            icono: Icons.fact_check,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Historial',
          icono: Icons.history,
          iconoSeleccionado: Icons.history,
          pantalla: SeccionPendiente(titulo: 'Historial', icono: Icons.history),
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

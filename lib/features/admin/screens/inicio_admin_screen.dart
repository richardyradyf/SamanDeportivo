import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Pantalla de inicio del administrador, según el Figma: Dashboard,
/// Deportes, Entrenadores, Horarios, Inscripciones, Analítica y
/// Configuración (el Figma no le da sección de Perfil).
///
/// Son 7 secciones: en el móvil el menú es desplegable (ver
/// [LayoutResponsivo]).
class InicioAdminScreen extends StatelessWidget {
  const InicioAdminScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return LayoutResponsivo(
      titulo: 'Samán',
      subtitulo: Rol.administrador.etiqueta,
      acciones: [BotonCerrarSesion(onConfirmar: onCerrarSesion)],
      destinos: [
        DestinoNavegacion(
          etiqueta: 'Dashboard',
          icono: Icons.dashboard_outlined,
          iconoSeleccionado: Icons.dashboard,
          // Las cifras del dashboard llegan con los módulos de deportes,
          // inscripciones y analítica.
          pantalla: PanelBienvenida(
            saludo: PanelBienvenida.componer('Hola', nombre),
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Deportes',
          icono: Icons.sports_soccer_outlined,
          iconoSeleccionado: Icons.sports_soccer,
          pantalla: SeccionPendiente(
            titulo: 'Deportes',
            icono: Icons.sports_soccer,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Entrenadores',
          icono: Icons.badge_outlined,
          iconoSeleccionado: Icons.badge,
          pantalla: SeccionPendiente(
            titulo: 'Entrenadores',
            icono: Icons.badge,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Horarios',
          icono: Icons.calendar_month_outlined,
          iconoSeleccionado: Icons.calendar_month,
          pantalla: SeccionPendiente(
            titulo: 'Horarios',
            icono: Icons.calendar_month,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Inscripciones',
          icono: Icons.how_to_reg_outlined,
          iconoSeleccionado: Icons.how_to_reg,
          pantalla: SeccionPendiente(
            titulo: 'Inscripciones',
            icono: Icons.how_to_reg,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Analítica',
          icono: Icons.bar_chart,
          iconoSeleccionado: Icons.bar_chart,
          pantalla: SeccionPendiente(
            titulo: 'Analítica',
            icono: Icons.bar_chart,
          ),
        ),
        const DestinoNavegacion(
          etiqueta: 'Configuración',
          icono: Icons.settings_outlined,
          iconoSeleccionado: Icons.settings,
          pantalla: SeccionPendiente(
            titulo: 'Configuración',
            icono: Icons.settings,
          ),
        ),
      ],
    );
  }
}

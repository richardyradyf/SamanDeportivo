import 'package:saman_deportivo/features/admin/dashboard/presentation/dashboard_admin_screen.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/analitica_admin_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/firestore_entrenador_repository.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/firebase_agenda_gateway.dart';
import 'package:saman_deportivo/features/admin/entrenadores/presentation/entrenadores_admin_screen.dart';
import 'package:saman_deportivo/features/admin/entrenadores/presentation/horarios_admin_screen.dart';
import 'package:saman_deportivo/features/admin/deportes/presentation/deportes_admin_screen.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Pantalla de inicio del administrador, según el Figma: Dashboard,
/// Deportes, Entrenadores, Horarios, Inscripciones, Analítica y
/// Configuración (el perfil se abre allí, sin añadir un octavo destino).
///
/// Son 7 secciones: en el móvil el menú es desplegable (ver
/// [LayoutResponsivo]).
class InicioAdminScreen extends StatelessWidget {
  const InicioAdminScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.perfil,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  /// Perfil del administrador, integrado dentro de Configuración.
  /// Si se omite, mantenemos el placeholder usado por pruebas existentes.
  final Widget? perfil;

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
          pantalla: DashboardAdminScreen(nombre: nombre),
        ),
        const DestinoNavegacion(
          etiqueta: 'Deportes',
          icono: Icons.sports_soccer_outlined,
          iconoSeleccionado: Icons.sports_soccer,
          pantalla: DeportesAdminScreen(),
        ),
        const DestinoNavegacion(
          etiqueta: 'Entrenadores',
          icono: Icons.badge_outlined,
          iconoSeleccionado: Icons.badge,
          pantalla: EntrenadoresAdminScreen(),
        ),
        DestinoNavegacion(
          etiqueta: 'Horarios',
          icono: Icons.calendar_month_outlined,
          iconoSeleccionado: Icons.calendar_month,
          // Los tests de InicioAdminScreen no inicializan Firebase.
          pantalla: Firebase.apps.isEmpty
              ? const HorariosAdminScreen()
              : HorariosAdminScreen(
                  deportes: FirestoreDeporteRepository(),
                  entrenadores: FirestoreEntrenadorRepository(),
                  agendaGateway: FirebaseAgendaGateway(),
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
          pantalla: AnaliticaAdminScreen(),
        ),
        DestinoNavegacion(
          etiqueta: 'Configuración',
          icono: Icons.settings_outlined,
          iconoSeleccionado: Icons.settings,
          pantalla:
              perfil ??
              const SeccionPendiente(
                titulo: 'Configuración',
                icono: Icons.settings,
              ),
        ),
      ],
    );
  }
}

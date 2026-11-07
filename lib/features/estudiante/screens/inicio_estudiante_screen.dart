import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/estudiante/widgets/sin_inscripciones_card.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

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
    this.deportes,
    this.resenas,
    this.uid,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  /// Pantalla de perfil (módulo de Alexander). Mientras no exista, se
  /// muestra un aviso de "próximamente".
  final Widget? perfil;

  /// De dónde sale la hora para el saludo. En las pruebas se pasa una hora
  /// fija; en la app se usa la hora real.
  final DateTime Function()? reloj;

  /// Repositorio del catálogo. En las pruebas se pasa uno falso; si es
  /// null, el catálogo usa Firestore.
  final DeporteRepository? deportes;

  /// Reseñas de los deportes. Mientras sea null, el detalle avisa que
  /// todavía no están disponibles.
  final ResenaRepository? resenas;

  /// UID del estudiante, para reconocer su propia reseña.
  final String? uid;

  static const indiceExplorar = 1;

  /// Abre el detalle del deporte elegido en el catálogo.
  void _verDeporte(BuildContext context, Deporte deporte) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleDeporteScreen(
          deporte: deporte,
          deportes: deportes,
          resenas: resenas,
          estudianteUid: uid,
          estudianteNombre: nombre,
        ),
      ),
    );
  }

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
        DestinoNavegacion(
          etiqueta: 'Explorar',
          icono: Icons.search,
          iconoSeleccionado: Icons.search,
          pantalla: CatalogoScreen(
            repositorio: deportes,
            onVerDeporte: (deporte) => _verDeporte(context, deporte),
          ),
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

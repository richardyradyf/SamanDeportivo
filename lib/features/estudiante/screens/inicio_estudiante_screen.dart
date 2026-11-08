import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/screens/mis_inscripciones_screen.dart';
import 'package:saman_deportivo/features/estudiante/widgets/sin_inscripciones_card.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

class InicioEstudianteScreen extends StatelessWidget {
  const InicioEstudianteScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.perfil,
    this.reloj,
    this.inscripcionesStream,
    this.onCancelarInscripcion,
    this.deportes,
    this.resenas,
    this.uid,
    this.onInscribirse,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;
  final Widget? perfil;
  final DateTime Function()? reloj;

  // Funcionalidades de inscripciones de Mariana.
  final Stream<List<Inscripcion>>? inscripcionesStream;
  final ValueChanged<Inscripcion>? onCancelarInscripcion;

  // Funcionalidades del catálogo de Gabriel.
  final DeporteRepository? deportes;
  final ResenaRepository? resenas;
  final String? uid;
  final Future<Inscripcion> Function(Deporte deporte)? onInscribirse;

  static const indiceExplorar = 1;

  void _verDeporte(BuildContext context, Deporte deporte) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleDeporteScreen(
          deporte: deporte,
          deportes: deportes,
          resenas: resenas,
          estudianteUid: uid,
          estudianteNombre: nombre,
          onInscribirse: onInscribirse == null
              ? null
              : (deporteSeleccionado) async {
                  try {
                    await onInscribirse!(deporteSeleccionado);

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Inscripción creada correctamente. '
                          'Está pendiente de pago.',
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo completar la inscripción. '
                          'Verifica los cupos y vuelve a intentarlo.',
                        ),
                      ),
                    );
                  }
                },
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
          pantalla: Builder(
            builder: (context) => PanelBienvenida(
              saludo: '$saludo 👋',
              contenido: SinInscripcionesCard(
                onExplorar: () => LayoutResponsivo.irA(context, indiceExplorar),
              ),
            ),
          ),
        ),

        // Catálogo de Gabriel.
        DestinoNavegacion(
          etiqueta: 'Explorar',
          icono: Icons.search,
          iconoSeleccionado: Icons.search,
          pantalla: CatalogoScreen(
            repositorio: deportes,
            usuarioUid: uid,
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

        // Inscripciones de Mariana.
        DestinoNavegacion(
          etiqueta: 'Inscripciones',
          icono: Icons.assignment_outlined,
          iconoSeleccionado: Icons.assignment,
          pantalla: MisInscripcionesScreen(
            inscripcionesStream: inscripcionesStream,
            onCancelarInscripcion: onCancelarInscripcion,
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

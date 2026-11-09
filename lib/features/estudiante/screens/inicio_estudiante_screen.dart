import 'dart:async';

import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/core/widgets/seccion_pendiente.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/permiso_resena.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/screens/mis_inscripciones_screen.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/mis_deportes_screen.dart';
import 'package:saman_deportivo/features/estudiante/widgets/sin_inscripciones_card.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

/// Pantalla de inicio del estudiante, según el Figma:
/// Inicio, Explorar, Mis deportes, Inscripciones y Perfil.
///
/// Recibe por parámetro lo que necesita (nombre, sesión, repositorios) en
/// vez de buscarlo por su cuenta: así se puede probar sin Firebase. Quien
/// le pasa esos datos es el AuthGate.
class InicioEstudianteScreen extends StatefulWidget {
  const InicioEstudianteScreen({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.perfil,
    this.pagos,
    this.reloj,
    this.inscripcionesStream,
    this.onCancelarInscripcion,
    this.deportes,
    this.resenas,
    this.uid,
    this.onInscribirse,
    this.asistencias,
  });

  final String nombre;
  final VoidCallback onCerrarSesion;

  /// Pantalla de perfil (módulo de Alexander).
  final Widget? perfil;

  /// Pagos del estudiante (módulo de Andrés). Si se pasa, aparece un botón
  /// en la barra superior que la abre; si no, el botón no se muestra.
  final Widget? pagos;

  /// De dónde sale la hora para el saludo; en las pruebas, una hora fija.
  final DateTime Function()? reloj;

  // Funcionalidades de inscripciones de Mariana.
  final Stream<List<Inscripcion>>? inscripcionesStream;
  final ValueChanged<Inscripcion>? onCancelarInscripcion;

  // Funcionalidades del catálogo de Gabriel.
  final DeporteRepository? deportes;
  final ResenaRepository? resenas;
  final String? uid;
  final Future<Inscripcion> Function(Deporte deporte)? onInscribirse;

  /// Asistencia del estudiante, para "Mis deportes" (registrada por el
  /// entrenador). Sin Firebase, en las pruebas, se pasa una falsa.
  final AsistenciaRepository? asistencias;

  static const indiceExplorar = 1;
  static const indiceMisDeportes = 2;
  static const indiceInscripciones = 3;

  @override
  State<InicioEstudianteScreen> createState() => _InicioEstudianteScreenState();
}

class _InicioEstudianteScreenState extends State<InicioEstudianteScreen> {
  // Las inscripciones las usan dos pantallas: "Mis inscripciones" y el
  // detalle del deporte (para saber si el estudiante puede calificar). Se
  // escuchan UNA sola vez aquí y se reparten, porque un stream de Firestore
  // no siempre admite dos suscripciones y el detalle se abre más tarde.
  final _inscripciones = ValueNotifier<List<Inscripcion>?>(null);
  final _cambios = StreamController<List<Inscripcion>>.broadcast();
  StreamSubscription<List<Inscripcion>>? _suscripcion;
  Object? _error;
  Stream<List<Inscripcion>>? _paraMisInscripciones;

  @override
  void initState() {
    super.initState();
    _escuchar(widget.inscripcionesStream);
  }

  @override
  void didUpdateWidget(InicioEstudianteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inscripcionesStream != widget.inscripcionesStream) {
      _escuchar(widget.inscripcionesStream);
    }
  }

  void _escuchar(Stream<List<Inscripcion>>? origen) {
    _suscripcion?.cancel();
    _suscripcion = null;
    _error = null;
    if (origen == null) {
      _paraMisInscripciones = null;
      return;
    }
    _suscripcion = origen.listen(
      (lista) {
        _error = null;
        _inscripciones.value = lista;
        _cambios.add(lista);
      },
      onError: (Object error, StackTrace pila) {
        _error = error;
        _cambios.addError(error, pila);
      },
    );
    _paraMisInscripciones = _conUltimoValor();
  }

  /// Stream para "Mis inscripciones": entrega primero el último valor que
  /// llegó (o el último error) y después cada cambio.
  Stream<List<Inscripcion>> _conUltimoValor() {
    late final StreamController<List<Inscripcion>> salida;
    StreamSubscription<List<Inscripcion>>? reenvio;
    salida = StreamController<List<Inscripcion>>(
      onListen: () {
        final ultimo = _inscripciones.value;
        final error = _error;
        if (error != null) {
          salida.addError(error);
        } else if (ultimo != null) {
          salida.add(ultimo);
        }
        reenvio = _cambios.stream.listen(
          salida.add,
          onError: salida.addError,
        );
      },
      onCancel: () => reenvio?.cancel(),
    );
    return salida.stream;
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _cambios.close();
    _inscripciones.dispose();
    super.dispose();
  }

  void _verDeporte(BuildContext context, Deporte deporte) {
    final onInscribirse = widget.onInscribirse;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Si el estudiante paga con el detalle abierto, su inscripción pasa
        // a confirmada y el formulario de reseña aparece sin recargar.
        builder: (_) => ValueListenableBuilder<List<Inscripcion>?>(
          valueListenable: _inscripciones,
          builder: (context, inscripciones, _) => DetalleDeporteScreen(
            deporte: deporte,
            deportes: widget.deportes,
            resenas: widget.resenas,
            estudianteUid: widget.uid,
            estudianteNombre: widget.nombre,
            puedeResenar: tieneInscripcionConfirmada(
              inscripciones,
              deporte.codigo,
            ),
            onInscribirse: onInscribirse == null
                ? null
                : (deporteSeleccionado) async {
                    try {
                      await onInscribirse(deporteSeleccionado);

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ahora = (widget.reloj ?? DateTime.now)();
    final saludo = PanelBienvenida.componer(
      PanelBienvenida.saludoSegunHora(ahora),
      widget.nombre,
    );
    final paginaPagos = widget.pagos;

    return LayoutResponsivo(
      titulo: 'Samán',
      subtitulo: Rol.estudiante.etiqueta,
      acciones: [
        if (paginaPagos != null)
          IconButton(
            tooltip: 'Pagos',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Pagos')),
                  body: paginaPagos,
                ),
              ),
            ),
          ),
        BotonCerrarSesion(onConfirmar: widget.onCerrarSesion),
      ],
      destinos: [
        DestinoNavegacion(
          etiqueta: 'Inicio',
          icono: Icons.home_outlined,
          iconoSeleccionado: Icons.home,
          // Como en el Figma: con deportes confirmados, la próxima sesión y
          // "Mis disciplinas"; sin ellos, la invitación a explorar.
          pantalla: Builder(
            builder: (context) => ValueListenableBuilder<List<Inscripcion>?>(
              valueListenable: _inscripciones,
              builder: (context, inscripciones, _) {
                final tieneConfirmadas =
                    inscripciones?.any(
                      (i) => i.estado == EstadoInscripcion.confirmada,
                    ) ??
                    false;
                return PanelBienvenida(
                  saludo: '$saludo 👋',
                  contenido: tieneConfirmadas
                      ? ResumenMisDeportes(
                          inscripciones: inscripciones,
                          deportes: widget.deportes,
                          reloj: widget.reloj,
                          onVerDeporte: (deporte) =>
                              _verDeporte(context, deporte),
                          onVerInscripciones: () => LayoutResponsivo.irA(
                            context,
                            InicioEstudianteScreen.indiceInscripciones,
                          ),
                        )
                      : SinInscripcionesCard(
                          onExplorar: () => LayoutResponsivo.irA(
                            context,
                            InicioEstudianteScreen.indiceExplorar,
                          ),
                        ),
                );
              },
            ),
          ),
        ),

        // Catálogo de Gabriel.
        DestinoNavegacion(
          etiqueta: 'Explorar',
          icono: Icons.search,
          iconoSeleccionado: Icons.search,
          pantalla: CatalogoScreen(
            repositorio: widget.deportes,
            usuarioUid: widget.uid,
            onVerDeporte: (deporte) => _verDeporte(context, deporte),
          ),
        ),

        DestinoNavegacion(
          etiqueta: 'Mis deportes',
          icono: Icons.sports_soccer_outlined,
          iconoSeleccionado: Icons.sports_soccer,
          pantalla: Builder(
            builder: (context) => ValueListenableBuilder<List<Inscripcion>?>(
              valueListenable: _inscripciones,
              // Sin stream de inscripciones (en algunas pruebas) no hay nada
              // que esperar: se muestra como lista vacía.
              builder: (context, inscripciones, _) => MisDeportesScreen(
                inscripciones: widget.inscripcionesStream == null
                    ? const []
                    : inscripciones,
                deportes: widget.deportes,
                asistencias: widget.asistencias,
                estudianteUid: widget.uid,
                reloj: widget.reloj,
                onVerDeporte: (deporte) => _verDeporte(context, deporte),
                onExplorar: () => LayoutResponsivo.irA(
                  context,
                  InicioEstudianteScreen.indiceExplorar,
                ),
                onVerInscripciones: () => LayoutResponsivo.irA(
                  context,
                  InicioEstudianteScreen.indiceInscripciones,
                ),
              ),
            ),
          ),
        ),

        // Inscripciones de Mariana.
        DestinoNavegacion(
          etiqueta: 'Inscripciones',
          icono: Icons.assignment_outlined,
          iconoSeleccionado: Icons.assignment,
          pantalla: MisInscripcionesScreen(
            inscripcionesStream: _paraMisInscripciones,
            onCancelarInscripcion: widget.onCancelarInscripcion,
          ),
        ),

        DestinoNavegacion(
          etiqueta: 'Perfil',
          icono: Icons.person_outline,
          iconoSeleccionado: Icons.person,
          pantalla:
              widget.perfil ??
              const SeccionPendiente(titulo: 'Perfil', icono: Icons.person),
        ),
      ],
    );
  }
}
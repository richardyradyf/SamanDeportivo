import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/features/admin/espacios/data/firestore_espacio_repository.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/data/firestore_disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/data/firestore_reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/data/reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/presentation/crear_reserva_screen.dart';
import 'package:saman_deportivo/features/reservas/presentation/detalle_reserva_screen.dart';
import 'package:saman_deportivo/features/reservas/presentation/disponibilidad_view.dart';
import 'package:saman_deportivo/features/reservas/presentation/explorar_espacios_view.dart';
import 'package:saman_deportivo/features/reservas/presentation/mis_reservas_view.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Reservas de espacios para los tres roles (Hito 4).
///
/// Tres pestañas: Espacios (pantalla A), Disponibilidad (B) y Mis reservas
/// (D), más el formulario de Nueva reserva (C). La misma pantalla sirve a
/// estudiantes, entrenadores y administradores: [rol] solo cambia los
/// límites que se muestran en el formulario. Las reglas reales están en los
/// repositorios compartidos; aquí no se recalculan permisos.
///
/// Si no se pasan repositorios y Firebase está iniciado, usa los de
/// Firestore. Sin Firebase (en algunas pruebas) muestra un aviso.
class ReservasScreen extends StatefulWidget {
  const ReservasScreen({
    super.key,
    required this.rol,
    this.usuarioUid,
    this.espacios,
    this.deportes,
    this.disponibilidad,
    this.reservas,
    this.reloj,
    this.mostrarTitulo = true,
  });

  final Rol rol;

  /// False cuando la pantalla se abre con su propia barra superior que ya
  /// dice «Reservas».
  final bool mostrarTitulo;

  /// Usuario en sesión. Si es null se toma de FirebaseAuth.
  final String? usuarioUid;
  final EspacioRepository? espacios;
  final DeporteRepository? deportes;
  final DisponibilidadRepository? disponibilidad;
  final ReservasRepository? reservas;
  final DateTime Function()? reloj;

  static const int indiceEspacios = 0;
  static const int indiceDisponibilidad = 1;
  static const int indiceMisReservas = 2;

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(length: 3, vsync: this);

  EspacioRepository? _espacios;
  DeporteRepository? _deportes;
  DisponibilidadRepository? _disponibilidad;
  ReservasRepository? _reservas;

  Stream<List<EspacioDeportivo>>? _streamEspacios;
  Stream<List<Deporte>>? _streamDeportes;
  /// Abre la consulta de "Mis reservas". Es una función y no un stream
  /// guardado porque la pestaña se vuelve a construir al regresar a ella, y
  /// un stream de Firestore no admite dos suscripciones.
  Stream<List<ReservaEspacio>> Function()? _observarMisReservas;

  /// Espacio elegido en Disponibilidad (también al tocar una tarjeta).
  String? _espacioId;

  DateTime _ahora() => (widget.reloj ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final conFirebase = Firebase.apps.isNotEmpty;
    _espacios = widget.espacios ?? (conFirebase ? FirestoreEspacioRepository() : null);
    _deportes = widget.deportes ?? (conFirebase ? FirestoreDeporteRepository() : null);
    _disponibilidad =
        widget.disponibilidad ??
        (conFirebase ? FirestoreDisponibilidadRepository() : null);
    _reservas = widget.reservas ?? (conFirebase ? FirestoreReservasRepository() : null);

    _streamEspacios = _espacios?.observarTodos().map(
      (lista) =>
          lista.where((e) => e.activo).toList()
            ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
    );
    _streamDeportes = _deportes?.observarCatalogo();

    final uid =
        widget.usuarioUid ??
        (conFirebase ? FirebaseAuth.instance.currentUser?.uid : null);
    final reservas = _reservas;
    if (uid != null && reservas != null) {
      _observarMisReservas = () {
        try {
          return reservas.observarPropias(uid);
        } catch (error) {
          return Stream.error(error);
        }
      };
    }
  }

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  Future<void> _nuevaReserva(
    List<EspacioDeportivo> espacios,
    List<Deporte> deportes, {
    String? espacioId,
    DateTime? inicio,
    DateTime? fin,
  }) async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearReservaScreen(
          espacios: espacios,
          deportes: deportes,
          disponibilidad: _disponibilidad!,
          reservas: _reservas!,
          rol: widget.rol,
          reloj: _ahora,
          espacioId: espacioId ?? _espacioId,
          inicio: inicio,
          fin: fin,
        ),
      ),
    );
    if (guardada != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reserva confirmada.')),
    );
    _pestanas.animateTo(ReservasScreen.indiceMisReservas);
  }

  Future<void> _abrirReserva(
    ReservaEspacio reserva,
    List<EspacioDeportivo> espacios,
  ) async {
    EspacioDeportivo? espacio;
    for (final e in espacios) {
      if (e.id == reserva.espacioId) espacio = e;
    }
    final reservas = _reservas!;
    final cancelada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DetalleReservaScreen(
          reserva: reserva,
          espacio: espacio?.nombre ?? nombreEspacio(espacios, reserva.espacioId),
          tipoEspacio: espacio?.tipo,
          reloj: _ahora,
          onCancelar: reservas.cancelar,
        ),
      ),
    );
    if (cancelada != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reserva cancelada.')),
    );
  }

  void _verDisponibilidad(EspacioDeportivo espacio) {
    setState(() => _espacioId = espacio.id);
    _pestanas.animateTo(ReservasScreen.indiceDisponibilidad);
  }

  @override
  Widget build(BuildContext context) {
    final streamEspacios = _streamEspacios;
    final streamDeportes = _streamDeportes;
    if (streamEspacios == null ||
        streamDeportes == null ||
        _disponibilidad == null ||
        _reservas == null) {
      return const AvisoReservas(
        icono: Icons.event_busy_outlined,
        titulo: 'Las reservas no están disponibles por ahora',
      );
    }

    return StreamBuilder<List<EspacioDeportivo>>(
      stream: streamEspacios,
      builder: (context, espaciosSnap) => StreamBuilder<List<Deporte>>(
        stream: streamDeportes,
        builder: (context, deportesSnap) {
          final cargando = !espaciosSnap.hasData || !deportesSnap.hasData;
          final fallo = espaciosSnap.hasError || deportesSnap.hasError;
          final espacios = espaciosSnap.data ?? const <EspacioDeportivo>[];
          final deportes = deportesSnap.data ?? const <Deporte>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(
                mostrarTitulo: widget.mostrarTitulo,
                onNuevaReserva: cargando || fallo || espacios.isEmpty
                    ? null
                    : () => _nuevaReserva(espacios, deportes),
              ),
              TabBar(
                controller: _pestanas,
                // Pestañas fijas del mismo ancho: las tres se ven siempre,
                // también en el celular.
                tabs: const [
                  Tab(text: 'Espacios'),
                  Tab(text: 'Disponibilidad'),
                  Tab(text: 'Mis reservas'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: fallo
                    ? const AvisoReservas(
                        icono: Icons.error_outline,
                        titulo: 'No pudimos cargar los espacios',
                        mensaje: 'Revisa tu conexión e inténtalo de nuevo.',
                      )
                    : cargando
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _pestanas,
                        children: [
                          ExplorarEspaciosView(
                            espacios: espacios,
                            deportes: deportes,
                            disponibilidad: _disponibilidad!,
                            reloj: _ahora,
                            onVerDisponibilidad: _verDisponibilidad,
                            onReservar: (espacio) => _nuevaReserva(
                              espacios,
                              deportes,
                              espacioId: espacio.id,
                            ),
                          ),
                          DisponibilidadView(
                            espacios: espacios,
                            deportes: deportes,
                            disponibilidad: _disponibilidad!,
                            rol: widget.rol,
                            reloj: _ahora,
                            espacioId: _espacioId,
                            onCambiarEspacio: (id) => _espacioId = id,
                            onReservar: (espacio, inicio, fin) => _nuevaReserva(
                              espacios,
                              deportes,
                              espacioId: espacio.id,
                              inicio: inicio,
                              fin: fin,
                            ),
                          ),
                          MisReservasView(
                            observar: _observarMisReservas,
                            espacios: espacios,
                            reloj: _ahora,
                            onAbrir: (reserva) => _abrirReserva(reserva, espacios),
                            onNuevaReserva: () => _nuevaReserva(espacios, deportes),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.mostrarTitulo,
    required this.onNuevaReserva,
  });

  final bool mostrarTitulo;
  final VoidCallback? onNuevaReserva;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ancho = MediaQuery.sizeOf(context).width >= 600;
    final titulos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reservas',
          style: ancho ? tema.textTheme.headlineLarge : tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Consulta los espacios y reserva una cancha o el gimnasio.',
          style: tema.textTheme.bodySmall,
        ),
      ],
    );
    final boton = FilledButton.icon(
      key: const Key('nuevaReserva'),
      onPressed: onNuevaReserva,
      icon: const Icon(Icons.add),
      label: const Text('Nueva reserva'),
    );

    if (!mostrarTitulo) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Align(alignment: Alignment.centerRight, child: boton),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, ancho ? 24 : 16, 16, 12),
      child: ancho
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [Expanded(child: titulos), boton],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titulos, const SizedBox(height: 12), boton],
            ),
    );
  }
}

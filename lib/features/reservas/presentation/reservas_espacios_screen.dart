import 'dart:async';

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
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/horario_reserva_caracas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Fase 2B: catálogo, disponibilidad (clases + reservas), formulario y
/// cancelación. Repositorios inyectables para pruebas sin Firebase.
class ReservasEspaciosScreen extends StatefulWidget {
  const ReservasEspaciosScreen({
    super.key,
    required this.rol,
    this.usuarioUid,
    this.espacios,
    this.deportes,
    this.disponibilidad,
    this.reservas,
    this.reloj,
  });

  final Rol rol;
  final String? usuarioUid;
  final EspacioRepository? espacios;
  final DeporteRepository? deportes;
  final DisponibilidadRepository? disponibilidad;
  final ReservasRepository? reservas;
  final DateTime Function()? reloj;

  @override
  State<ReservasEspaciosScreen> createState() => _ReservasEspaciosScreenState();
}

class _ReservasEspaciosScreenState extends State<ReservasEspaciosScreen> {
  EspacioRepository? _espaciosRepo;
  DeporteRepository? _deportesRepo;
  DisponibilidadRepository? _disponibilidadRepo;
  ReservasRepository? _reservasRepo;
  String? _uid;

  StreamSubscription<List<EspacioDeportivo>>? _espaciosSub;
  StreamSubscription<List<Deporte>>? _deportesSub;
  StreamSubscription<List<OcupacionEspacio>>? _ocupacionesSub;
  StreamSubscription<List<ReservaEspacio>>? _reservasSub;

  List<EspacioDeportivo>? _espacios;
  List<Deporte>? _deportes;
  List<OcupacionEspacio>? _ocupaciones;
  List<ReservaEspacio>? _misReservas;
  String? _errorLectura;
  String? _errorOcupaciones;
  String? _errorReservas;
  String? _errorSolicitud;
  String? _espacioId;
  late DateTime _dia;
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  int _duracionMinutos = 60;
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _cancelandoId;

  DateTime _ahora() => (widget.reloj ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final caracas = HorarioReservaCaracas.fechaLocal(_ahora());
    _dia = DateTime(caracas.year, caracas.month, caracas.day + 1);

    final firebaseDisponible = Firebase.apps.isNotEmpty;
    _uid =
        widget.usuarioUid ??
        (firebaseDisponible ? FirebaseAuth.instance.currentUser?.uid : null);
    _espaciosRepo =
        widget.espacios ??
        (firebaseDisponible ? FirestoreEspacioRepository() : null);
    _deportesRepo =
        widget.deportes ??
        (firebaseDisponible ? FirestoreDeporteRepository() : null);
    _disponibilidadRepo =
        widget.disponibilidad ??
        (firebaseDisponible ? FirestoreDisponibilidadRepository() : null);
    _reservasRepo =
        widget.reservas ??
        (firebaseDisponible ? FirestoreReservasRepository() : null);

    final espacios = _espaciosRepo;
    if (espacios != null) {
      _espaciosSub = espacios.observarTodos().listen(
        (lista) {
          if (!mounted) return;
          final activos = lista.where((e) => e.activo).toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));
          setState(() {
            _espacios = activos;
            _errorLectura = null;
          });
          if (!activos.any((e) => e.id == _espacioId)) {
            _seleccionarEspacio(activos.isEmpty ? null : activos.first.id);
          }
        },
        onError: (Object error) {
          if (mounted) {
            setState(() => _errorLectura = 'No pudimos cargar los espacios.');
          }
        },
      );
    }
    final deportes = _deportesRepo;
    if (deportes != null) {
      _deportesSub = deportes
          .observarCatalogo(soloActivos: false)
          .listen(
            (lista) {
              if (mounted) {
                setState(() {
                  _deportes = lista;
                  _errorLectura = null;
                });
              }
            },
            onError: (Object error) {
              if (mounted) {
                setState(
                  () => _errorLectura = 'No pudimos consultar los horarios.',
                );
              }
            },
          );
    }
    final reservas = _reservasRepo;
    final uid = _uid;
    if (reservas != null && uid != null) {
      try {
        _reservasSub = reservas
            .observarPropias(uid)
            .listen(
              (lista) {
                if (mounted) {
                  setState(() {
                    _misReservas = lista;
                    _errorReservas = null;
                  });
                }
              },
              onError: (Object error) {
                if (mounted) {
                  setState(
                    () => _errorReservas = 'No pudimos consultar tus reservas.',
                  );
                }
              },
            );
      } catch (_) {
        _errorReservas = 'No pudimos consultar tus reservas.';
      }
    }
    _motivo.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  void _seleccionarEspacio(String? id) {
    _ocupacionesSub?.cancel();
    setState(() {
      _espacioId = id;
      _ocupaciones = null;
      _errorOcupaciones = null;
    });
    final repo = _disponibilidadRepo;
    if (id == null || repo == null) return;
    final desde = HorarioReservaCaracas.inicioDelDia(_dia);
    // Una reserva de noche puede terminar en la madrugada siguiente.
    // Incluir ambos días evita mostrar una falsa disponibilidad al cruzar
    // las 00:00 en el formulario.
    final hasta = desde.add(const Duration(days: 2));
    try {
      _ocupacionesSub = repo
          .observarOcupaciones(espacioId: id, desde: desde, hasta: hasta)
          .listen(
            (lista) {
              if (mounted && _espacioId == id) {
                setState(() {
                  _ocupaciones = lista;
                  _errorOcupaciones = null;
                });
              }
            },
            onError: (Object error) {
              if (mounted && _espacioId == id) {
                setState(
                  () => _errorOcupaciones =
                      'No pudimos cargar la disponibilidad.',
                );
              }
            },
          );
    } catch (_) {
      setState(
        () => _errorOcupaciones = 'No pudimos cargar la disponibilidad.',
      );
    }
  }

  @override
  void dispose() {
    _motivo.removeListener(_refrescar);
    _motivo.dispose();
    _espaciosSub?.cancel();
    _deportesSub?.cancel();
    _ocupacionesSub?.cancel();
    _reservasSub?.cancel();
    super.dispose();
  }

  DateTime get _inicio => HorarioReservaCaracas.combinar(_dia, _hora);
  DateTime get _fin => _inicio.add(Duration(minutes: _duracionMinutos));

  EspacioDeportivo? get _espacioSeleccionado {
    for (final espacio in _espacios ?? <EspacioDeportivo>[]) {
      if (espacio.id == _espacioId) return espacio;
    }
    return null;
  }

  List<BloqueOcupado>? get _bloques {
    final espacio = _espacioSeleccionado;
    if (espacio == null || _deportes == null || _ocupaciones == null) {
      return null;
    }
    final desde = HorarioReservaCaracas.inicioDelDia(_dia);
    return ValidacionesReserva.consultarOcupaciones(
      espacio: espacio,
      desde: desde,
      hasta: desde.add(const Duration(days: 2)),
      deportes: _deportes!,
      ocupaciones: _ocupaciones!,
    );
  }

  Future<void> _elegirDia() async {
    final caracas = HorarioReservaCaracas.fechaLocal(_ahora());
    final hoy = DateTime(caracas.year, caracas.month, caracas.day);
    final maximo = DateTime(
      hoy.year,
      hoy.month,
      hoy.day + (widget.rol == Rol.estudiante ? 21 : 365),
    );
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia.isBefore(hoy)
          ? hoy
          : (_dia.isAfter(maximo) ? maximo : _dia),
      firstDate: hoy,
      lastDate: maximo,
      helpText: 'Elige el día (hora de Venezuela)',
    );
    if (elegido == null || !mounted) return;
    _dia = elegido;
    _seleccionarEspacio(_espacioId);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Hora de inicio en Venezuela',
    );
    if (elegida != null && mounted) setState(() => _hora = elegida);
  }

  Future<void> _crearReserva() async {
    final repo = _reservasRepo;
    final espacio = _espacioSeleccionado;
    final bloques = _bloques;
    final deportes = _deportes;
    final ocupaciones = _ocupaciones;
    if (_guardando ||
        repo == null ||
        espacio == null ||
        bloques == null ||
        deportes == null ||
        ocupaciones == null) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorSolicitud = null;
    });
    try {
      ValidacionesReserva.validarSolicitud(
        espacio: espacio,
        rol: widget.rol,
        inicio: _inicio,
        fin: _fin,
        ahora: _ahora(),
        motivo: _motivo.text,
        deportes: deportes,
        ocupaciones: ocupaciones,
      );
      await repo.crear(
        espacioId: espacio.id,
        inicio: _inicio,
        fin: _fin,
        motivo: _motivo.text.trim(),
      );
      if (!mounted) return;
      _motivo.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva creada correctamente.')),
      );
    } on ReservaEspacioException catch (error) {
      if (mounted) setState(() => _errorSolicitud = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorSolicitud = 'No se pudo reservar. La disponibilidad pudo cambiar: actualiza y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cancelar(ReservaEspacio reserva) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text(
          '¿Seguro que quieres cancelar esta reserva? El horario volverá a estar disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted || _cancelandoId != null) return;
    setState(() => _cancelandoId = reserva.id);
    try {
      await _reservasRepo!.cancelar(reserva.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada. El horario quedó liberado.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible cancelar. Actualiza y vuelve a intentarlo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final bloques = _bloques;
    final disponibles = _espacios;
    final puedeReservar =
        _uid != null && _reservasRepo != null && bloques != null && !_guardando;
    final duraciones = widget.rol == Rol.estudiante
        ? const [30, 60, 90, 120]
        : const [30, 60, 90, 120, 180, 240, 480];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas de espacios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar disponibilidad',
            icon: const Icon(Icons.refresh),
            onPressed: () => _seleccionarEspacio(_espacioId),
          ),
        ],
      ),
      body:
          _uid == null ||
              _espaciosRepo == null ||
              _deportesRepo == null ||
              _disponibilidadRepo == null ||
              _reservasRepo == null
          ? const Center(
              child: Text('Inicia sesión para consultar y crear reservas.'),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _seleccionarEspacio(_espacioId);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Encuentra un espacio libre',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Horarios expresados en hora de Venezuela (UTC−04). Las clases oficiales y las reservas usan la misma disponibilidad.',
                  ),
                  const SizedBox(height: 16),
                  if (_errorLectura != null) _AvisoReserva(_errorLectura!),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Nueva reserva',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (disponibles == null)
                            const Center(child: CircularProgressIndicator())
                          else if (disponibles.isEmpty)
                            const Text(
                              'No hay instalaciones activas para reservar.',
                            )
                          else
                            DropdownButtonFormField<String>(
                              key: ValueKey('reserva-espacio-$_espacioId'),
                              initialValue: _espacioId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Instalación',
                              ),
                              items: [
                                for (final espacio in disponibles)
                                  DropdownMenuItem(
                                    value: espacio.id,
                                    child: Text(
                                      '${espacio.nombre} · ${espacio.tipo}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _seleccionarEspacio,
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('reserva-fecha'),
                                icon: const Icon(Icons.calendar_month_outlined),
                                onPressed: _elegirDia,
                                label: Text(HorarioReservaCaracas.fecha(_dia)),
                              ),
                              OutlinedButton.icon(
                                key: const Key('reserva-hora'),
                                icon: const Icon(Icons.schedule),
                                onPressed: _elegirHora,
                                label: Text(_hora.format(context)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: const Key('reserva-duracion'),
                            initialValue: _duracionMinutos,
                            decoration: const InputDecoration(
                              labelText: 'Duración',
                            ),
                            items: [
                              for (final minutos in duraciones)
                                DropdownMenuItem(
                                  value: minutos,
                                  child: Text(
                                    minutos < 60
                                        ? '$minutos minutos'
                                        : '${minutos ~/ 60} h ${minutos % 60 == 0 ? '' : '${minutos % 60} min'}'
                                              .trim(),
                                  ),
                                ),
                            ],
                            onChanged: (valor) {
                              if (valor != null) {
                                setState(() => _duracionMinutos = valor);
                              }
                            },
                          ),
                          if (widget.rol == Rol.estudiante)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Estudiantes: máximo 2 horas y 21 días de anticipación.',
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('reserva-motivo'),
                            controller: _motivo,
                            maxLength: 200,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Motivo de la reserva',
                              hintText: 'Ej. Práctica deportiva',
                            ),
                          ),
                          if (_errorSolicitud != null)
                            _AvisoReserva(_errorSolicitud!),
                          const SizedBox(height: 4),
                          FilledButton.icon(
                            key: const Key('confirmar-reserva'),
                            onPressed: puedeReservar ? _crearReserva : null,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.event_available_outlined),
                            label: const Text('Confirmar reserva'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disponibilidad del día y el siguiente',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_errorOcupaciones != null)
                            _AvisoReserva(_errorOcupaciones!)
                          else if (bloques == null)
                            const Text('Cargando clases y reservas existentes…')
                          else if (bloques.isEmpty)
                            const Text(
                              'No hay horarios ocupados para las próximas 48 horas.',
                            )
                          else
                            for (final bloque in bloques)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  bloque.origen == OrigenOcupacion.clase
                                      ? Icons.sports_outlined
                                      : Icons.event_busy_outlined,
                                  color: esquema.primary,
                                ),
                                title: Text(
                                  '${HorarioReservaCaracas.fecha(HorarioReservaCaracas.fechaLocal(bloque.inicio))} · '
                                  '${HorarioReservaCaracas.hora(bloque.inicio)}–${HorarioReservaCaracas.hora(bloque.fin)} · '
                                  '${bloque.origen == OrigenOcupacion.clase ? 'Clase' : 'Reservado'}',
                                ),
                                subtitle: Text(bloque.descripcion),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mis reservas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_errorReservas != null)
                    _AvisoReserva(_errorReservas!)
                  else if (_misReservas == null)
                    const Text('Cargando tus reservas…')
                  else if (_misReservas!.isEmpty)
                    const Text('Todavía no tienes reservas.')
                  else
                    for (final reserva in _misReservas!)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _nombreEspacio(reserva.espacioId),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Chip(
                                    label: Text(
                                      reserva.estaActiva
                                          ? 'Activa'
                                          : 'Cancelada',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${HorarioReservaCaracas.fechaHora(reserva.inicio)} – ${HorarioReservaCaracas.hora(reserva.fin)}',
                              ),
                              Text(reserva.motivo),
                              if (reserva.estaActiva)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    key: Key('cancelar-reserva-${reserva.id}'),
                                    onPressed: _cancelandoId == null
                                        ? () => _cancelar(reserva)
                                        : null,
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('Cancelar reserva'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  String _nombreEspacio(String id) {
    for (final espacio in _espacios ?? <EspacioDeportivo>[]) {
      if (espacio.id == id) return espacio.nombre;
    }
    return 'Instalación $id';
  }
}

class _AvisoReserva extends StatelessWidget {
  const _AvisoReserva(this.mensaje);
  final String mensaje;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      mensaje,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

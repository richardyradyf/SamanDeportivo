import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/entrenador_repository.dart';
import 'package:saman_deportivo/features/admin/entrenadores/domain/gestion_agenda_entrenador.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/entrenador.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Pantalla de A2: horarios y asignaciones usando contratos compartidos.
///
/// Antes de fusionar A1 se prueba con repositorios fake. Tras el merge de
/// A1 se inyecta FirestoreDeporteRepository desde InicioAdminScreen.
class HorariosAdminScreen extends StatefulWidget {
  const HorariosAdminScreen({
    super.key,
    this.deportes,
    this.entrenadores,
    this.agendaGateway,
  });

  final DeporteRepository? deportes;
  final EntrenadorRepository? entrenadores;
  final AgendaMutaciones? agendaGateway;

  @override
  State<HorariosAdminScreen> createState() => _HorariosAdminScreenState();
}

class _HorariosAdminScreenState extends State<HorariosAdminScreen> {
  final _busqueda = TextEditingController();
  late final Stream<List<Deporte>>? _deportes;
  late final Stream<List<Entrenador>>? _entrenadores;
  late final GestionAgendaEntrenador? _gestion;

  @override
  void initState() {
    super.initState();
    _deportes = widget.deportes?.observarCatalogo(soloActivos: false);
    _entrenadores = widget.entrenadores?.observarEntrenadores();
    _gestion = widget.deportes == null
        ? null
        : GestionAgendaEntrenador(
            widget.deportes!,
            mutaciones: widget.agendaGateway,
          );
    _busqueda.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _busqueda.removeListener(_refrescar);
    _busqueda.dispose();
    super.dispose();
  }

  void _informarError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo guardar la agenda: $error')),
    );
  }

  Future<void> _asignar(Deporte deporte, List<Entrenador> entrenadores) async {
    final gestion = _gestion;
    if (gestion == null) {
      return;
    }
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoAsignacion(
        deporte: deporte,
        entrenadores: entrenadores,
        gestion: gestion,
      ),
    );
    if (!mounted || actualizado != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrenador asignado correctamente.')),
    );
  }

  Future<void> _editarHorarios(Deporte deporte) async {
    final gestion = _gestion;
    if (gestion == null) {
      return;
    }
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DialogoHorarios(deporte: deporte, gestion: gestion),
    );
    if (!mounted || actualizado != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Horarios guardados correctamente.')),
    );
  }

  Future<void> _desasignar(Deporte deporte) async {
    final gestion = _gestion;
    if (gestion == null) {
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desasignar entrenador'),
        content: Text(
          '¿Quitar a ${deporte.entrenadorNombre ?? 'este entrenador'} de ${deporte.nombre}? Los horarios se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-desasignacion'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desasignar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) {
      return;
    }
    try {
      await gestion.desasignar(deporte.codigo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrenador desasignado.')));
    } catch (error) {
      _informarError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Horarios', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Gestiona las sesiones y el entrenador asignado a cada deporte.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('buscar-agenda'),
            controller: _busqueda,
            decoration: const InputDecoration(
              labelText: 'Buscar deporte o código',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _deportes == null || _entrenadores == null
                ? const Center(
                    child: Text(
                      'La gestión de agendas se habilitará al integrar A1.',
                    ),
                  )
                : StreamBuilder<List<Deporte>>(
                    stream: _deportes,
                    builder: (context, deportesSnapshot) {
                      if (deportesSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error de deportes: ${deportesSnapshot.error}',
                          ),
                        );
                      }
                      if (!deportesSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return StreamBuilder<List<Entrenador>>(
                        stream: _entrenadores,
                        builder: (context, entrenadoresSnapshot) {
                          if (entrenadoresSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error de entrenadores: ${entrenadoresSnapshot.error}',
                              ),
                            );
                          }
                          if (!entrenadoresSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final termino = normalizarBusqueda(
                            _busqueda.text.trim(),
                          );
                          final deportes =
                              deportesSnapshot.data!
                                  .where(
                                    (d) =>
                                        normalizarBusqueda(d.nombre)
                                            .contains(termino) ||
                                        normalizarBusqueda(d.codigo)
                                            .contains(termino),
                                  )
                                  .toList()
                                ..sort((a, b) => a.nombre.compareTo(b.nombre));
                          if (deportes.isEmpty) {
                            return const Center(
                              child: Text('No hay deportes con ese criterio.'),
                            );
                          }
                          return ListView.separated(
                            itemCount: deportes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final deporte = deportes[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            deporte.nombre,
                                            style: tema.textTheme.titleMedium,
                                          ),
                                          Chip(label: Text(deporte.codigo)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        deporte.entrenadorNombre == null
                                            ? 'Sin entrenador asignado'
                                            : 'Entrenador: ${deporte.entrenadorNombre}',
                                      ),
                                      const SizedBox(height: 8),
                                      if (deporte.horarios.isEmpty)
                                        const Text('Sin sesiones programadas.')
                                      else
                                        for (final horario in deporte.horarios)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '${horario.resumen} · ${horario.lugar}',
                                            ),
                                          ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            key: Key(
                                              'asignar-${deporte.codigo}',
                                            ),
                                            onPressed: () => _asignar(
                                              deporte,
                                              entrenadoresSnapshot.data!,
                                            ),
                                            icon: const Icon(
                                              Icons.person_add_alt_outlined,
                                            ),
                                            label: Text(
                                              deporte.entrenadorUid == null
                                                  ? 'Asignar entrenador'
                                                  : 'Cambiar entrenador',
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            key: Key(
                                              'horarios-${deporte.codigo}',
                                            ),
                                            onPressed: () =>
                                                _editarHorarios(deporte),
                                            icon: const Icon(
                                              Icons.edit_calendar_outlined,
                                            ),
                                            label: const Text(
                                              'Editar horarios',
                                            ),
                                          ),
                                          if (deporte.entrenadorUid != null)
                                            TextButton(
                                              key: Key(
                                                'desasignar-${deporte.codigo}',
                                              ),
                                              onPressed: () =>
                                                  _desasignar(deporte),
                                              child: const Text('Desasignar'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DialogoAsignacion extends StatefulWidget {
  const _DialogoAsignacion({
    required this.deporte,
    required this.entrenadores,
    required this.gestion,
  });

  final Deporte deporte;
  final List<Entrenador> entrenadores;
  final GestionAgendaEntrenador gestion;

  @override
  State<_DialogoAsignacion> createState() => _DialogoAsignacionState();
}

class _DialogoAsignacionState extends State<_DialogoAsignacion> {
  final _formKey = GlobalKey<FormState>();
  String? _seleccionado;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final actual = widget.deporte.entrenadorUid;
    if (widget.entrenadores.any((e) => e.uid == actual)) {
      _seleccionado = actual;
    }
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) {
      return;
    }
    final entrenador = widget.entrenadores
        .where((e) => e.uid == _seleccionado)
        .firstOrNull;
    if (entrenador == null) {
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.gestion.asignar(
        codigoDeporte: widget.deporte.codigo,
        entrenador: entrenador,
        horarios: widget.deporte.horarios,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Asignar entrenador · ${widget.deporte.nombre}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('seleccionar-entrenador'),
                initialValue: _seleccionado,
                decoration: const InputDecoration(labelText: 'Entrenador'),
                items: [
                  for (final entrenador in widget.entrenadores)
                    DropdownMenuItem(
                      value: entrenador.uid,
                      child: Text(entrenador.nombre),
                    ),
                ],
                onChanged: _guardando
                    ? null
                    : (valor) => setState(() => _seleccionado = valor),
                validator: (valor) =>
                    valor == null ? 'Selecciona un entrenador.' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Se validarán los horarios actuales de este deporte con el resto de la agenda del entrenador.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-asignacion'),
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Asignar'),
        ),
      ],
    );
  }
}

class _BorradorHorario {
  _BorradorHorario(HorarioSesion? original)
    : dia = original?.dia ?? DiaSemana.lunes,
      inicio = TextEditingController(text: original?.horaInicio ?? '16:00'),
      fin = TextEditingController(text: original?.horaFin ?? '18:00'),
      lugar = TextEditingController(text: original?.lugar ?? '');

  DiaSemana dia;
  final TextEditingController inicio;
  final TextEditingController fin;
  final TextEditingController lugar;

  HorarioSesion guardar() => HorarioSesion(
    dia: dia,
    horaInicio: inicio.text.trim(),
    horaFin: fin.text.trim(),
    lugar: lugar.text.trim(),
  );

  void dispose() {
    inicio.dispose();
    fin.dispose();
    lugar.dispose();
  }
}

class _DialogoHorarios extends StatefulWidget {
  const _DialogoHorarios({required this.deporte, required this.gestion});

  final Deporte deporte;
  final GestionAgendaEntrenador gestion;

  @override
  State<_DialogoHorarios> createState() => _DialogoHorariosState();
}

class _DialogoHorariosState extends State<_DialogoHorarios> {
  final _formKey = GlobalKey<FormState>();
  final _borradores = <_BorradorHorario>[];
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _borradores.addAll(widget.deporte.horarios.map(_BorradorHorario.new));
  }

  @override
  void dispose() {
    for (final horario in _borradores) {
      horario.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final horarios = _borradores.map((h) => h.guardar()).toList();
      ValidacionesAgendaEntrenador.validarHorarios(horarios);
      await widget.gestion.actualizarHorarios(
        codigoDeporte: widget.deporte.codigo,
        horarios: horarios,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 610, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Horarios · ${widget.deporte.nombre}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      for (var i = 0; i < _borradores.length; i++)
                        _filaHorario(i),
                      OutlinedButton.icon(
                        key: const Key('agregar-sesion'),
                        onPressed: _guardando
                            ? null
                            : () => setState(
                                () => _borradores.add(_BorradorHorario(null)),
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar sesión'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('guardar-horarios'),
                    onPressed: _guardando ? null : _guardar,
                    child: Text(_guardando ? 'Guardando…' : 'Guardar horarios'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaHorario(int indice) {
    final horario = _borradores[indice];
    return Padding(
      key: ValueKey(horario),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DiaSemana>(
                  initialValue: horario.dia,
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: [
                    for (final dia in DiaSemana.values)
                      DropdownMenuItem(value: dia, child: Text(dia.etiqueta)),
                  ],
                  onChanged: _guardando
                      ? null
                      : (dia) {
                          if (dia != null) {
                            setState(() => horario.dia = dia);
                          }
                        },
                ),
              ),
              IconButton(
                key: Key('eliminar-sesion-$indice'),
                tooltip: 'Eliminar sesión',
                onPressed: _guardando
                    ? null
                    : () => setState(() {
                        final eliminado = _borradores.removeAt(indice);
                        // El controlador debe sobrevivir a este frame.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          eliminado.dispose();
                        });
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('inicio-$indice'),
                  controller: horario.inicio,
                  decoration: const InputDecoration(
                    labelText: 'Inicio (HH:mm)',
                  ),
                  validator: (valor) =>
                      _horaCorrecta(valor) ? null : 'Hora inválida (HH:mm)',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: Key('fin-$indice'),
                  controller: horario.fin,
                  decoration: const InputDecoration(labelText: 'Fin (HH:mm)'),
                  validator: (valor) =>
                      _horaCorrecta(valor) ? null : 'Hora inválida (HH:mm)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: Key('lugar-$indice'),
            controller: horario.lugar,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Lugar'),
            validator: (valor) => (valor ?? '').trim().isNotEmpty
                ? null
                : 'Indica un lugar de entrenamiento.',
          ),
        ],
      ),
    );
  }

  static bool _horaCorrecta(String? hora) =>
      RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')
          .hasMatch((hora ?? '').trim());
}

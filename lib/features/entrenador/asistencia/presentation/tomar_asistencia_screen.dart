import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:saman_deportivo/features/entrenador/widgets/con_deporte.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/conversiones.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

/// Toma de asistencia (RF-14): presentes y ausentes de una sesión.
class TomarAsistenciaScreen extends StatelessWidget {
  const TomarAsistenciaScreen({
    super.key,
    required this.deportes,
    required this.confirmadas,
    required this.asistencias,
    required this.entrenadorUid,
    this.hoy,
  });

  final Stream<List<Deporte>> deportes;
  final ConfirmadasDeDeporte confirmadas;
  final AsistenciaRepository asistencias;
  final String entrenadorUid;

  /// De dónde sale la fecha por defecto. En las pruebas se pasa una fija.
  final DateTime Function()? hoy;

  @override
  Widget build(BuildContext context) {
    return ConDeporte(
      deportes: deportes,
      builder: (context, deporte) => _Sesion(
        deporte: deporte,
        confirmadas: confirmadas,
        asistencias: asistencias,
        entrenadorUid: entrenadorUid,
        dia: soloDia((hoy ?? DateTime.now)()),
      ),
    );
  }
}

class _Sesion extends StatefulWidget {
  const _Sesion({
    required this.deporte,
    required this.confirmadas,
    required this.asistencias,
    required this.entrenadorUid,
    required this.dia,
  });

  final Deporte deporte;
  final ConfirmadasDeDeporte confirmadas;
  final AsistenciaRepository asistencias;
  final String entrenadorUid;
  final DateTime dia;

  @override
  State<_Sesion> createState() => _SesionState();
}

class _SesionState extends State<_Sesion> {
  late final Stream<List<Inscripcion>> _inscritos =
      widget.confirmadas(widget.deporte.codigo);
  late DateTime _dia = widget.dia;
  // Sin valor significa que el entrenador TODAVÍA no verificó al estudiante.
  Map<String, EstadoAsistencia> _marcados = {};
  bool _guardando = false;
  bool _cargandoPrevios = true;

  DateTime get _siguiente => DateTime(_dia.year, _dia.month, _dia.day + 1);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _aviso(String mensaje) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  /// Si ya hay asistencia de ese día, se carga para poder corregirla.
  Future<void> _cargar() async {
    final dia = _dia;
    if (!_cargandoPrevios) {
      setState(() => _cargandoPrevios = true);
    }
    try {
      final previos = await widget.asistencias
          .observarDeDeporte(widget.deporte.codigo, desde: dia, hasta: _siguiente)
          .first;
      if (!mounted || dia != _dia) return;
      setState(() {
        _marcados = {for (final a in previos) a.estudianteUid: a.estado};
        _cargandoPrevios = false;
      });
    } catch (_) {
      if (!mounted || dia != _dia) return;
      setState(() => _cargandoPrevios = false);
      _aviso('No se pudo cargar la asistencia de ese día.');
    }
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (fecha == null) return;
    setState(() {
      _dia = soloDia(fecha);
      _marcados = {};
    });
    _cargar();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Una consulta nueva: la lista de la pantalla ya está escuchando la otra.
      final inscritos = await widget.confirmadas(widget.deporte.codigo).first;
      if (inscritos.isEmpty ||
          inscritos.any((i) => !_marcados.containsKey(i.estudianteUid))) {
        if (mounted) {
          _aviso('Debes marcar presente o ausente a cada estudiante.');
        }
        return;
      }
      await widget.asistencias.guardarSesion([
        for (final i in inscritos)
          Asistencia.registrar(
            inscripcionId: i.id,
            estudianteUid: i.estudianteUid,
            estudianteNombre: i.estudianteNombre,
            deporteId: widget.deporte.codigo,
            entrenadorUid: widget.entrenadorUid,
            fecha: _dia,
            estado: _marcados[i.estudianteUid]!,
          ),
      ]);
      if (mounted) _aviso('Asistencia guardada.');
    } catch (_) {
      if (mounted) _aviso('No se pudo guardar la asistencia. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Inscripcion>>(
      stream: _inscritos,
      builder: (context, snapshot) {
        final lista = [...?snapshot.data]
          ..sort((a, b) => a.estudianteNombre.compareTo(b.estudianteNombre));
        final marcados = lista
            .where((i) => _marcados.containsKey(i.estudianteUid))
            .length;
        final todosMarcados = lista.isNotEmpty && marcados == lista.length;

        // La lista y el botón comparten el mismo scroll: con pocos alumnos,
        // «Guardar asistencia» queda justo debajo, no al fondo de la pantalla.
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('dd/MM/yyyy').format(_dia)),
              trailing: TextButton(
                onPressed: _elegirFecha,
                child: const Text('Cambiar fecha'),
              ),
            ),
            if (snapshot.hasError)
              const Text('No se pudo cargar la lista.')
            else if (!snapshot.hasData || _cargandoPrevios)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No hay inscritos confirmados.'),
              )
            else ...[
              Text(
                'Verifica a cada estudiante y marca presente o ausente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$marcados de ${lista.length} estudiantes verificados',
                key: const Key('asistencia-progreso'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              for (final i in lista)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.estudianteNombre,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<EstadoAsistencia>(
                          key: Key('asistencia-estado-${i.estudianteUid}'),
                          showSelectedIcon: false,
                          emptySelectionAllowed: true,
                          segments: const [
                            ButtonSegment(
                              value: EstadoAsistencia.presente,
                              label: Text('Presente'),
                            ),
                            ButtonSegment(
                              value: EstadoAsistencia.ausente,
                              label: Text('Ausente'),
                            ),
                          ],
                          selected: _marcados[i.estudianteUid] == null
                              ? <EstadoAsistencia>{}
                              : {_marcados[i.estudianteUid]!},
                          onSelectionChanged: (elegidos) => setState(() {
                            if (elegidos.isEmpty) {
                              _marcados.remove(i.estudianteUid);
                            } else {
                              _marcados[i.estudianteUid] = elegidos.first;
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando || !todosMarcados ? null : _guardar,
                  child: Text(
                    _guardando ? 'Guardando asistencia...' : 'Guardar asistencia',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

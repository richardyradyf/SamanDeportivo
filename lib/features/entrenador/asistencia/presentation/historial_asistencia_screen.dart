import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:saman_deportivo/features/entrenador/asistencia/domain/resumen_asistencia.dart';
import 'package:saman_deportivo/features/entrenador/widgets/con_deporte.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

/// Historial de asistencia (RF-14): por período y por estudiante, con porcentaje.
class HistorialAsistenciaScreen extends StatelessWidget {
  const HistorialAsistenciaScreen({
    super.key,
    required this.deportes,
    required this.asistencias,
    this.hoy,
  });

  final Stream<List<Deporte>> deportes;
  final AsistenciaRepository asistencias;

  /// De dónde sale la fecha por defecto. En las pruebas se pasa una fija.
  final DateTime Function()? hoy;

  @override
  Widget build(BuildContext context) {
    return ConDeporte(
      deportes: deportes,
      builder: (context, deporte) => _Historial(
        deporte: deporte,
        asistencias: asistencias,
        hoy: (hoy ?? DateTime.now)(),
      ),
    );
  }
}

class _Historial extends StatefulWidget {
  const _Historial({
    required this.deporte,
    required this.asistencias,
    required this.hoy,
  });

  final Deporte deporte;
  final AsistenciaRepository asistencias;
  final DateTime hoy;

  @override
  State<_Historial> createState() => _HistorialState();
}

class _HistorialState extends State<_Historial> {
  PeriodoHistorial _periodo = PeriodoHistorial.semana;
  late DateTime _ref = widget.hoy;
  String _estudiante = ''; // vacío = todos
  late Stream<List<Asistencia>> _stream = _consulta();

  Stream<List<Asistencia>> _consulta() {
    final r = _periodo.rango(_ref);
    return widget.asistencias.observarDeDeporte(
      widget.deporte.codigo,
      desde: r.desde,
      hasta: r.hasta,
    );
  }

  void _cambiar({PeriodoHistorial? periodo, DateTime? ref}) => setState(() {
        _periodo = periodo ?? _periodo;
        _ref = ref ?? _ref;
        _estudiante = '';
        _stream = _consulta();
      });

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _ref,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (fecha != null) _cambiar(ref: fecha);
  }

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('dd/MM/yyyy');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<PeriodoHistorial>(
            segments: [
              for (final p in PeriodoHistorial.values)
                ButtonSegment(value: p, label: Text(p.etiqueta)),
            ],
            selected: {_periodo},
            onSelectionChanged: (s) => _cambiar(periodo: s.first),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: Text(formato.format(_ref)),
          trailing: TextButton(
            onPressed: _elegirFecha,
            child: const Text('Cambiar fecha'),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Asistencia>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('No se pudo cargar el historial.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final todos = snapshot.data!;
              if (todos.isEmpty) {
                return const Center(child: Text('No hay registros en este período.'));
              }
              final nombres = {for (final a in todos) a.estudianteUid: a.estudianteNombre};
              final elegido = nombres.containsKey(_estudiante) ? _estudiante : '';
              final lista = todos
                  .where((a) => elegido.isEmpty || a.estudianteUid == elegido)
                  .toList()
                ..sort((a, b) => b.fecha.compareTo(a.fecha));
              final presentes = lista.where((a) => a.estuvoPresente).length;
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    value: elegido,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todos los estudiantes'),
                      ),
                      for (final e in nombres.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _estudiante = v ?? ''),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Asistencia: ${porcentajeAsistencia(lista)}% '
                      '($presentes de ${lista.length} registros)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final a in lista)
                    ListTile(
                      title: Text(a.estudianteNombre),
                      subtitle: Text(formato.format(a.fecha)),
                      trailing: Chip(label: Text(a.estado.etiqueta)),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
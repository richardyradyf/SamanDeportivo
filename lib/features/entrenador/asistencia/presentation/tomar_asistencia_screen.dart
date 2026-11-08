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
  Map<String, bool> _presentes = {};
  bool _guardando = false;

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
    try {
      final previos = await widget.asistencias
          .observarDeDeporte(widget.deporte.codigo, desde: dia, hasta: _siguiente)
          .first;
      if (!mounted || dia != _dia) return;
      setState(() => _presentes = {
            for (final a in previos) a.estudianteUid: a.estuvoPresente,
          });
    } catch (_) {
      if (mounted) _aviso('No se pudo cargar la asistencia de ese día.');
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
      _presentes = {};
    });
    _cargar();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Una consulta nueva: la lista de la pantalla ya está escuchando la otra.
      final inscritos = await widget.confirmadas(widget.deporte.codigo).first;
      await widget.asistencias.guardarSesion([
        for (final i in inscritos)
          Asistencia.registrar(
            inscripcionId: i.id,
            estudianteUid: i.estudianteUid,
            estudianteNombre: i.estudianteNombre,
            deporteId: widget.deporte.codigo,
            entrenadorUid: widget.entrenadorUid,
            fecha: _dia,
            estado: _presentes[i.estudianteUid] == true
                ? EstadoAsistencia.presente
                : EstadoAsistencia.ausente,
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
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.event),
          title: Text(DateFormat('dd/MM/yyyy').format(_dia)),
          trailing: TextButton(
            onPressed: _elegirFecha,
            child: const Text('Cambiar fecha'),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Inscripcion>>(
            stream: _inscritos,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('No se pudo cargar la lista.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = [...snapshot.data!]
                ..sort((a, b) => a.estudianteNombre.compareTo(b.estudianteNombre));
              if (lista.isEmpty) {
                return const Center(child: Text('No hay inscritos confirmados.'));
              }
              return ListView(
                children: [
                  for (final i in lista)
                    SwitchListTile(
                      title: Text(i.estudianteNombre),
                      subtitle: Text(
                        _presentes[i.estudianteUid] == true ? 'Presente' : 'Ausente',
                      ),
                      value: _presentes[i.estudianteUid] ?? false,
                      onChanged: (v) =>
                          setState(() => _presentes[i.estudianteUid] = v),
                    ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: const Text('Guardar asistencia'),
            ),
          ),
        ),
      ],
    );
  }
}
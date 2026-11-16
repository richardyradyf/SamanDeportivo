import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/dashboard/data/firestore_asistencia_admin_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';
import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Asistencia administrativa: total y desglose por deporte en una ventana
/// móvil de tres meses, ajustada al día de creación de cada deporte.
class PanelAsistenciaAdmin extends StatefulWidget {
  const PanelAsistenciaAdmin({
    super.key,
    this.consultar,
    this.deportes,
    this.ahora,
  });

  /// Inyectables para pruebas y para evitar inicializar Firebase en widgets.
  final ConsultarAsistenciaAdmin? consultar;
  final Stream<List<Deporte>>? deportes;
  final DateTime Function()? ahora;

  @override
  State<PanelAsistenciaAdmin> createState() => _PanelAsistenciaAdminState();
}

class _PanelAsistenciaAdminState extends State<PanelAsistenciaAdmin> {
  // Cero representa los últimos tres meses de calendario (no 90 días).
  int _dias = 0;
  String? _deporteId;
  Stream<LecturaAsistenciaAdmin>? _fuente;
  Stream<List<Deporte>>? _catalogo;
  late DateTime _desde;
  late DateTime _hasta;

  @override
  void initState() {
    super.initState();
    _conectar();
  }

  @override
  void didUpdateWidget(covariant PanelAsistenciaAdmin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consultar != widget.consultar ||
        oldWidget.deportes != widget.deportes ||
        oldWidget.ahora != widget.ahora) {
      _conectar();
    }
  }

  void _conectar() {
    final consultar =
        widget.consultar ??
        (Firebase.apps.isNotEmpty
            ? FirestoreAsistenciaAdminRepository().observar
            : null);
    final hoy = widget.ahora?.call() ?? DateTime.now();
    _hasta = DateTime(hoy.year, hoy.month, hoy.day + 1);
    _desde = _dias == 0
        ? ResumenAsistenciaAdmin.inicioTresMeses(hoy)
        : _hasta.subtract(Duration(days: _dias));

    _fuente = consultar?.call(_desde, _hasta);
    _catalogo = widget.deportes ??
        (Firebase.apps.isNotEmpty
            ? FirestoreDeporteRepository().observarCatalogo(soloActivos: false)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Asistencia promedio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  key: const Key('h3-asistencia-periodo'),
                  value: _dias,
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Últimos 3 meses'),
                    ),
                    DropdownMenuItem(value: 7, child: Text('Últimos 7 días')),
                    DropdownMenuItem(value: 30, child: Text('Últimos 30 días')),
                    DropdownMenuItem(value: 90, child: Text('Últimos 90 días')),
                  ],
                  onChanged: (dias) {
                    if (dias == null) return;
                    setState(() {
                      _dias = dias;
                      _deporteId = null;
                      _conectar();
                    });
                  },
                ),
                const Text('Porcentaje de registros presentes'),
              ],
            ),
            const SizedBox(height: 12),
            if (_fuente == null)
              const Text(
                'Fuente no conectada: inicia Firebase para consultar asistencias.',
                key: Key('h3-asistencia-no-conectada'),
              )
            else
              StreamBuilder<LecturaAsistenciaAdmin>(
                stream: _fuente,
                builder: (context, estado) {
                  if (estado.hasError) {
                    return const Text(
                      'No se pudo consultar la asistencia. Revisa los permisos y la conexión.',
                      key: Key('h3-asistencia-error'),
                    );
                  }
                  if (!estado.hasData) {
                    return const LinearProgressIndicator();
                  }

                  return StreamBuilder<List<Deporte>>(
                    stream: _catalogo,
                    builder: (context, deportesEstado) {
                      if (deportesEstado.hasError) {
                        return const Text(
                          'No se pudo consultar el catálogo de deportes.',
                          key: Key('h4-asistencia-error-deportes'),
                        );
                      }
                      if (_catalogo != null && !deportesEstado.hasData) {
                        return const LinearProgressIndicator();
                      }
                      return _construirResumen(
                        context,
                        estado.data!,
                        deportesEstado.data ?? const <Deporte>[],
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirResumen(
    BuildContext context,
    LecturaAsistenciaAdmin lectura,
    List<Deporte> catalogo,
  ) {
    final nombres = <String, String>{
      for (final deporte in catalogo) deporte.codigo: deporte.nombre,
    };
    final fechasDeCreacion = <String, DateTime>{
      for (final deporte in catalogo) deporte.codigo: deporte.creadoEn,
    };

    // Conserva identificadores históricos, aunque el deporte no esté en el
    // catálogo actual. Los deportes nuevos sin asistencias también aparecen.
    for (final registro in lectura.registros) {
      nombres.putIfAbsent(registro.deporteId, () => registro.deporteId);
    }
    final ids = nombres.keys.toList()
      ..sort((a, b) {
        final porNombre = nombres[a]!.compareTo(nombres[b]!);
        return porNombre == 0 ? a.compareTo(b) : porNombre;
      });

    final seleccionado = ids.contains(_deporteId) ? _deporteId : null;
    ResumenAsistenciaAdmin calcular(String? id) =>
        ResumenAsistenciaAdmin.calcular(
          lectura.registros,
          deporteId: id,
          desde: _desde,
          hasta: _hasta,
          creadoEnPorDeporte: fechasDeCreacion,
        );
    final resumen = calcular(seleccionado);
    final resumenTotal = calcular(null);
    final resumenesPorDeporte = <String, ResumenAsistenciaAdmin>{
      for (final id in ids) id: calcular(id),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String?>(
          key: const Key('h3-asistencia-deporte'),
          isExpanded: true,
          value: seleccionado,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos los deportes'),
            ),
            ...ids.map(
              (id) => DropdownMenuItem<String?>(
                value: id,
                child: Text(nombres[id] == id ? id : '${nombres[id]} ($id)'),
              ),
            ),
          ],
          onChanged: (id) => setState(() => _deporteId = id),
        ),
        if (lectura.omitidos > 0)
          Text(
            'Se omitieron ${lectura.omitidos} registros con datos inválidos.',
            key: const Key('h3-asistencia-omitidos'),
          ),
        const SizedBox(height: 6),
        Text(
          '${resumen.porcentaje.toStringAsFixed(1)}%',
          key: const Key('h3-asistencia-porcentaje'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text('Presentes: ${resumen.presentes}'),
        Text('Ausentes: ${resumen.ausentes}'),
        Text('Total de registros: ${resumen.total}'),
        if (resumen.total == 0)
          const Text(
            'Sin registros en este período; se muestra 0 %.',
            key: Key('h3-asistencia-sin-datos'),
          ),
        if (seleccionado != null)
          Text(
            'Asistencia total de todos los deportes: '
            '${resumenTotal.porcentaje.toStringAsFixed(1)}%',
            key: const Key('h4-asistencia-total'),
          ),
        const SizedBox(height: 18),
        Text(
          'Asistencia por deporte',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (ids.isEmpty)
          const Text('Aún no hay deportes registrados.')
        else
          for (final id in ids) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                key: Key('h4-asistencia-deporte-$id'),
                children: [
                  Expanded(
                    child: Text(
                      nombres[id] == id ? id : '${nombres[id]} · $id',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${resumenesPorDeporte[id]!.porcentaje.toStringAsFixed(1)}% '
                    '(${resumenesPorDeporte[id]!.total} registros)',
                  ),
                ],
              ),
            ),
          ],
        const SizedBox(height: 10),
        const Text(
          'El período de cada deporte comienza como máximo en su fecha de '
          'creación. La métrica cuenta registros de sesiones, no estudiantes '
          'únicos. Un deporte sin registros muestra 0 %.',
        ),
      ],
    );
  }
}

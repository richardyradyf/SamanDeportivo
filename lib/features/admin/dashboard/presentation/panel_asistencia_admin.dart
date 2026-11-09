import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/dashboard/data/firestore_asistencia_admin_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';

/// Indicador del RF-18: asistencia promedio por período y deporte.
/// Usa una fuente independiente para no ocultar los errores de Firestore.
class PanelAsistenciaAdmin extends StatefulWidget {
  const PanelAsistenciaAdmin({super.key, this.consultar});

  /// Inyectable en pruebas, sin inicializar Firebase.
  final ConsultarAsistenciaAdmin? consultar;

  @override
  State<PanelAsistenciaAdmin> createState() => _PanelAsistenciaAdminState();
}

class _PanelAsistenciaAdminState extends State<PanelAsistenciaAdmin> {
  int _dias = 30;
  String? _deporteId;
  Stream<LecturaAsistenciaAdmin>? _fuente;

  @override
  void initState() {
    super.initState();
    _conectar();
  }

  @override
  void didUpdateWidget(covariant PanelAsistenciaAdmin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consultar != widget.consultar) _conectar();
  }

  void _conectar() {
    final consultar =
        widget.consultar ??
        (Firebase.apps.isNotEmpty
            ? FirestoreAsistenciaAdminRepository().observar
            : null);
    if (consultar == null) {
      _fuente = null;
      return;
    }

    final hoy = DateTime.now();
    // Al final del día actual (exclusivo): períodos de días completos.
    final hasta = DateTime(hoy.year, hoy.month, hoy.day + 1);
    final desde = hasta.subtract(Duration(days: _dias));
    _fuente = consultar(desde, hasta);
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  key: const Key('h3-asistencia-periodo'),
                  value: _dias,
                  items: const [
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

                  final lectura = estado.data!;
                  final deportes =
                      lectura.registros
                          .map((registro) => registro.deporteId)
                          .toSet()
                          .toList()
                        ..sort();
                  final seleccionado = deportes.contains(_deporteId)
                      ? _deporteId
                      : null;
                  final resumen = ResumenAsistenciaAdmin.calcular(
                    lectura.registros,
                    deporteId: seleccionado,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<String?>(
                        key: const Key('h3-asistencia-deporte'),
                        value: seleccionado,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los deportes'),
                          ),
                          ...deportes.map(
                            (id) => DropdownMenuItem<String?>(
                              value: id,
                              child: Text(id),
                            ),
                          ),
                        ],
                        onChanged: (id) => setState(() => _deporteId = id),
                      ),
                      const SizedBox(height: 8),
                      if (lectura.omitidos > 0)
                        Text(
                          'Se omitieron ${lectura.omitidos} registros con datos inválidos.',
                          key: const Key('h3-asistencia-omitidos'),
                        ),
                      if (resumen.porcentaje == null)
                        const Text(
                          'No hay asistencias válidas registradas en este período.',
                          key: Key('h3-asistencia-sin-datos'),
                        )
                      else ...[
                        Text(
                          '${resumen.porcentaje!.toStringAsFixed(1)}%',
                          key: const Key('h3-asistencia-porcentaje'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Presentes: ${resumen.presentes}'),
                        Text('Ausentes: ${resumen.ausentes}'),
                        Text('Total de registros: ${resumen.total}'),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'La métrica cuenta registros de sesiones, no estudiantes únicos.',
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

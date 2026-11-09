import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/data/firestore_inscripcion_repository.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

/// Consulta administrativa de inscripciones. No modifica estados ni cupos.
/// [flujo] facilita pruebas de widgets sin inicializar Firebase.
class InscripcionesAdminScreen extends StatefulWidget {
  const InscripcionesAdminScreen({super.key, this.flujo});

  final Stream<List<Inscripcion>>? flujo;

  @override
  State<InscripcionesAdminScreen> createState() =>
      _InscripcionesAdminScreenState();
}

class _InscripcionesAdminScreenState extends State<InscripcionesAdminScreen> {
  Stream<List<Inscripcion>>? _inscripciones;
  String _busqueda = '';
  EstadoInscripcion? _estado;

  @override
  void initState() {
    super.initState();
    _conectar();
  }

  @override
  void didUpdateWidget(covariant InscripcionesAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flujo != widget.flujo) _conectar();
  }

  void _conectar() {
    _inscripciones =
        widget.flujo ??
        (Firebase.apps.isEmpty
            ? null
            : FirestoreInscripcionRepository().observarTodas());
  }

  List<Inscripcion> _filtrar(List<Inscripcion> inscripciones) {
    final busqueda = _busqueda.trim().toLowerCase();
    return inscripciones.where((inscripcion) {
      if (_estado != null && inscripcion.estado != _estado) return false;
      if (busqueda.isEmpty) return true;
      final texto = [
        inscripcion.estudianteNombre,
        inscripcion.estudianteCedula,
        inscripcion.estudianteCarnet,
        inscripcion.deporteNombre,
        inscripcion.deporteId,
      ].join(' ').toLowerCase();
      return texto.contains(busqueda);
    }).toList();
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inscripciones deportivas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Consulta administrativa de estudiantes, deportes y estados. '
            'Solo lectura: no modifica reservas ni pagos.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 340
                      ? constraints.maxWidth
                      : 340,
                  child: TextField(
                    key: const Key('ins-admin-busqueda'),
                    decoration: const InputDecoration(
                      labelText:
                          'Buscar por estudiante, cédula, carnet o deporte',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (valor) => setState(() => _busqueda = valor),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth < 230
                      ? constraints.maxWidth
                      : 230,
                  child: DropdownButton<EstadoInscripcion?>(
                    key: const Key('ins-admin-estado'),
                    isExpanded: true,
                    value: _estado,
                    items: [
                      const DropdownMenuItem<EstadoInscripcion?>(
                        value: null,
                        child: Text('Todos los estados'),
                      ),
                      ...EstadoInscripcion.values.map(
                        (estado) => DropdownMenuItem<EstadoInscripcion?>(
                          value: estado,
                          child: Text(estado.etiqueta),
                        ),
                      ),
                    ],
                    onChanged: (valor) => setState(() => _estado = valor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _inscripciones == null
                ? const Center(child: Text('Firebase no está inicializado.'))
                : StreamBuilder<List<Inscripcion>>(
                    stream: _inscripciones,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'No se pudieron consultar las inscripciones. '
                            'Revisa los permisos de administrador.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final resultados = _filtrar(snapshot.data!);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${resultados.length} ${resultados.length == 1 ? 'inscripción encontrada' : 'inscripciones encontradas'}',
                            key: const Key('ins-admin-total'),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: resultados.isEmpty
                                ? Center(
                                    child: Text(
                                      snapshot.data!.isEmpty
                                          ? 'No hay inscripciones registradas.'
                                          : 'No hay resultados para los filtros seleccionados.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: resultados.length,
                                    itemBuilder: (context, index) {
                                      final inscripcion = resultados[index];
                                      return Card(
                                        key: Key(
                                          'ins-admin-registro-${inscripcion.id}',
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                inscripcion.estudianteNombre,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Deporte: ${inscripcion.deporteNombre} '
                                                '(${inscripcion.deporteId})',
                                              ),
                                              Text(
                                                'Cédula: ${inscripcion.estudianteCedula}',
                                              ),
                                              Text(
                                                'Carnet: ${inscripcion.estudianteCarnet}',
                                              ),
                                              Text(
                                                'Estado: ${inscripcion.estado.etiqueta}',
                                              ),
                                              Text(
                                                'Fecha: ${_fecha(inscripcion.fechaInscripcion)}',
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

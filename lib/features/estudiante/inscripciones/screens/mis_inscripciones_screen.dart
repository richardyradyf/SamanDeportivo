import 'package:flutter/material.dart';

import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

class MisInscripcionesScreen extends StatelessWidget {
  const MisInscripcionesScreen({
    super.key,
    this.inscripciones = const [],
    this.inscripcionesStream,
    this.onCancelar,
    this.onCancelarInscripcion,
  });

  /// Lista de inscripciones utilizada cuando no se recibe un Stream.
  final List<Inscripcion> inscripciones;

  /// Flujo de inscripciones del estudiante autenticado.
  final Stream<List<Inscripcion>>? inscripcionesStream;

  /// Acción para solicitar una cancelación.
  final ValueChanged<Inscripcion>? onCancelar;

  /// Nombre alternativo utilizado por InicioEstudianteScreen.
  final ValueChanged<Inscripcion>? onCancelarInscripcion;

  Color obtenerColor(EstadoInscripcion estado) {
    switch (estado) {
      case EstadoInscripcion.pendiente:
        return Colors.orange;
      case EstadoInscripcion.confirmada:
        return Colors.green;
      case EstadoInscripcion.rechazada:
        return Colors.red;
      case EstadoInscripcion.cancelada:
        return Colors.red;
      case EstadoInscripcion.expirada:
        return Colors.grey;
    }
  }

  String formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mis inscripciones',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Consulta el estado de tus inscripciones deportivas.'),
          const SizedBox(height: 24),
          Expanded(
            child: inscripcionesStream == null
                ? _construirContenido(context, inscripciones)
                : StreamBuilder<List<Inscripcion>>(
                    stream: inscripcionesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'No se pudieron cargar tus inscripciones.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return _construirContenido(context, snapshot.data!);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _construirContenido(BuildContext context, List<Inscripcion> datos) {
    if (datos.isEmpty) {
      return _construirEstadoVacio(context);
    }

    return ListView.builder(
      itemCount: datos.length,
      itemBuilder: (context, index) {
        return _construirTarjeta(datos[index]);
      },
    );
  }

  Widget _construirEstadoVacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 65,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tienes inscripciones registradas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando te inscribas en una disciplina, '
            'podrás consultar su estado aquí.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _construirTarjeta(Inscripcion inscripcion) {
    final cancelar = onCancelarInscripcion ?? onCancelar;

    final puedeCancelar = inscripcion.ocupaCupo && cancelar != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inscripcion.deporteNombre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Código: ${inscripcion.deporteId}'),
            const SizedBox(height: 8),
            Text('Inscripción: ${inscripcion.id}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Estado: '),
                Text(
                  inscripcion.estado.etiqueta,
                  style: TextStyle(
                    color: obtenerColor(inscripcion.estado),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fecha de inscripción: '
              '${formatearFecha(inscripcion.fechaInscripcion)}',
            ),
            if (inscripcion.estado == EstadoInscripcion.pendiente) ...[
              const SizedBox(height: 8),
              Text(
                'Fecha límite de pago: '
                '${formatearFecha(inscripcion.fechaLimitePago)}',
              ),
            ],
            if (inscripcion.motivo != null &&
                inscripcion.motivo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motivo: ${inscripcion.motivo}'),
            ],
            if (inscripcion.ocupaCupo) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: puedeCancelar ? () => cancelar(inscripcion) : null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar inscripción'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

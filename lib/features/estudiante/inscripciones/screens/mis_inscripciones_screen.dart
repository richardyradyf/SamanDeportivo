import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/inscripciones/models/inscripcion_local.dart';

class MisInscripcionesScreen extends StatelessWidget {
  const MisInscripcionesScreen({
    super.key,
    this.inscripciones = const [],
    this.onCancelar,
  });

  final List<InscripcionLocal> inscripciones;
  final ValueChanged<InscripcionLocal>? onCancelar;

  String obtenerEstado(EstadoInscripcion estado) {
    switch (estado) {
      case EstadoInscripcion.pendiente:
        return 'Pendiente';
      case EstadoInscripcion.confirmada:
        return 'Confirmada';
      case EstadoInscripcion.cancelada:
        return 'Cancelada';
      case EstadoInscripcion.expirada:
        return 'Expirada';
    }
  }

  Color obtenerColor(EstadoInscripcion estado) {
    switch (estado) {
      case EstadoInscripcion.pendiente:
        return Colors.orange;
      case EstadoInscripcion.confirmada:
        return Colors.green;
      case EstadoInscripcion.cancelada:
        return Colors.red;
      case EstadoInscripcion.expirada:
        return Colors.grey;
    }
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
            child: inscripciones.isEmpty
                ? _construirEstadoVacio(context)
                : _construirLista(),
          ),
        ],
      ),
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
            'podras consultar su estado aqui.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _construirLista() {
    return ListView.builder(
      itemCount: inscripciones.length,
      itemBuilder: (context, index) {
        final inscripcion = inscripciones[index];
        final puedeCancelar = inscripcion.estaVigente && onCancelar != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deporte: ${inscripcion.deporteId}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Inscripcion: ${inscripcion.id}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Estado: '),
                    Text(
                      obtenerEstado(inscripcion.estado),
                      style: TextStyle(
                        color: obtenerColor(inscripcion.estado),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (inscripcion.estaVigente)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: puedeCancelar
                          ? () => onCancelar!(inscripcion)
                          : null,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar inscripcion'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

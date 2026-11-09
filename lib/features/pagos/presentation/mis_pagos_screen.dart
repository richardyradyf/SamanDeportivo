import 'package:flutter/material.dart';

import '../../../models/pago.dart';
import '../../../repositories/pago_repository.dart';

class MisPagosScreen extends StatelessWidget {
  const MisPagosScreen({
    super.key,
    required this.repositorio,
    required this.estudianteUid,
  });

  final PagoRepository repositorio;
  final String estudianteUid;

  static String _fecha(DateTime f) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: StreamBuilder<List<Pago>>(
        stream: repositorio.observarDeEstudiante(estudianteUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar tus pagos.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pagos = snapshot.data!;
          if (pagos.isEmpty) {
            return const Center(child: Text('Todavía no tienes pagos.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pagos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _TarjetaPago(pago: pagos[index]),
          );
        },
      ),
    );
  }
}

class _TarjetaPago extends StatelessWidget {
  const _TarjetaPago({required this.pago});

  final Pago pago;

  @override
  Widget build(BuildContext context) {
    final captura = pago.paypalCaptureId;
    return Card(
      child: ListTile(
        title: Text(pago.deporteNombre),
        subtitle: Text([
          '${pago.monto.toStringAsFixed(2)} ${pago.moneda} · ${MisPagosScreen._fecha(pago.fecha)}',
          if (captura != null) 'Comprobante: $captura',
        ].join('\n')),
        isThreeLine: captura != null,
        trailing: Chip(label: Text(pago.estado.etiqueta)),
      ),
    );
  }
}
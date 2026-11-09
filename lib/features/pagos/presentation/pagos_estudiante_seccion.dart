import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/inscripciones/data/firestore_inscripcion_repository.dart';
import 'package:saman_deportivo/features/pagos/data/firestore_pago_repository.dart';
import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';
import 'package:saman_deportivo/features/pagos/presentation/mis_pagos_screen.dart';
import 'package:saman_deportivo/features/pagos/presentation/pagar_inscripcion_screen.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/pago_repository.dart';

/// Pagos del estudiante: inscripciones por pagar y su historial.
class PagosEstudianteSeccion extends StatefulWidget {
  const PagosEstudianteSeccion({
    super.key,
    required this.estudianteUid,
    required this.pagos,
    required this.pendientes,
    required this.confirmar,
    this.costoDe,
    this.construirVista,
  });

  /// Versión con Firebase real.
  factory PagosEstudianteSeccion.firebase(String uid) {
    final db = FirebaseFirestore.instance;
    final inscripciones = FirestoreInscripcionRepository(firestore: db);
    return PagosEstudianteSeccion(
      estudianteUid: uid,
      pagos: FirestorePagoRepository(db),
      pendientes: () => db
          .collection('inscripciones')
          .where('estudianteUid', isEqualTo: uid)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots()
          .map((s) => [
                for (final d in s.docs) Inscripcion.fromMap(d.id, d.data())
              ]),
      costoDe: (codigo) async {
        final d = await db.collection('deportes').doc(codigo).get();
        final costo = d.data()?['costo'];
        return costo is num ? costo.toDouble() : null;
      },
      confirmar: (inscripcion, resultado, monto) => inscripciones.confirmar(
        inscripcion.id,
        pago: pagoDesdePaypal(
          inscripcion: inscripcion,
          resultado: resultado,
          monto: monto,
        ),
      ),
    );
  }

  final String estudianteUid;
  final PagoRepository pagos;
  final Stream<List<Inscripcion>> Function() pendientes;
  final ConfirmarPago confirmar;

  /// Costo del deporte: es lo que se cobra en PayPal.
  final Future<double?> Function(String deporteId)? costoDe;
  final ConstructorVistaPaypal? construirVista;

  @override
  State<PagosEstudianteSeccion> createState() => _PagosEstudianteSeccionState();
}

class _PagosEstudianteSeccionState extends State<PagosEstudianteSeccion> {
  late final Stream<List<Inscripcion>> _pendientes = widget.pendientes();

  static String _fecha(DateTime f) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)} ${d2(f.hour)}:${d2(f.minute)}';
  }

  Future<void> _pagar(Inscripcion inscripcion) async {
    double? monto;
    try {
      monto = await widget.costoDe?.call(inscripcion.deporteId);
    } catch (_) {
      monto = null;
    }
    if (!mounted) return;
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el costo del deporte.')),
      );
      return;
    }
    final costo = monto;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PagarInscripcionScreen(
          inscripcion: inscripcion,
          monto: costo,
          confirmar: widget.confirmar,
          construirVista: widget.construirVista,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Por pagar', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StreamBuilder<List<Inscripcion>>(
          stream: _pendientes,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('No se pudieron cargar tus inscripciones.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snapshot.data!;
            if (lista.isEmpty) return const Text('No tienes pagos pendientes.');
            return Column(
              children: [
                for (final i in lista)
                  Card(
                    child: ListTile(
                      title: Text(i.deporteNombre),
                      subtitle: Text(i.estaVencida()
                          ? 'Plazo vencido'
                          : 'Paga antes del ${_fecha(i.fechaLimitePago)}'),
                      trailing: FilledButton(
                        onPressed: i.estaVencida() ? null : () => _pagar(i),
                        child: const Text('Pagar'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MisPagosScreen(
                repositorio: widget.pagos,
                estudianteUid: widget.estudianteUid,
              ),
            ),
          ),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Ver mis pagos'),
        ),
      ],
    );
  }
}

/// Versión con Firebase real. Se arma al abrirse, no al construirla,
/// para que las pruebas del AuthGate no necesiten Firebase.
class PagosEstudianteFirebase extends StatelessWidget {
  const PagosEstudianteFirebase({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => PagosEstudianteSeccion.firebase(uid);
}

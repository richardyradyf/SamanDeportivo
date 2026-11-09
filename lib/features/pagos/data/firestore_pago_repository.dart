import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/enums.dart';
import '../../../models/pago.dart';
import '../../../repositories/pago_repository.dart';

class FirestorePagoRepository implements PagoRepository {
  FirestorePagoRepository([FirebaseFirestore? db])
      : _pagos = (db ?? FirebaseFirestore.instance).collection('pagos');

  final CollectionReference<Map<String, dynamic>> _pagos;

  Stream<List<Pago>> _lista(Query<Map<String, dynamic>> consulta) {
    return consulta.snapshots().map((s) {
      final pagos = [for (final d in s.docs) Pago.fromMap(d.id, d.data())];
      pagos.sort((a, b) => b.fecha.compareTo(a.fecha));
      return pagos;
    });
  }

  @override
  Stream<List<Pago>> observarDeEstudiante(String estudianteUid) =>
      _lista(_pagos.where('estudianteUid', isEqualTo: estudianteUid));

  @override
  Stream<List<Pago>> observarTodos() => _lista(_pagos);

  @override
  Future<Pago> crear(Pago pago) =>
      throw UnsupportedError('Lo hace la función crearOrdenPaypal.');

  @override
  Future<void> actualizarEstado(String pagoId, EstadoPago estado,
          {String? paypalCaptureId}) =>
      throw UnsupportedError('Lo hace la función capturarPagoPaypal.');
}
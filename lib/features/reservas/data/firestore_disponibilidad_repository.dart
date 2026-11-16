import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Proyección pública; no consulta `reservasEspacios` ni expone usuarioUid.
class FirestoreDisponibilidadRepository implements DisponibilidadRepository {
  FirestoreDisponibilidadRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<List<OcupacionEspacio>> observarOcupaciones({
    required String espacioId,
    required DateTime desde,
    required DateTime hasta,
  }) {
    if (espacioId.trim().isEmpty || !hasta.isAfter(desde) ||
        hasta.difference(desde) > const Duration(days: 31)) {
      throw ArgumentError('Consulta un espacio y un rango de hasta 31 días.');
    }
    return _db.collection('ocupacionesEspacios')
        .where('espacioId', isEqualTo: espacioId)
        .where('inicio', isLessThan: Timestamp.fromDate(hasta))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OcupacionEspacio.fromMap(doc.id, doc.data()))
            .where((o) => o.fin.isAfter(desde))
            .toList(growable: false));
  }
}

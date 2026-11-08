import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

class FirestoreAsistenciaRepository implements AsistenciaRepository {
  FirestoreAsistenciaRepository({FirebaseFirestore? firestore, this.entrenadorUid})
      : _asistencias =
            (firestore ?? FirebaseFirestore.instance).collection('asistencias');

  final CollectionReference<Map<String, dynamic>> _asistencias;

  /// Si se indica, las consultas por deporte también filtran por este
  /// entrenador: las reglas de seguridad lo exigen.
  final String? entrenadorUid;

  @override
  Future<void> guardarSesion(List<Asistencia> registros) async {
    final lote = _asistencias.firestore.batch();
    for (final a in registros) {
      lote.set(_asistencias.doc(a.id), a.toMap());
    }
    await lote.commit();
  }

  Stream<List<Asistencia>> _entre(
    Query<Map<String, dynamic>> consulta,
    DateTime desde,
    DateTime hasta,
  ) {
    return consulta
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThan: Timestamp.fromDate(hasta))
        .snapshots()
        .map((s) => [for (final d in s.docs) Asistencia.fromMap(d.id, d.data())]);
  }

  @override
  Stream<List<Asistencia>> observarDeDeporte(
    String codigoDeporte, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    var consulta = _asistencias.where('deporteId', isEqualTo: codigoDeporte);
    if (entrenadorUid != null) {
      consulta = consulta.where('entrenadorUid', isEqualTo: entrenadorUid);
    }
    return _entre(consulta, desde, hasta);
  }

  @override
  Stream<List<Asistencia>> observarDeEstudiante(
    String estudianteUid, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    return _entre(
      _asistencias.where('estudianteUid', isEqualTo: estudianteUid),
      desde,
      hasta,
    );
  }
}
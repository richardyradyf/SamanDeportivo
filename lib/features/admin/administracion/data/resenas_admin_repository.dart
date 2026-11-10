import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/data/firestore_resena_repository.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Las reseñas se consultan por deporte: evita una consulta de colección
/// global y permite aplicar reglas con ámbito reducido por deporte.
abstract class ResenasAdminRepository {
  Stream<List<Deporte>> observarDeportes();
  Stream<List<Resena>> observarResenas(String codigoDeporte);
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  });
}

class FirestoreResenasAdminRepository implements ResenasAdminRepository {
  FirestoreResenasAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Deporte>> observarDeportes() => _firestore
      .collection('deportes')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Deporte.fromMap(doc.id, doc.data()))
            .toList(growable: false),
      );

  @override
  Stream<List<Resena>> observarResenas(String codigoDeporte) => _firestore
      .collection('deportes')
      .doc(codigoDeporte)
      .collection('resenas')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Resena.fromMap(doc.id, doc.data()))
            .toList(growable: false),
      );

  @override
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  }) async {
    if (codigoDeporte.trim().isEmpty || estudianteUid.trim().isEmpty) {
      throw ArgumentError('Deporte y estudiante son obligatorios.');
    }
    // Reusar la transaccion compartida: oculta la resena y actualiza
    // promedio/total sin dejar los dos documentos inconsistentes.
    await FirestoreResenaRepository(firestore: _firestore).cambiarVisibilidad(
      codigoDeporte, estudianteUid, oculta: oculta,
    );
  }
}

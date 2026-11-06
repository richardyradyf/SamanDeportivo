import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/entrenador.dart';
import 'package:saman_deportivo/models/enums.dart';

import 'entrenador_repository.dart';

/// Solo el administrador puede listar la colección usuarios según las reglas
/// actuales. Las lecturas realizadas por un estudiante deben ser rechazadas.
class FirestoreEntrenadorRepository implements EntrenadorRepository {
  FirestoreEntrenadorRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Entrenador>> observarEntrenadores() {
    return _firestore
        .collection('usuarios')
        .where('rol', isEqualTo: Rol.entrenador.name)
        .snapshots()
        .map((snapshot) {
          final entrenadores = snapshot.docs
              .map((doc) => Entrenador.fromMap(doc.id, doc.data()))
              .toList(growable: false);
          entrenadores.sort((a, b) => a.nombre.compareTo(b.nombre));
          return entrenadores;
        });
  }
}

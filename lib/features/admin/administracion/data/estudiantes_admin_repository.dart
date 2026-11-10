import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';

/// Contrato inyectable. Solo el rol administrador puede listar usuarios y
/// cambiar el estado de un estudiante (ver firestore.rules).
abstract class EstudiantesAdminRepository {
  Stream<List<Estudiante>> observarEstudiantes();
  Future<void> cambiarEstado(String uid, EstadoEstudiante nuevoEstado);
}

class FirestoreEstudiantesAdminRepository
    implements EstudiantesAdminRepository {
  FirestoreEstudiantesAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Estudiante>> observarEstudiantes() => _firestore
      .collection('usuarios')
      .where('rol', isEqualTo: 'estudiante')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Estudiante.fromMap(doc.id, doc.data()))
            .toList(growable: false),
      );

  @override
  Future<void> cambiarEstado(String uid, EstadoEstudiante nuevoEstado) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El identificador del estudiante es obligatorio.');
    }
    // Solo modifica este campo. Las reglas rechazan cualquier otro cambio.
    await _firestore.collection('usuarios').doc(uid).update({
      'estado': nuevoEstado.name,
    });
  }
}

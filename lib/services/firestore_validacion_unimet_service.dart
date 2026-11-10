import 'package:cloud_firestore/cloud_firestore.dart';

import 'validacion_unimet_service.dart';

/// Implementacion de la validacion del estudiante usando Firestore.
///
/// Para el Hito 3, la validacion de solvencia se simula
/// mediante el estado del estudiante en la coleccion usuarios.
class FirestoreValidacionUnimetService implements ValidacionUnimetService {
  final FirebaseFirestore firestore;

  FirestoreValidacionUnimetService({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<bool> estaHabilitado(String estudianteUid) async {
    if (estudianteUid.trim().isEmpty) {
      return false;
    }

    final documento = await firestore
        .collection('usuarios')
        .doc(estudianteUid)
        .get();

    if (!documento.exists) {
      return false;
    }

    final datos = documento.data();

    if (datos == null) {
      return false;
    }

    final esEstudiante = datos['rol'] == 'estudiante';
    final estaActivo = datos['estado'] == 'activo';

    return esEstudiante && estaActivo;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/perfil_usuario.dart';
import 'perfil_repository.dart';

class FirestorePerfilRepository implements PerfilRepository {
  FirestorePerfilRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<PerfilUsuario?> observarPerfil(String uid) {
    return _firestore.collection('usuarios').doc(uid).snapshots().map((snapshot) {
      final datos = snapshot.data();
      return datos == null ? null : PerfilUsuario.fromMap(snapshot.id, datos);
    });
  }

  @override
  Future<void> actualizarPerfil({
    required String uid,
    required String nombre,
    String? carnet,
  }) async {
    final limpio = nombre.trim();
    if (limpio.length < 2 || limpio.length > 100) {
      throw ArgumentError('El nombre debe tener entre 2 y 100 caracteres');
    }
    final cambios = <String, dynamic>{'nombre': limpio};
    if (carnet != null) {
      final carnetLimpio = carnet.trim();
      if (!RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(carnetLimpio)) {
        throw ArgumentError('Carnet inválido');
      }
      cambios['carnet'] = carnetLimpio;
    }
    await _firestore.collection('usuarios').doc(uid).update(cambios);
  }
}

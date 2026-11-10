import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/perfil_usuario.dart';
import 'perfil_repository.dart';

class FirestorePerfilRepository implements PerfilRepository {
  FirestorePerfilRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<PerfilUsuario?> observarPerfil(String uid) {
    return _firestore.collection('usuarios').doc(uid).snapshots().map((
      snapshot,
    ) {
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
    final nombreLimpio = nombre.trim();

    if (nombreLimpio.length < 2 || nombreLimpio.length > 100) {
      throw ArgumentError('El nombre debe tener entre 2 y 100 caracteres');
    }

    final carnetNuevo = carnet?.trim();

    if (carnetNuevo != null &&
        !RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(carnetNuevo)) {
      throw ArgumentError('Carnet inválido');
    }

    final usuarioRef = _firestore.collection('usuarios').doc(uid);

    await _firestore.runTransaction<void>((tx) async {
      // Leer primero el perfil actual.
      final documento = await tx.get(usuarioRef);

      if (!documento.exists) {
        throw StateError('El usuario no existe');
      }

      final datos = documento.data()!;
      final rol = datos['rol'] as String?;
      final carnetAnterior = datos['carnet'] as String?;

      // Editar solamente el nombre.
      if (carnetNuevo == null || carnetNuevo == carnetAnterior) {
        tx.update(usuarioRef, {'nombre': nombreLimpio});
        return;
      }

      // Solo los estudiantes tienen carnet editable.
      if (rol != 'estudiante') {
        throw StateError('Este perfil no permite modificar el carnet');
      }

      if (carnetAnterior == null || carnetAnterior.isEmpty) {
        throw StateError('El perfil no tiene un carnet anterior válido');
      }

      final carnets = _firestore.collection('carnets');

      final nuevoRef = carnets.doc(carnetNuevo);
      final anteriorRef = carnets.doc(carnetAnterior);

      // Crear el índice nuevo y liberar el anterior.
      // Las reglas de Firestore deben impedir que
      // el índice nuevo pertenezca a otra persona.
      tx.set(nuevoRef, {'uid': uid});

      tx.update(usuarioRef, {'nombre': nombreLimpio, 'carnet': carnetNuevo});

      tx.delete(anteriorRef);
    });
  }
}

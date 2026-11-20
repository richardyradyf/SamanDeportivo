import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/perfil_usuario.dart';
import 'perfil_repository.dart';

class FirestorePerfilRepository implements PerfilRepository {
  FirestorePerfilRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
    String? telefono,
  }) async {
    final nombreLimpio = nombre.trim();

    if (nombreLimpio.length < 2 || nombreLimpio.length > 100) {
      throw ArgumentError('El nombre debe tener entre 2 y 100 caracteres');
    }

    final carnetNuevo = carnet?.trim();

    if (carnetNuevo != null &&
        !RegExp(r'^[0-9]{4,24}$').hasMatch(carnetNuevo)) {
      throw ArgumentError('Carnet inválido');
    }

    final telefonoNuevo = telefono?.trim();
    if (telefonoNuevo != null &&
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(telefonoNuevo)) {
      throw ArgumentError('Teléfono internacional inválido');
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
      final cambios = <String, dynamic>{'nombre': nombreLimpio};
      if (telefonoNuevo != null) {
        if (rol != 'estudiante') {
          throw StateError('Este perfil no permite modificar el teléfono');
        }
        cambios['telefono'] = telefonoNuevo;
      }

      // Editar solamente el nombre.
      if (carnetNuevo == null || carnetNuevo == carnetAnterior) {
        tx.update(usuarioRef, cambios);
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

      tx.update(usuarioRef, {...cambios, 'carnet': carnetNuevo});

      tx.delete(anteriorRef);
    });
  }

  @override
  Future<void> solicitarCambioCorreo(String correo) async {
    final nuevo = correo.trim().toLowerCase();
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@correo\.unimet\.edu\.ve$')
        .hasMatch(nuevo)) {
      throw ArgumentError('Debes usar un correo @correo.unimet.edu.ve');
    }
    final usuario = _auth.currentUser;
    if (usuario == null) throw StateError('No hay sesión activa');
    await usuario.verifyBeforeUpdateEmail(nuevo);
  }

  @override
  Future<String> sincronizarCorreoVerificado(String uid) async {
    final usuario = _auth.currentUser;
    if (usuario == null || usuario.uid != uid) {
      throw StateError('La sesión no corresponde al perfil');
    }
    await usuario.reload();
    final actualizado = _auth.currentUser;
    if (actualizado == null || actualizado.uid != uid) {
      throw StateError('La sesión expiró');
    }
    final correo = actualizado.email?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@correo\.unimet\.edu\.ve$')
        .hasMatch(correo)) {
      throw StateError('El correo verificado debe ser institucional');
    }
    await actualizado.getIdToken(true);
    // La regla solo permite este cambio si el token de Auth ya contiene correo.
    await _firestore.collection('usuarios').doc(uid).update({'correo': correo});
    return correo;
  }
}

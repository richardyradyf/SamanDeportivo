
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';

class UsuarioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colección de usuarios en Firestore.
  CollectionReference<Map<String, dynamic>> get _usuarios {
    return _firestore.collection('usuarios');
  }

  // Guardar el perfil de un estudiante.
  Future<void> guardarUsuario(UsuarioModel usuario) async {
    if (usuario.rol != 'estudiante' ||
        usuario.estado != 'inactivo') {
      throw Exception('Datos de registro no permitidos');
    }

    await _usuarios.doc(usuario.uid).set(usuario.toMap());
  }

  // Obtener los datos de un usuario.
  Future<UsuarioModel?> obtenerUsuario(String uid) async {
    final documento = await _usuarios.doc(uid).get();

    if (!documento.exists || documento.data() == null) {
      return null;
    }

    return UsuarioModel.fromMap(documento.data()!);
  }

  // Actualizar los datos permitidos del perfil.
  Future<void> actualizarPerfil({
    required String uid,
    required String nombre,
    required String carnet,
  }) async {
    await _usuarios.doc(uid).update({
      'nombre': nombre,
      'carnet': carnet,
    });
  }
}

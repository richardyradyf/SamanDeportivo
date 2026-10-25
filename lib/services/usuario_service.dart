
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/estudiante.dart';
import '../models/enums.dart';
import '../models/usuario_model.dart';

class UsuarioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colección de perfiles de usuarios.
  CollectionReference<Map<String, dynamic>> get _usuarios {
    return _firestore.collection('usuarios');
  }

  // Guardar el perfil del estudiante recién registrado.
  Future<void> guardarEstudiante(Estudiante estudiante) async {
    if (estudiante.estado != EstadoEstudiante.activo) {
      throw Exception('El estudiante debe registrarse como activo');
    }

    await _usuarios.doc(estudiante.uid).set(estudiante.toMap());
  }

  // Mantener el método anterior por compatibilidad.
  Future<void> guardarUsuario(UsuarioModel usuario) async {
    if (usuario.rol != 'estudiante') {
      throw Exception('Solo se permite registrar estudiantes');
    }

    final estudiante = Estudiante(
      uid: usuario.uid,
      cedula: usuario.cedula,
      nombre: usuario.nombre,
      correo: usuario.correo,
      carnet: usuario.carnet ?? '',
      estado: EstadoEstudiante.activo,
    );

    await guardarEstudiante(estudiante);
  }

  // Obtener los datos de un usuario desde Firestore.
  Future<UsuarioModel?> obtenerUsuario(String uid) async {
    final documento = await _usuarios.doc(uid).get();

    if (!documento.exists || documento.data() == null) {
      return null;
    }

    final datos = {
      ...documento.data()!,
      'uid': uid,
    };

    return UsuarioModel.fromMap(datos);
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

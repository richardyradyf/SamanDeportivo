import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/estudiante.dart';
import '../models/enums.dart';
import '../models/usuario_model.dart';

class UsuarioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _cedulas =>
      _firestore.collection('cedulas');

  CollectionReference<Map<String, dynamic>> get _carnets =>
      _firestore.collection('carnets');

  // Registra perfil, cedula y carnet en la misma transaccion.
  Future<void> guardarEstudiante(Estudiante estudiante) async {
    if (estudiante.estado != EstadoEstudiante.activo) {
      throw StateError('El estudiante debe registrarse como activo');
    }

    final cedula = estudiante.cedula.trim();
    final carnet = estudiante.carnet.trim();

    if (!RegExp(r'^[0-9]{5,20}$').hasMatch(cedula)) {
      throw ArgumentError('La cedula no tiene un formato valido');
    }

    if (!RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(carnet)) {
      throw ArgumentError('El carnet no tiene un formato valido');
    }

    final usuarioRef = _usuarios.doc(estudiante.uid);
    final cedulaRef = _cedulas.doc(cedula);
    final carnetRef = _carnets.doc(carnet);

    await _firestore.runTransaction<void>((tx) async {
      // Leer unicamente el perfil propio.
      final usuarioExistente = await tx.get(usuarioRef);

      if (usuarioExistente.exists) {
        throw StateError('Este usuario ya tiene un perfil');
      }

      // No leemos indices ajenos: intentamos crearlos.
      // Las reglas rechazaran la escritura si ya existen.
      tx.set(cedulaRef, {'uid': estudiante.uid});
      tx.set(carnetRef, {'uid': estudiante.uid});
      tx.set(usuarioRef, estudiante.toMap());
    });
  }

  Future<void> guardarUsuario(UsuarioModel usuario) async {
    if (usuario.rol != 'estudiante') {
      throw StateError('Solo se permite registrar estudiantes');
    }

    await guardarEstudiante(
      Estudiante(
        uid: usuario.uid,
        cedula: usuario.cedula,
        nombre: usuario.nombre,
        correo: usuario.correo,
        carnet: usuario.carnet ?? '',
        estado: EstadoEstudiante.activo,
      ),
    );
  }

  Future<UsuarioModel?> obtenerUsuario(String uid) async {
    final documento = await _usuarios.doc(uid).get();

    if (!documento.exists || documento.data() == null) {
      return null;
    }

    return UsuarioModel.fromMap({...documento.data()!, 'uid': uid});
  }

  // Cambiar el carnet requiere mover su indice atomicamente.
  Future<void> actualizarPerfil({
    required String uid,
    required String nombre,
    required String carnet,
  }) async {
    final nombreLimpio = nombre.trim();
    final carnetNuevo = carnet.trim();

    if (nombreLimpio.length < 2 || nombreLimpio.length > 100) {
      throw ArgumentError('Nombre invalido');
    }

    if (!RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(carnetNuevo)) {
      throw ArgumentError('Carnet invalido');
    }

    final usuarioRef = _usuarios.doc(uid);

    await _firestore.runTransaction<void>((tx) async {
      final documento = await tx.get(usuarioRef);

      if (!documento.exists) {
        throw StateError('El usuario no existe');
      }

      final carnetAnterior = documento.data()?['carnet'] as String?;

      if (carnetAnterior == null) {
        throw StateError('El perfil no tiene carnet');
      }

      if (carnetAnterior == carnetNuevo) {
        tx.update(usuarioRef, {'nombre': nombreLimpio});
        return;
      }

      // La escritura del nuevo indice fallara si esta ocupado.
      tx.set(_carnets.doc(carnetNuevo), {'uid': uid});

      tx.update(usuarioRef, {'nombre': nombreLimpio, 'carnet': carnetNuevo});

      tx.delete(_carnets.doc(carnetAnterior));
    });
  }
}

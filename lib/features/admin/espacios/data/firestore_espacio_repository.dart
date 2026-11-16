import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';

class FirestoreEspacioRepository implements EspacioRepository {
  FirestoreEspacioRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _espacios =>
      _db.collection('espacios');

  static void _validar(String nombre, String tipo, String descripcion) {
    if (nombre.trim().length < 3 || nombre.trim().length > 100) {
      throw ArgumentError('El nombre debe tener entre 3 y 100 caracteres.');
    }
    if (tipo.trim().isEmpty || tipo.trim().length > 60) {
      throw ArgumentError('El tipo de espacio debe tener de 1 a 60 caracteres.');
    }
    if (descripcion.trim().length > 500) {
      throw ArgumentError('La descripción no debe superar 500 caracteres.');
    }
  }

  @override
  Stream<List<EspacioDeportivo>> observarTodos() => _espacios.snapshots().map(
    (s) => s.docs
        .map((d) => EspacioDeportivo.fromMap(d.id, d.data()))
        .toList(growable: false),
  );

  @override
  Future<String> crear({
    required String nombre,
    required String tipo,
    String descripcion = '',
  }) async {
    _validar(nombre, tipo, descripcion);
    final ref = _espacios.doc();
    await ref.set({
      'nombre': nombre.trim(),
      'tipo': tipo.trim(),
      'descripcion': descripcion.trim(),
      'activo': true,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> actualizar(EspacioDeportivo espacio) async {
    _validar(espacio.nombre, espacio.tipo, espacio.descripcion);
    await _espacios.doc(espacio.id).update({
      'nombre': espacio.nombre.trim(),
      'tipo': espacio.tipo.trim(),
      'descripcion': espacio.descripcion.trim(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cambiarEstado(String espacioId, {required bool activo}) async {
    await _espacios.doc(espacioId).update({
      'activo': activo,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

/// Reseñas en `deportes/{codigo}/resenas/{uid}` (RF-17).
///
/// Va de la mano con las reglas A3.6 y la Cloud Function A3.7 de Alexander:
/// - Las reglas solo dejan escribir al estudiante con inscripción
///   confirmada, y solo su propia reseña (el ID es su UID).
/// - El estudiante nunca cambia `oculta`; eso lo hace el administrador.
/// - `promedioCalificacion` y `totalResenas` los recalcula la Cloud
///   Function cuando cambia una reseña. La app no los toca, así que el
///   promedio nuevo puede tardar unos segundos en verse.
class FirestoreResenaRepository implements ResenaRepository {
  FirestoreResenaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Límite de `estudianteNombre` en las reglas.
  static const int maxNombre = 100;

  CollectionReference<Map<String, dynamic>> _resenas(String codigoDeporte) =>
      _firestore.collection('deportes').doc(codigoDeporte).collection('resenas');

  @override
  Stream<List<Resena>> observar(
    String codigoDeporte, {
    bool incluirOcultas = false,
  }) {
    Query<Map<String, dynamic>> consulta = _resenas(codigoDeporte);
    // Las reglas solo dejan listar las visibles a quien no es administrador,
    // así que la consulta tiene que pedirlas así o Firestore la rechaza.
    // Sin orderBy para no necesitar un índice compuesto: la pantalla las
    // ordena por fecha.
    if (!incluirOcultas) {
      consulta = consulta.where('oculta', isEqualTo: false);
    }
    return consulta.snapshots().map(
      (snapshot) => snapshot.docs
          .map((documento) => Resena.fromMap(documento.id, documento.data()))
          .toList(growable: false),
    );
  }

  @override
  Future<void> guardar(String codigoDeporte, Resena resena) async {
    if (!resena.esValida) {
      throw ArgumentError('La reseña debe tener de 1 a 5 estrellas y un '
          'comentario de máximo ${Resena.maxComentario} caracteres.');
    }

    final documento = _resenas(codigoDeporte).doc(resena.estudianteUid);
    final nombre = resena.estudianteNombre.trim();
    final datos = <String, dynamic>{
      'estudianteNombre': nombre.length > maxNombre
          ? nombre.substring(0, maxNombre)
          : nombre,
      'puntuacion': resena.puntuacion,
      'comentario': resena.comentario.trim(),
      'fecha': Timestamp.fromDate(resena.fecha),
    };

    try {
      // Caso normal: reseña nueva o ya visible. Siempre entra visible.
      await documento.set({...datos, 'oculta': false});
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // Si el administrador la había ocultado, escribir `oculta: false`
      // está prohibido. Se actualiza el contenido y la reseña sigue oculta.
      // Si tampoco se puede, el estudiante no tiene inscripción confirmada
      // y el error llega a la pantalla.
      await documento.set(datos, SetOptions(merge: true));
    }
  }

  @override
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  }) {
    return _resenas(
      codigoDeporte,
    ).doc(estudianteUid).update({'oculta': oculta});
  }
}

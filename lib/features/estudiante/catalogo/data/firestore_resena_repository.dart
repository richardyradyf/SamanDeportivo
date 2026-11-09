import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/data/agregado_resenas.dart';
import 'package:saman_deportivo/models/conversiones.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

/// Reseñas en `deportes/{codigo}/resenas/{uid}` (RF-17).
///
/// Va de la mano con las reglas A3.6 de Alexander:
/// - Las reglas solo dejan escribir al estudiante con inscripción
///   confirmada, y solo su propia reseña (el ID es su UID).
/// - El estudiante nunca cambia `oculta`; eso lo hace el administrador.
/// - El proyecto está en el plan gratuito de Firebase (sin Cloud
///   Functions), así que `promedioCalificacion` y `totalResenas` se
///   recalculan aquí, en la misma transacción que guarda la reseña. Las
///   reseñas ocultas no cuentan. La cuenta está en [AgregadoResenas].
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

  DocumentReference<Map<String, dynamic>> _deporte(String codigoDeporte) =>
      _firestore.collection('deportes').doc(codigoDeporte);

  static AgregadoResenas _agregadoDe(Map<String, dynamic> deporte) =>
      AgregadoResenas(
        promedio: leerDecimal(deporte['promedioCalificacion']),
        total: leerEntero(deporte['totalResenas']),
      );

  static Map<String, dynamic> _comoMapa(AgregadoResenas agregado) => {
    'promedioCalificacion': agregado.promedio,
    'totalResenas': agregado.total,
  };

  @override
  Future<void> guardar(String codigoDeporte, Resena resena) async {
    if (!resena.esValida) {
      throw ArgumentError('La reseña debe tener de 1 a 5 estrellas y un '
          'comentario de máximo ${Resena.maxComentario} caracteres.');
    }

    final deporte = _deporte(codigoDeporte);
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

    // Todo en una transacción: si dos estudiantes califican a la vez,
    // Firestore repite la que llegó después con los datos nuevos, y el
    // promedio no se pisa.
    await _firestore.runTransaction((transaccion) async {
      final fotoDeporte = await transaccion.get(deporte);
      final fotoResena = await transaccion.get(documento);
      final datosDeporte = fotoDeporte.data();
      if (datosDeporte == null) {
        throw StateError('El deporte $codigoDeporte no existe.');
      }

      final anterior = fotoResena.data();
      final antes = _agregadoDe(datosDeporte);
      final despues = antes.alGuardar(
        nueva: resena.puntuacion,
        anterior: anterior == null ? null : leerEntero(anterior['puntuacion']),
        anteriorOculta: anterior?['oculta'] == true,
      );

      if (anterior == null) {
        // Reseña nueva: siempre entra visible.
        transaccion.set(documento, {...datos, 'oculta': false});
      } else {
        // Edición: no se toca `oculta`; si el administrador la ocultó,
        // sigue oculta.
        transaccion.update(documento, datos);
      }
      if (despues != antes) {
        transaccion.update(deporte, _comoMapa(despues));
      }
    });
  }

  @override
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  }) async {
    final deporte = _deporte(codigoDeporte);
    final documento = _resenas(codigoDeporte).doc(estudianteUid);

    // Ocultar una reseña la saca del promedio; mostrarla la vuelve a sumar.
    await _firestore.runTransaction((transaccion) async {
      final fotoDeporte = await transaccion.get(deporte);
      final fotoResena = await transaccion.get(documento);
      final datosDeporte = fotoDeporte.data();
      final datosResena = fotoResena.data();
      if (datosDeporte == null || datosResena == null) {
        throw StateError('La reseña o el deporte no existen.');
      }
      if ((datosResena['oculta'] == true) == oculta) return;

      final puntuacion = leerEntero(datosResena['puntuacion']);
      final antes = _agregadoDe(datosDeporte);
      final despues = oculta ? antes.quitar(puntuacion) : antes.agregar(puntuacion);

      transaccion.update(documento, {'oculta': oculta});
      transaccion.update(deporte, _comoMapa(despues));
    });
  }
}

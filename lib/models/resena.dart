import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';

/// Reseña de un deporte (RF-17).
/// Subcolección `deportes/{codigo}/resenas`; el ID es el UID del estudiante,
/// así cada estudiante califica una sola vez.
class Resena {
  final String estudianteUid;
  final String estudianteNombre;

  /// De 1 a 5 estrellas.
  final int puntuacion;
  final String comentario;

  /// El administrador oculta las reseñas inapropiadas.
  final bool oculta;
  final DateTime fecha;

  const Resena({
    required this.estudianteUid,
    required this.estudianteNombre,
    required this.puntuacion,
    required this.comentario,
    required this.fecha,
    this.oculta = false,
  });

  static const int maxComentario = 300;

  bool get esValida =>
      puntuacion >= 1 &&
      puntuacion <= 5 &&
      comentario.length <= maxComentario;

  Map<String, dynamic> toMap() {
    return {
      'estudianteNombre': estudianteNombre,
      'puntuacion': puntuacion,
      'comentario': comentario,
      'oculta': oculta,
      'fecha': Timestamp.fromDate(fecha),
    };
  }

  factory Resena.fromMap(String estudianteUid, Map<String, dynamic> datos) {
    return Resena(
      estudianteUid: estudianteUid,
      estudianteNombre: datos['estudianteNombre'] as String? ?? '',
      puntuacion: leerEntero(datos['puntuacion']),
      comentario: datos['comentario'] as String? ?? '',
      oculta: datos['oculta'] as bool? ?? false,
      fecha: leerFecha(datos['fecha']),
    );
  }
}

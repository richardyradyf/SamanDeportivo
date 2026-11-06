import '../models/resena.dart';

/// Acceso a `deportes/{codigo}/resenas` (RF-17). Implementa: Gabriel.
abstract class ResenaRepository {
  /// Reseñas de un deporte. El catálogo no muestra las ocultas;
  /// el administrador sí (para poder volver a mostrarlas).
  Stream<List<Resena>> observar(String codigoDeporte, {bool incluirOcultas = false});

  /// Crea o reemplaza la reseña del estudiante y recalcula
  /// `promedioCalificacion` y `totalResenas` del deporte.
  /// Solo para estudiantes con inscripción confirmada.
  Future<void> guardar(String codigoDeporte, Resena resena);

  /// El administrador oculta o vuelve a mostrar una reseña.
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  });
}

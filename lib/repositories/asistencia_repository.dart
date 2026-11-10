import '../models/asistencia.dart';

/// Acceso a la colección `asistencias` (RF-14). Implementa: Andrés.
abstract class AsistenciaRepository {
  /// Guarda la lista de una sesión de una sola vez (WriteBatch).
  /// Si ya existía, la reemplaza (el entrenador puede corregir).
  Future<void> guardarSesion(List<Asistencia> registros);

  /// Historial de un deporte entre dos fechas (diario, semanal o mensual).
  /// [hasta] no se incluye.
  Stream<List<Asistencia>> observarDeDeporte(
    String codigoDeporte, {
    required DateTime desde,
    required DateTime hasta,
  });

  /// Historial de un estudiante entre dos fechas.
  Stream<List<Asistencia>> observarDeEstudiante(
    String estudianteUid, {
    required DateTime desde,
    required DateTime hasta,
  });
}

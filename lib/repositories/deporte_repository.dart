import '../models/deporte.dart';

/// Acceso a la colección `deportes` (RF-05, RF-15, RF-16).
/// Lectura: Gabriel (catálogo). Escritura: Alexander (administración).
abstract class DeporteRepository {
  /// Catálogo en tiempo real (RF-05). Por defecto solo los activos.
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true});

  /// Un deporte en tiempo real; null si no existe.
  Stream<Deporte?> observar(String codigo);

  /// Deportes asignados a un entrenador (RF-02, RF-13, RF-16).
  Stream<List<Deporte>> observarPorEntrenador(String entrenadorUid);

  /// Crea el deporte. Falla si el código ya existe (RF-15).
  Future<void> crear(Deporte deporte);

  /// Actualiza nombre, cupo, entrenador, horarios, etc.
  /// No debe permitir `cupoMaximo < cuposOcupados` (RF-15).
  Future<void> actualizar(Deporte deporte);

  /// Desactiva en vez de borrar (RF-15).
  Future<void> desactivar(String codigo);
}

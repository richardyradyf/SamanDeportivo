import '../models/enums.dart';
import '../models/pago.dart';

/// Acceso a la colección `pagos` (RF-11, RF-12). Implementa: Andrés.
abstract class PagoRepository {
  /// Registra el pago (normalmente en `pendiente`) y devuelve el pago con su ID.
  Future<Pago> crear(Pago pago);

  /// Cambia el estado cuando PayPal responde.
  Future<void> actualizarEstado(
    String pagoId,
    EstadoPago estado, {
    String? paypalCaptureId,
  });

  /// Historial y comprobantes del estudiante (RF-12).
  Stream<List<Pago>> observarDeEstudiante(String estudianteUid);

  /// Auditoría del administrador (RF-12, RF-18).
  Stream<List<Pago>> observarTodos();
}

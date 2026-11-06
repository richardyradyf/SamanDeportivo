import '../models/deporte.dart';
import '../models/estudiante.dart';
import '../models/inscripcion.dart';

/// Error de negocio al inscribirse o cambiar de estado.
/// El [mensaje] se puede mostrar tal cual en la pantalla.
class InscripcionException implements Exception {
  final String mensaje;

  const InscripcionException(this.mensaje);

  static const yaInscrito = InscripcionException('Ya estás inscrito en este deporte');
  static const sinCupos = InscripcionException('No quedan cupos en este deporte');
  static const estudianteInactivo = InscripcionException(
    'Tu estado no permite inscribirte. Consulta con la administración',
  );
  static const deporteInactivo = InscripcionException('Este deporte no está disponible');

  @override
  String toString() => mensaje;
}

/// Acceso a la colección `inscripciones` (RF-07 a RF-10). Implementa: Mariana.
///
/// Todo cambio que toque cupos se hace en una transacción de Firestore
/// junto con `deportes/{codigo}.cuposOcupados` / `cuposConfirmados`.
abstract class InscripcionRepository {
  /// Reserva el cupo y deja la inscripción en `pendiente` (RF-07).
  /// Si el estudiante está inactivo, queda `rechazada` (RF-10).
  /// Lanza [InscripcionException] si ya está inscrito, no hay cupos
  /// o el deporte está inactivo.
  Future<Inscripcion> inscribirse({
    required Estudiante estudiante,
    required Deporte deporte,
  });

  /// El estudiante cancela; libera el cupo (RF-09).
  Future<void> cancelar(String inscripcionId, {required String responsableUid});

  /// Pago aprobado: pasa a `confirmada` (RF-11). La llama el módulo de pagos.
  Future<void> confirmar(String inscripcionId, {required String pagoId});

  /// Pago fallido o fuera de plazo: pasa a `expirada` y libera el cupo.
  /// La llama el módulo de pagos o [expirarVencidas].
  Future<void> expirar(String inscripcionId, {required String motivo});

  /// Expira las pendientes vencidas. Devuelve cuántas expiró.
  /// Se llama al abrir "Mis inscripciones", el catálogo o la nómina.
  Future<int> expirarVencidas();

  /// "Mis inscripciones" del estudiante.
  Stream<List<Inscripcion>> observarDeEstudiante(String estudianteUid);

  /// Nómina del entrenador: solo las confirmadas (RF-13).
  Stream<List<Inscripcion>> observarConfirmadasDeDeporte(String codigoDeporte);

  /// Todas, para el panel del administrador (RF-18).
  Stream<List<Inscripcion>> observarTodas();
}

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
///
/// Reinscripción: el ID es siempre `{uid}_{codigo}`, así que volver a
/// inscribirse reutiliza el mismo documento con [Inscripcion.reinscribir].
/// Se permite si la anterior está cancelada, expirada o rechazada; el
/// historial se conserva.
///
/// Expiración: no hay Cloud Functions (plan gratuito), así que las pendientes
/// vencidas se expiran desde la app con [expirarVencidas] y, además, dentro de
/// [inscribirse] si la inscripción leída ya venció. Limitación conocida: los
/// cupos de una reserva vencida se liberan la próxima vez que alguien abre
/// la app, no en el segundo exacto en que vence.
abstract class InscripcionRepository {
  /// Reserva el cupo y deja la inscripción en `pendiente` (RF-07).
  /// Si existe una anterior que no retiene cupo, la reutiliza (reinscripción);
  /// si existe una pendiente vencida, la expira en la misma transacción
  /// y luego reinscribe.
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
  /// Consulta `estado == pendiente` y `fechaLimitePago < ahora` (requiere un
  /// índice compuesto) y expira cada una en su propia transacción, verificando
  /// que siga pendiente. Se llama al iniciar sesión y al abrir el catálogo,
  /// "Mis inscripciones", la nómina y el panel del administrador.
  Future<int> expirarVencidas();

  /// "Mis inscripciones" del estudiante.
  Stream<List<Inscripcion>> observarDeEstudiante(String estudianteUid);

  /// Nómina del entrenador: solo las confirmadas (RF-13).
  Stream<List<Inscripcion>> observarConfirmadasDeDeporte(String codigoDeporte);

  /// Todas, para el panel del administrador (RF-18).
  Stream<List<Inscripcion>> observarTodas();
}

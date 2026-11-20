import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Lectura pública de franjas ocupadas, sin datos personales ni acciones
/// de escritura. La escritura segura se habilitará con control transaccional.
abstract class DisponibilidadRepository {
  Stream<List<OcupacionEspacio>> observarOcupaciones({
    required String espacioId,
    required DateTime desde,
    required DateTime hasta,
  });
}

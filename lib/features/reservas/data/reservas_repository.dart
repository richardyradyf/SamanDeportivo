import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Contrato independiente de Firebase para las pantallas y pruebas.
abstract class ReservasRepository {
  Stream<List<ReservaEspacio>> observarPropias(String usuarioUid);

  Future<String> crear({
    required String espacioId,
    required DateTime inicio,
    required DateTime fin,
    required String motivo,
  });

  Future<void> cancelar(String reservaId);
}

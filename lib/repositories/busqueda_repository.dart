import '../models/busqueda.dart';

/// Acceso a la colección `busquedas` (RF-06, RF-18).
/// Registrar: Gabriel. Consultar para el panel: Alexander.
abstract class BusquedaRepository {
  /// Guarda una búsqueda confirmada (enter o 1 s sin escribir),
  /// no una por cada tecla.
  Future<void> registrar(Busqueda busqueda);

  /// Búsquedas desde una fecha, para "deportes más buscados".
  Stream<List<Busqueda>> observarDesde(DateTime desde);
}

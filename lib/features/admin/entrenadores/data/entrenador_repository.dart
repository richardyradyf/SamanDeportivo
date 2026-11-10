import 'package:saman_deportivo/models/entrenador.dart';

/// Contrato de consulta. Altas/ediciones de cuentas requieren backend
/// privilegiado; la aplicación Flutter no debe contener Firebase Admin SDK.
abstract class EntrenadorRepository {
  Stream<List<Entrenador>> observarEntrenadores();
}

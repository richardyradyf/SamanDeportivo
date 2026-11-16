import 'package:saman_deportivo/models/espacio_deportivo.dart';

/// Contrato compartido: el sistema de reservas también consultará espacios.
abstract class EspacioRepository {
  Stream<List<EspacioDeportivo>> observarTodos();

  Future<String> crear({
    required String nombre,
    required String tipo,
    String descripcion = '',
  });

  Future<void> actualizar(EspacioDeportivo espacio);

  /// Desactiva sin borrar el historial ni las referencias de los horarios.
  Future<void> cambiarEstado(String espacioId, {required bool activo});
}

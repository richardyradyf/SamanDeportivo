/// Promedio y total de reseñas visibles de un deporte (RF-17).
///
/// Como el proyecto está en el plan gratuito de Firebase no hay Cloud
/// Functions: la app recalcula estos dos valores en la misma transacción en
/// la que guarda la reseña. Aquí está solo la cuenta, sin Firebase, para
/// poder probarla sola. Las reseñas ocultas no cuentan.
class AgregadoResenas {
  const AgregadoResenas({required this.promedio, required this.total});

  final double promedio;
  final int total;

  /// Resultado de guardar una reseña con [nueva] estrellas.
  ///
  /// - Reseña nueva ([anterior] null): el total sube 1.
  /// - Edición de una reseña visible: el total queda igual y la puntuación
  ///   [anterior] se cambia por la [nueva] dentro del promedio.
  /// - Edición de una reseña oculta ([anteriorOculta]): no cambia nada,
  ///   porque no contaba ni sigue contando.
  AgregadoResenas alGuardar({
    required int nueva,
    int? anterior,
    bool anteriorOculta = false,
  }) {
    if (anterior == null) return agregar(nueva);
    if (anteriorOculta) return this;
    // Datos inconsistentes (una reseña visible con total 0): se arranca de
    // nuevo con esta reseña en lugar de dividir entre cero.
    if (total <= 0) return AgregadoResenas(promedio: _limitar(nueva * 1.0), total: 1);
    return AgregadoResenas(
      promedio: _limitar((promedio * total - anterior + nueva) / total),
      total: total,
    );
  }

  /// Suma una reseña visible; por ejemplo, cuando el administrador vuelve a
  /// mostrar una que estaba oculta.
  AgregadoResenas agregar(int puntuacion) {
    final nuevoTotal = total + 1;
    return AgregadoResenas(
      promedio: _limitar((promedio * total + puntuacion) / nuevoTotal),
      total: nuevoTotal,
    );
  }

  /// Quita una reseña visible; por ejemplo, cuando el administrador la
  /// oculta.
  AgregadoResenas quitar(int puntuacion) {
    if (total <= 1) return const AgregadoResenas(promedio: 0, total: 0);
    final nuevoTotal = total - 1;
    return AgregadoResenas(
      promedio: _limitar((promedio * total - puntuacion) / nuevoTotal),
      total: nuevoTotal,
    );
  }

  /// El promedio siempre queda entre 0 y 5, aunque los datos guardados
  /// estuvieran mal.
  static double _limitar(double valor) => valor.clamp(0, 5).toDouble();

  @override
  bool operator ==(Object other) =>
      other is AgregadoResenas &&
      (other.promedio - promedio).abs() < 1e-9 &&
      other.total == total;

  @override
  int get hashCode => Object.hash(total, (promedio * 1e6).round());

  @override
  String toString() => 'AgregadoResenas(promedio: $promedio, total: $total)';
}

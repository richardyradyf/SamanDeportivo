import 'package:flutter/foundation.dart';

/// Un tiempo medido en la app y si cumple su límite (Hito 4, rendimiento).
class Medicion {
  const Medicion({
    required this.evento,
    required this.duracion,
    required this.limite,
  });

  final String evento;
  final Duration duracion;
  final Duration limite;

  bool get cumple => duracion <= limite;

  @override
  String toString() =>
      '[rendimiento] $evento: ${duracion.inMilliseconds} ms '
      '(límite ${limite.inMilliseconds} ms) ${cumple ? 'OK' : 'LENTO'}';
}

/// Registro de los tiempos que pide el Hito 4.
///
/// Fuera del modo release cada medición se escribe en la consola de
/// depuración, así se puede leer al correr la app con
/// `flutter run --profile`. Las mediciones también quedan en [registro]
/// para las pruebas.
abstract final class MedicionRendimiento {
  /// La app tiene que mostrar el catálogo en menos de 3 segundos.
  static const limiteCarga = Duration(seconds: 3);

  /// Un cambio de cupos tiene que verse en menos de 2 segundos.
  static const limiteCupos = Duration(seconds: 2);

  static final List<Medicion> registro = [];

  static Medicion registrar(
    String evento,
    Duration duracion, {
    required Duration limite,
  }) {
    final medicion = Medicion(
      evento: evento,
      duracion: duracion,
      limite: limite,
    );
    registro.add(medicion);
    if (!kReleaseMode) debugPrint(medicion.toString());
    return medicion;
  }
}

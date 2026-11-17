import 'dart:async';

import 'package:saman_deportivo/features/entrenador/dashboard/resumen_entrenador.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Asistencias de un deporte. Se consulta por deporte y entrenador
/// porque así lo exigen las reglas de Firestore.
typedef AsistenciasDeDeporte = Stream<List<Asistencia>> Function(
  String codigoDeporte,
);

/// Resumen del Dashboard en tiempo real.
///
/// Cada vez que cambian los deportes del entrenador se cancelan las
/// consultas de asistencia anteriores y se abre una por cada deporte
/// activo. Cada vez que llega una respuesta, se recalcula el resumen.
Stream<ResumenEntrenador> resumenEnVivo({
  required Stream<List<Deporte>> deportes,
  required AsistenciasDeDeporte asistenciasDe,
  DateTime Function() reloj = DateTime.now,
}) {
  late final StreamController<ResumenEntrenador> salida;
  StreamSubscription<List<Deporte>>? subDeportes;
  var subsAsistencias = <StreamSubscription<List<Asistencia>>>[];

  Future<void> cancelarAsistencias() async {
    final anteriores = subsAsistencias;
    subsAsistencias = [];
    for (final sub in anteriores) {
      await sub.cancel();
    }
  }

  void alCambiarDeportes(List<Deporte> lista) {
    unawaited(cancelarAsistencias());
    final activos = lista.where((d) => d.activo).toList();
    final porDeporte = <String, List<Asistencia>>{};

    void emitir() {
      // Espera la primera respuesta de cada deporte para no mostrar
      // un porcentaje a medias.
      if (porDeporte.length < activos.length) return;
      salida.add(
        ResumenEntrenador.calcular(
          deportes: lista,
          asistencias: [for (final r in porDeporte.values) ...r],
          ahora: reloj(),
        ),
      );
    }

    if (activos.isEmpty) {
      emitir();
      return;
    }
    for (final deporte in activos) {
      subsAsistencias.add(
        asistenciasDe(deporte.codigo).listen((registros) {
          porDeporte[deporte.codigo] = registros;
          emitir();
        }, onError: salida.addError),
      );
    }
  }

  salida = StreamController<ResumenEntrenador>(
    onListen: () {
      subDeportes = deportes.listen(
        alCambiarDeportes,
        onError: salida.addError,
      );
    },
    onCancel: () async {
      await subDeportes?.cancel();
      await cancelarAsistencias();
    },
  );
  return salida.stream;
}

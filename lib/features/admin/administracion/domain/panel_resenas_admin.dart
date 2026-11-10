import 'dart:async';

import 'package:saman_deportivo/features/admin/administracion/data/resenas_admin_repository.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Reseña acompañada de su deporte de origen.
/// La colección Firestore sigue siendo deportes/{codigo}/resenas/{uid}.
class ResenaConDeporte {
  const ResenaConDeporte({required this.deporte, required this.resena});

  final Deporte deporte;
  final Resena resena;
}

class PanelResenasAdmin {
  const PanelResenasAdmin({required this.deportes, required this.resenas});

  final List<Deporte> deportes;
  final List<ResenaConDeporte> resenas;
}

/// Combina las subcolecciones de los deportes registrados sin usar
/// collectionGroup, que requeriría permisos adicionales sobre las reseñas.
/// Emite solo cuando todos los deportes tienen su primera respuesta.
/// Si se crea/elimina un deporte, ajusta las suscripciones automáticamente.
Stream<PanelResenasAdmin> observarPanelResenas(
  ResenasAdminRepository repositorio,
) {
  late final StreamController<PanelResenasAdmin> controlador;
  StreamSubscription<List<Deporte>>? suscripcionDeportes;
  final suscripcionesResenas = <String, StreamSubscription<List<Resena>>>{};
  final resenasPorDeporte = <String, List<Resena>>{};
  var deportes = <String, Deporte>{};
  var recibioDeportes = false;

  void emitir() {
    if (controlador.isClosed ||
        !recibioDeportes ||
        deportes.keys.any((codigo) => !resenasPorDeporte.containsKey(codigo))) {
      return;
    }
    final registros = <ResenaConDeporte>[
      for (final deporte in deportes.values)
        for (final resena in resenasPorDeporte[deporte.codigo]!)
          ResenaConDeporte(deporte: deporte, resena: resena),
    ]..sort((a, b) => b.resena.fecha.compareTo(a.resena.fecha));

    controlador.add(
      PanelResenasAdmin(
        deportes: List<Deporte>.unmodifiable(deportes.values),
        resenas: List<ResenaConDeporte>.unmodifiable(registros),
      ),
    );
  }

  void actualizarDeportes(List<Deporte> nuevos) {
    final siguientes = {for (final deporte in nuevos) deporte.codigo: deporte};
    for (final codigo in suscripcionesResenas.keys.toList()) {
      if (!siguientes.containsKey(codigo)) {
        unawaited(suscripcionesResenas.remove(codigo)!.cancel());
        resenasPorDeporte.remove(codigo);
      }
    }
    deportes = siguientes;
    recibioDeportes = true;
    for (final codigo in siguientes.keys) {
      if (suscripcionesResenas.containsKey(codigo)) continue;
      suscripcionesResenas[codigo] = repositorio.observarResenas(codigo).listen(
        (registros) {
          if (!deportes.containsKey(codigo)) return;
          resenasPorDeporte[codigo] = registros;
          emitir();
        },
        onError: controlador.addError,
      );
    }
    emitir();
  }

  controlador = StreamController<PanelResenasAdmin>(
    onListen: () {
      suscripcionDeportes = repositorio.observarDeportes().listen(
        actualizarDeportes,
        onError: controlador.addError,
      );
    },
    onCancel: () async {
      await suscripcionDeportes?.cancel();
      await Future.wait(suscripcionesResenas.values.map((s) => s.cancel()));
      suscripcionesResenas.clear();
    },
  );
  return controlador.stream;
}

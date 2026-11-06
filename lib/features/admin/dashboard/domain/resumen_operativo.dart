import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

/// Métricas operativas derivadas de documentos reales.
/// No sustituye fuentes ausentes por una colección vacía: la capa de
/// presentación diferencia una lectura correcta de un error de permisos.
class ResumenInscripciones {
  const ResumenInscripciones({
    required this.porEstado,
    required this.recientes,
  });

  final Map<EstadoInscripcion, int> porEstado;
  final int recientes;

  int get total => porEstado.values.fold(0, (a, b) => a + b);
  int get pendientes => porEstado[EstadoInscripcion.pendiente] ?? 0;
  int get confirmadas => porEstado[EstadoInscripcion.confirmada] ?? 0;
  int get ocupanCupo => pendientes + confirmadas;

  static ResumenInscripciones calcular(
    List<Inscripcion> inscripciones, {
    DateTime? ahora,
  }) {
    final referencia = ahora ?? DateTime.now();
    final desde = referencia.subtract(const Duration(days: 30));
    final conteos = {for (final estado in EstadoInscripcion.values) estado: 0};
    var recientes = 0;
    for (final inscripcion in inscripciones) {
      conteos[inscripcion.estado] = conteos[inscripcion.estado]! + 1;
      if (!inscripcion.fechaInscripcion.isBefore(desde) &&
          !inscripcion.fechaInscripcion.isAfter(referencia)) {
        recientes++;
      }
    }
    return ResumenInscripciones(
      porEstado: Map.unmodifiable(conteos),
      recientes: recientes,
    );
  }
}

/// Ingresos brutos confirmados en USD. No descuenta comisiones ni refleja
/// ingresos netos. Excluye expresamente pagos reembolsados y otras monedas.
class ResumenPagos {
  const ResumenPagos({
    required this.total,
    required this.aprobadosUsd,
    required this.montoAprobadoUsd,
    required this.reembolsados,
    required this.aprobadosOtrasMonedas,
  });

  final int total;
  final int aprobadosUsd;
  final double montoAprobadoUsd;
  final int reembolsados;
  final int aprobadosOtrasMonedas;

  static ResumenPagos calcular(List<Pago> pagos) {
    var aprobadosUsd = 0;
    var monto = 0.0;
    var reembolsados = 0;
    var otrasMonedas = 0;
    for (final pago in pagos) {
      if (pago.estado == EstadoPago.reembolsado) {
        reembolsados++;
        continue;
      }
      if (pago.estado != EstadoPago.aprobado) continue;
      if (pago.moneda.toUpperCase() == 'USD') {
        aprobadosUsd++;
        monto += pago.monto;
      } else {
        otrasMonedas++;
      }
    }
    return ResumenPagos(
      total: pagos.length,
      aprobadosUsd: aprobadosUsd,
      montoAprobadoUsd: monto,
      reembolsados: reembolsados,
      aprobadosOtrasMonedas: otrasMonedas,
    );
  }
}

class TerminoBuscado {
  const TerminoBuscado(this.termino, this.cantidad);
  final String termino;
  final int cantidad;
}

/// Resume EVENTOS de búsqueda, no clics ni inscripciones.
/// No atribuye una búsqueda a un deporte por haber salido en resultados.
class ResumenBusquedas {
  const ResumenBusquedas({required this.eventos, required this.topTerminos});

  final int eventos;
  final List<TerminoBuscado> topTerminos;

  static ResumenBusquedas calcular(
    List<Busqueda> busquedas, {
    DateTime? ahora,
    int limite = 5,
  }) {
    final referencia = ahora ?? DateTime.now();
    final desde = referencia.subtract(const Duration(days: 30));
    final conteos = <String, int>{};
    var eventos = 0;
    for (final busqueda in busquedas) {
      if (busqueda.fecha.isBefore(desde) ||
          busqueda.fecha.isAfter(referencia)) {
        continue;
      }
      eventos++;
      final termino = normalizarBusqueda(busqueda.termino);
      if (termino.isEmpty) continue;
      conteos[termino] = (conteos[termino] ?? 0) + 1;
    }
    final ordenados = conteos.entries.toList()
      ..sort((a, b) {
        final porCantidad = b.value.compareTo(a.value);
        return porCantidad != 0 ? porCantidad : a.key.compareTo(b.key);
      });
    return ResumenBusquedas(
      eventos: eventos,
      topTerminos: List.unmodifiable(
        ordenados
            .take(limite)
            .map((entrada) => TerminoBuscado(entrada.key, entrada.value)),
      ),
    );
  }
}

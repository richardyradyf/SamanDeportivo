import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_operativo.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

final ahora = DateTime.utc(2026, 11, 6);

Inscripcion inscripcion(EstadoInscripcion estado, {int diasAtras = 0}) {
  final fecha = ahora.subtract(Duration(days: diasAtras));
  return Inscripcion(
    id: 'ins-${estado.name}-$diasAtras',
    estudianteUid: 'est-1',
    estudianteCedula: '12345678',
    estudianteNombre: 'Estudiante',
    estudianteCarnet: '202600001',
    estudianteCorreo: 'estudiante@unimet.edu.ve',
    deporteId: 'FUT-01',
    deporteNombre: 'Fútbol',
    estado: estado,
    fechaInscripcion: fecha,
    fechaLimitePago: fecha.add(const Duration(hours: 24)),
  );
}

Pago pago(
  EstadoPago estado,
  double monto, {
  String moneda = 'USD',
  String id = 'pago',
}) => Pago(
  id: id,
  inscripcionId: 'ins-1',
  estudianteUid: 'est-1',
  deporteId: 'FUT-01',
  deporteNombre: 'Fútbol',
  paypalOrderId: 'order-1',
  monto: monto,
  estado: estado,
  moneda: moneda,
  fecha: ahora,
);

Busqueda busqueda(String termino, {int diasAtras = 0}) => Busqueda(
  id: 'b-$termino-$diasAtras',
  termino: termino,
  fecha: ahora.subtract(Duration(days: diasAtras)),
);

void main() {
  test('inscripciones vacías arrojan cero para todos los estados', () {
    final r = ResumenInscripciones.calcular([], ahora: ahora);
    expect(r.total, 0);
    for (final estado in EstadoInscripcion.values) {
      expect(r.porEstado[estado], 0);
    }
  });

  test('inscripciones cuentan estados y cupos retenidos', () {
    final r = ResumenInscripciones.calcular([
      inscripcion(EstadoInscripcion.pendiente),
      inscripcion(EstadoInscripcion.confirmada),
      inscripcion(EstadoInscripcion.cancelada),
      inscripcion(EstadoInscripcion.expirada),
      inscripcion(EstadoInscripcion.rechazada),
    ], ahora: ahora);
    expect(r.total, 5);
    expect(r.pendientes, 1);
    expect(r.confirmadas, 1);
    expect(r.ocupanCupo, 2);
  });

  test('recientes incluye día 30, excluye antiguos y fechas futuras', () {
    final r = ResumenInscripciones.calcular([
      inscripcion(EstadoInscripcion.pendiente, diasAtras: 30),
      inscripcion(EstadoInscripcion.confirmada, diasAtras: 31),
    ], ahora: ahora);
    expect(r.recientes, 1);
  });

  test('pagos vacíos no cuentan montos', () {
    final r = ResumenPagos.calcular([]);
    expect(r.total, 0);
    expect(r.montoAprobadoUsd, 0);
  });

  test('solo pagos aprobados en USD suman al monto', () {
    final r = ResumenPagos.calcular([
      pago(EstadoPago.aprobado, 10, id: 'p1'),
      pago(EstadoPago.aprobado, 15.5, id: 'p2'),
      pago(EstadoPago.pendiente, 200, id: 'p3'),
      pago(EstadoPago.rechazado, 200, id: 'p4'),
    ]);
    expect(r.montoAprobadoUsd, 25.5);
    expect(r.aprobadosUsd, 2);
    expect(r.total, 4);
  });

  test('reembolsos y otras monedas no son ingresos USD aprobados', () {
    final r = ResumenPagos.calcular([
      pago(EstadoPago.reembolsado, 25, id: 'p1'),
      pago(EstadoPago.aprobado, 90, moneda: 'EUR', id: 'p2'),
      pago(EstadoPago.aprobado, 10, moneda: 'usd', id: 'p3'),
    ]);
    expect(r.montoAprobadoUsd, 10);
    expect(r.reembolsados, 1);
    expect(r.aprobadosOtrasMonedas, 1);
  });

  test('búsquedas sin eventos arrojan cero y top vacío', () {
    final r = ResumenBusquedas.calcular([], ahora: ahora);
    expect(r.eventos, 0);
    expect(r.topTerminos, isEmpty);
  });

  test('búsquedas agrupan fútbol y futbol ignorando tildes', () {
    final r = ResumenBusquedas.calcular([
      busqueda('Fútbol'),
      busqueda('futbol'),
      busqueda(' FÚTBOL '),
    ], ahora: ahora);
    expect(r.eventos, 3);
    expect(r.topTerminos.single.termino, 'futbol');
    expect(r.topTerminos.single.cantidad, 3);
  });

  test('búsquedas excluyen eventos fuera de últimos 30 días', () {
    final r = ResumenBusquedas.calcular([
      busqueda('tenis', diasAtras: 31),
      busqueda('natacion', diasAtras: 30),
    ], ahora: ahora);
    expect(r.eventos, 1);
    expect(r.topTerminos.single.termino, 'natacion');
  });

  test('términos se ordenan por frecuencia y luego alfabéticamente', () {
    final r = ResumenBusquedas.calcular(
      [
        busqueda('tenis'),
        busqueda('futbol'),
        busqueda('futbol'),
        busqueda('natacion'),
        busqueda('tenis'),
      ],
      ahora: ahora,
      limite: 2,
    );
    expect(r.topTerminos.map((t) => t.termino).toList(), ['futbol', 'tenis']);
  });
}

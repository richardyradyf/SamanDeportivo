import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/operaciones_dashboard_repository.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

void main() {
  test('A3.8: ignora una inscripción malformada y mantiene la válida', () {
    final resultado = procesarDocumentosOperativos<Inscripcion>([
      const MapEntry('ok', <String, dynamic>{'estado': 'pendiente'}),
      const MapEntry('mal', <String, dynamic>{'estado': 'inexistente'}),
      const MapEntry('sin-estado', <String, dynamic>{}),
    ], Inscripcion.fromMap);
    expect(resultado.registros.map((i) => i.id), ['ok']);
    expect(resultado.omitidos, 2);
  });

  test('A3.8: omite pago sin estado y monto de tipo erróneo', () {
    final resultado = procesarDocumentosOperativos<Pago>([
      const MapEntry('ok', <String, dynamic>{
        'estado': 'aprobado',
        'monto': 12,
      }),
      const MapEntry('mal-estado', <String, dynamic>{'estado': 'imposible'}),
      const MapEntry('mal-monto', <String, dynamic>{
        'estado': 'aprobado',
        'monto': '12',
      }),
      const MapEntry('sin-estado', <String, dynamic>{}),
    ], Pago.fromMap);
    expect(resultado.registros, hasLength(1));
    expect(resultado.registros.single.id, 'ok');
    expect(resultado.registros.single.monto, 12);
    expect(resultado.omitidos, 3);
  });

  test('A3.8: colección legítimamente vacía no produce descartes', () {
    final resultado = procesarDocumentosOperativos<String>(
      const <MapEntry<String, Map<String, dynamic>>>[],
      (id, _) => id,
    );
    expect(resultado.registros, isEmpty);
    expect(resultado.omitidos, 0);
  });
}

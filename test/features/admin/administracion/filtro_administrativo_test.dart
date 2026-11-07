import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/administracion/domain/filtro_administrativo.dart';

void main() {
  test('ignora tildes y mayúsculas', () {
    expect(normalizarTextoAdministrativo('FÚTBOL'), 'futbol');
    expect(normalizarTextoAdministrativo('José Muñoz'), 'jose munoz');
  });

  test('normaliza espacios', () {
    expect(normalizarTextoAdministrativo('  Ana   Pérez  '), 'ana perez');
  });

  test('mantiene números de cédula y carnet', () {
    expect(normalizarTextoAdministrativo('  V-12345678 '), 'v-12345678');
  });
}

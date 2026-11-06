import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';

void main() {
  test('fut encuentra Fútbol y futbol encuentra Fútbol', () {
    final nombre = normalizarBusqueda('Fútbol sala');
    expect(nombre.contains(normalizarBusqueda('fut')), isTrue);
    expect(nombre.contains(normalizarBusqueda('futbol')), isTrue);
    expect(nombre.contains(normalizarBusqueda('FÚTBOL')), isTrue);
  });

  test('ignora tildes, mayúsculas y espacios exteriores', () {
    expect(normalizarBusqueda(' NATACIÓN '), 'natacion');
    expect(normalizarBusqueda('José Muñoz'), 'jose munoz');
    expect(normalizarBusqueda('Kárate'), 'karate');
  });

  test('admite diacríticos Unicode combinados', () {
    expect(normalizarBusqueda('Fu\u0301tbol'), 'futbol');
  });

  test('no modifica el texto original presentado al usuario', () {
    const nombre = 'Fútbol sala';
    normalizarBusqueda(nombre);
    expect(nombre, 'Fútbol sala');
  });
}

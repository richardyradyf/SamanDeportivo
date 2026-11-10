import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/registro_busquedas.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';

class _BusquedasFalsas implements BusquedaRepository {
  _BusquedasFalsas({this.fallar = false});

  final bool fallar;
  final guardadas = <Busqueda>[];

  @override
  Future<void> registrar(Busqueda busqueda) async {
    if (fallar) throw Exception('sin permiso');
    guardadas.add(busqueda);
  }

  @override
  Stream<List<Busqueda>> observarDesde(DateTime desde) =>
      const Stream.empty();
}

Deporte _deporte(String codigo) => Deporte(
  codigo: codigo,
  nombre: codigo,
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 11, 1),
);

/// Deja que terminen los guardados que [RegistroBusquedas] lanzó.
Future<void> _esperarGuardado() => Future<void>.delayed(Duration.zero);

void main() {
  final fecha = DateTime(2026, 11, 7, 20, 30);

  RegistroBusquedas registro(BusquedaRepository repositorio) =>
      RegistroBusquedas(
        repositorio: repositorio,
        usuarioUid: 'uid-ana',
        reloj: () => fecha,
      );

  test('al confirmar guarda texto, filtros, resultados, usuario y fecha',
      () async {
    final busquedas = _BusquedasFalsas();
    const filtro = FiltroCatalogo(
      texto: '  Fútbol ',
      disciplina: Disciplina.colectivo,
    );

    registro(busquedas).confirmar(filtro, [_deporte('FUT-01')]);
    await _esperarGuardado();

    final guardada = busquedas.guardadas.single;
    expect(guardada.termino, 'Fútbol');
    expect(guardada.filtros, {'disciplina': 'colectivo'});
    expect(guardada.deporteIds, ['FUT-01']);
    expect(guardada.usuarioUid, 'uid-ana');
    expect(guardada.fecha, fecha);
  });

  test('el catálogo sin texto ni filtros no cuenta como búsqueda', () async {
    final busquedas = _BusquedasFalsas();

    registro(busquedas).confirmar(const FiltroCatalogo(texto: '  '), []);
    await _esperarGuardado();

    expect(busquedas.guardadas, isEmpty);
  });

  test('no repite la misma búsqueda dos veces seguidas', () async {
    final busquedas = _BusquedasFalsas();
    final r = registro(busquedas);

    r.confirmar(const FiltroCatalogo(texto: 'natación'), []);
    r.confirmar(const FiltroCatalogo(texto: 'NATACION'), []);
    r.confirmar(const FiltroCatalogo(texto: 'tenis'), []);
    await _esperarGuardado();

    expect(busquedas.guardadas.map((b) => b.termino), ['natación', 'tenis']);
  });

  test('respeta los límites de las reglas', () async {
    final busquedas = _BusquedasFalsas();
    final muchos = [for (var i = 0; i < 60; i++) _deporte('DEP-$i')];

    registro(busquedas).confirmar(FiltroCatalogo(texto: 'a' * 200), muchos);
    await _esperarGuardado();

    final guardada = busquedas.guardadas.single;
    expect(guardada.termino.length, RegistroBusquedas.maxTermino);
    expect(guardada.deporteIds, hasLength(RegistroBusquedas.maxDeportes));
  });

  test('si no se puede guardar, no rompe nada', () async {
    final busquedas = _BusquedasFalsas(fallar: true);

    registro(busquedas).confirmar(const FiltroCatalogo(texto: 'tenis'), []);
    await _esperarGuardado();

    expect(busquedas.guardadas, isEmpty);
  });

  test('la clave de una búsqueda ignora tildes, mayúsculas y orden', () {
    expect(
      RegistroBusquedas.claveDe(
        const FiltroCatalogo(texto: 'Fútbol', soloConCupo: true),
      ),
      RegistroBusquedas.claveDe(
        const FiltroCatalogo(texto: 'futbol', soloConCupo: true),
      ),
    );
    expect(
      RegistroBusquedas.claveDe(const FiltroCatalogo(texto: 'futbol')),
      isNot(
        RegistroBusquedas.claveDe(
          const FiltroCatalogo(texto: 'futbol', soloConCupo: true),
        ),
      ),
    );
  });
}

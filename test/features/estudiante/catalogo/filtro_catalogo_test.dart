import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

Deporte _deporte(
  String codigo,
  String nombre,
  Disciplina disciplina, {
  int cupoMaximo = 20,
  int cuposOcupados = 0,
  String? especialidad,
  List<HorarioSesion> horarios = const [],
}) {
  return Deporte(
    codigo: codigo,
    nombre: nombre,
    descripcion: '',
    disciplina: disciplina,
    costo: 10,
    cupoMaximo: cupoMaximo,
    cuposOcupados: cuposOcupados,
    entrenadorEspecialidad: especialidad,
    horarios: horarios,
    creadoEn: DateTime(2026, 11, 1),
  );
}

HorarioSesion _sesion(DiaSemana dia, String inicio, String fin) =>
    HorarioSesion(dia: dia, horaInicio: inicio, horaFin: fin, lugar: 'Cancha');

final _catalogo = [
  _deporte(
    'TEN-01',
    'Tenis',
    Disciplina.raqueta,
    cupoMaximo: 2,
    cuposOcupados: 2, // sin cupo
    especialidad: 'Tenis',
    horarios: [_sesion(DiaSemana.martes, '08:00', '10:00')],
  ),
  _deporte(
    'FUT-01',
    'Fútbol sala',
    Disciplina.colectivo,
    especialidad: 'Fútbol',
    horarios: [
      _sesion(DiaSemana.lunes, '16:00', '18:00'),
      _sesion(DiaSemana.miercoles, '16:00', '18:00'),
    ],
  ),
  _deporte(
    'NAT-01',
    'Natación',
    Disciplina.acuatico,
    especialidad: 'Natación',
    horarios: [_sesion(DiaSemana.lunes, '07:00', '08:30')],
  ),
  _deporte(
    'BAS-01',
    'Baloncesto',
    Disciplina.colectivo,
    especialidad: 'Baloncesto',
    horarios: [_sesion(DiaSemana.jueves, '18:30', '20:00')],
  ),
];

List<String> _codigos(List<Deporte> deportes) =>
    deportes.map((d) => d.codigo).toList();

void main() {
  group('Búsqueda', () {
    test('sin texto ni filtros devuelve todo, ordenado por nombre', () {
      const filtro = FiltroCatalogo();

      expect(filtro.estaVacio, isTrue);
      expect(
        _codigos(filtro.aplicar(_catalogo)),
        ['BAS-01', 'FUT-01', 'NAT-01', 'TEN-01'],
      );
    });

    test('ignora mayúsculas y tildes', () {
      expect(
        _codigos(const FiltroCatalogo(texto: 'FUTBOL').aplicar(_catalogo)),
        ['FUT-01'],
      );
      expect(
        _codigos(const FiltroCatalogo(texto: 'natacion').aplicar(_catalogo)),
        ['NAT-01'],
      );
    });

    test('encuentra por parte del nombre y por código', () {
      expect(
        _codigos(const FiltroCatalogo(texto: 'bal').aplicar(_catalogo)),
        ['BAS-01'],
      );
      expect(
        _codigos(const FiltroCatalogo(texto: 'ten-01').aplicar(_catalogo)),
        ['TEN-01'],
      );
    });

    test('un texto que no coincide no devuelve resultados', () {
      expect(const FiltroCatalogo(texto: 'ajedrez').aplicar(_catalogo), isEmpty);
    });
  });

  group('Filtros', () {
    test('por disciplina', () {
      const filtro = FiltroCatalogo(disciplina: Disciplina.colectivo);

      expect(_codigos(filtro.aplicar(_catalogo)), ['BAS-01', 'FUT-01']);
    });

    test('solo con cupo deja fuera los deportes llenos', () {
      const filtro = FiltroCatalogo(soloConCupo: true);

      expect(_codigos(filtro.aplicar(_catalogo)), isNot(contains('TEN-01')));
      expect(filtro.aplicar(_catalogo), hasLength(3));
    });

    test('por día de la semana', () {
      const filtro = FiltroCatalogo(dia: DiaSemana.lunes);

      expect(_codigos(filtro.aplicar(_catalogo)), ['FUT-01', 'NAT-01']);
    });

    test('por turno, según la hora de inicio', () {
      expect(
        _codigos(const FiltroCatalogo(turno: Turno.manana).aplicar(_catalogo)),
        ['NAT-01', 'TEN-01'],
      );
      expect(
        _codigos(const FiltroCatalogo(turno: Turno.noche).aplicar(_catalogo)),
        ['BAS-01'],
      );
    });

    test('día y turno se exigen en la misma sesión', () {
      const filtro =
          FiltroCatalogo(dia: DiaSemana.lunes, turno: Turno.tarde);

      // Natación va el lunes, pero en la mañana.
      expect(_codigos(filtro.aplicar(_catalogo)), ['FUT-01']);
    });

    test('por especialidad del entrenador, sin distinguir tildes', () {
      const filtro = FiltroCatalogo(especialidad: 'futbol');

      expect(_codigos(filtro.aplicar(_catalogo)), ['FUT-01']);
    });

    test('combina texto y filtros', () {
      const filtro = FiltroCatalogo(texto: 'a', soloConCupo: true);

      // "Tenis" no tiene "a", pero igual queda fuera por no tener cupo.
      expect(
        _codigos(filtro.aplicar(_catalogo)),
        ['BAS-01', 'FUT-01', 'NAT-01'],
      );
    });

    test('ningún deporte cumple una combinación imposible', () {
      const filtro = FiltroCatalogo(
        disciplina: Disciplina.acuatico,
        dia: DiaSemana.jueves,
      );

      expect(filtro.aplicar(_catalogo), isEmpty);
    });
  });

  group('Estado del filtro', () {
    test('cuenta los filtros activos sin contar el texto', () {
      const filtro = FiltroCatalogo(
        texto: 'fut',
        disciplina: Disciplina.colectivo,
        soloConCupo: true,
      );

      expect(filtro.cantidadFiltros, 2);
      expect(filtro.estaVacio, isFalse);
    });

    test('limpiar los filtros conserva el texto', () {
      const filtro = FiltroCatalogo(texto: 'fut', dia: DiaSemana.lunes);
      final limpio = filtro.limpiarFiltros();

      expect(limpio.texto, 'fut');
      expect(limpio.cantidadFiltros, 0);
    });

    test('copyWith puede quitar un filtro', () {
      const filtro = FiltroCatalogo(dia: DiaSemana.lunes, turno: Turno.tarde);
      final sinDia = filtro.copyWith(sinDia: true);

      expect(sinDia.dia, isNull);
      expect(sinDia.turno, Turno.tarde);
    });

    test('aMapa guarda solo los filtros activos, para la métrica de búsquedas',
        () {
      const filtro = FiltroCatalogo(
        texto: 'fut',
        disciplina: Disciplina.colectivo,
        soloConCupo: true,
      );

      expect(filtro.aMapa(), {'disciplina': 'colectivo', 'soloConCupo': true});
      expect(const FiltroCatalogo().aMapa(), isEmpty);
    });

    test('lista las especialidades sin repetir y en orden', () {
      expect(
        FiltroCatalogo.especialidadesDe(_catalogo),
        ['Baloncesto', 'Fútbol', 'Natación', 'Tenis'],
      );
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Repositorio falso: entrega el catálogo que se le pase, sin Firebase.
class _RepositorioFalso implements DeporteRepository {
  _RepositorioFalso(this._catalogo);

  final Stream<List<Deporte>> _catalogo;

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      _catalogo;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El catálogo no usa ${invocation.memberName}');
}

Deporte _deporte(
  String codigo,
  String nombre,
  Disciplina disciplina, {
  int cupoMaximo = 20,
  int cuposOcupados = 0,
  String? entrenador,
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
    entrenadorUid: entrenador == null ? null : 'uid-$codigo',
    entrenadorNombre: entrenador,
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
    cuposOcupados: 2,
    entrenador: 'Laura Díaz',
    especialidad: 'Tenis',
    horarios: [_sesion(DiaSemana.martes, '08:00', '10:00')],
  ),
  _deporte(
    'FUT-01',
    'Fútbol sala',
    Disciplina.colectivo,
    entrenador: 'Pedro Gómez',
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
    cupoMaximo: 12,
    cuposOcupados: 10,
    horarios: [_sesion(DiaSemana.viernes, '07:00', '09:00')],
  ),
  _deporte(
    'BAS-01',
    'Baloncesto',
    Disciplina.colectivo,
    cupoMaximo: 15,
    entrenador: 'Ana Ruiz',
    especialidad: 'Baloncesto',
    horarios: [_sesion(DiaSemana.jueves, '18:30', '20:00')],
  ),
];

final _buscador = find.byKey(const Key('buscadorCatalogo'));

const _celular = Size(400, 900);
const _escritorio = Size(1400, 1000);

Future<void> _mostrar(
  WidgetTester tester,
  Widget pantalla, {
  Size tamano = _celular,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(body: pantalla),
    ),
  );
  await tester.pump();
}

CatalogoScreen _catalogoCon(
  List<Deporte> deportes, {
  void Function(Deporte)? onVerDeporte,
}) => CatalogoScreen(
  repositorio: _RepositorioFalso(Stream.value(deportes)),
  onVerDeporte: onVerDeporte,
);

void main() {
  group('Catálogo', () {
    testWidgets('muestra código, nombre, horario, entrenador y cupos', (
      tester,
    ) async {
      await _mostrar(tester, _catalogoCon(_catalogo));

      expect(find.text('4 deportes'), findsOneWidget);
      expect(find.text('FUT-01'), findsOneWidget);
      expect(find.text('FÚTBOL SALA'), findsOneWidget);
      expect(find.text('Lun / Mié · 16:00'), findsOneWidget);
      expect(find.text('Pedro Gómez'), findsOneWidget);
      expect(find.text('20 cupos disponibles'), findsOneWidget);
    });

    testWidgets('marca los deportes llenos y los que tienen pocos cupos', (
      tester,
    ) async {
      await _mostrar(tester, _catalogoCon(_catalogo));

      expect(find.text('Sin cupos'), findsOneWidget); // Tenis
      expect(find.text('2 cupos disponibles'), findsOneWidget); // Natación
      expect(find.text('Entrenador por asignar'), findsOneWidget);
    });

    testWidgets('mientras carga muestra un indicador', (tester) async {
      final controlador = StreamController<List<Deporte>>();
      addTearDown(controlador.close);

      await _mostrar(
        tester,
        CatalogoScreen(repositorio: _RepositorioFalso(controlador.stream)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('si falla la carga muestra un mensaje de error', (
      tester,
    ) async {
      await _mostrar(
        tester,
        CatalogoScreen(
          repositorio: _RepositorioFalso(Stream.error(Exception('sin red'))),
        ),
      );

      expect(find.text('No pudimos cargar los deportes'), findsOneWidget);
    });

    testWidgets('sin deportes publicados lo dice', (tester) async {
      await _mostrar(tester, _catalogoCon(const []));

      expect(find.text('Todavía no hay deportes publicados'), findsOneWidget);
    });

    testWidgets('tocar una tarjeta avisa qué deporte se eligió', (
      tester,
    ) async {
      Deporte? elegido;
      await _mostrar(
        tester,
        _catalogoCon(_catalogo, onVerDeporte: (d) => elegido = d),
      );

      await tester.tap(find.text('BALONCESTO'));
      expect(elegido?.codigo, 'BAS-01');
    });
  });

  group('Búsqueda', () {
    testWidgets('filtra mientras se escribe, sin importar las tildes', (
      tester,
    ) async {
      await _mostrar(tester, _catalogoCon(_catalogo));

      await tester.enterText(_buscador, 'natacion');
      await tester.pump();

      expect(find.text('1 deporte'), findsOneWidget);
      expect(find.text('NATACIÓN'), findsOneWidget);
      expect(find.text('TENIS'), findsNothing);
    });

    testWidgets('sin resultados ofrece limpiar la búsqueda', (tester) async {
      await _mostrar(tester, _catalogoCon(_catalogo));

      await tester.enterText(_buscador, 'ajedrez');
      await tester.pump();
      expect(find.text('No encontramos deportes'), findsOneWidget);

      await tester.tap(find.text('Limpiar búsqueda y filtros'));
      await tester.pump();

      expect(find.text('4 deportes'), findsOneWidget);
      final campo = tester.widget<TextField>(_buscador);
      expect(campo.controller!.text, isEmpty);
    });
  });

  group('Filtros en computadora', () {
    testWidgets('se ven en un panel lateral, sin botón de filtros', (
      tester,
    ) async {
      await _mostrar(tester, _catalogoCon(_catalogo), tamano: _escritorio);

      expect(find.text('Solo con cupos'), findsOneWidget);
      expect(find.byKey(const Key('botonFiltros')), findsNothing);
    });

    testWidgets('"Solo con cupos" quita los deportes llenos', (tester) async {
      await _mostrar(tester, _catalogoCon(_catalogo), tamano: _escritorio);

      await tester.tap(find.text('Solo con cupos'));
      await tester.pump();

      expect(find.text('3 deportes'), findsOneWidget);
      expect(find.text('TENIS'), findsNothing);
    });

    testWidgets('se combinan disciplina y búsqueda', (tester) async {
      await _mostrar(tester, _catalogoCon(_catalogo), tamano: _escritorio);

      await tester.tap(find.text('Colectivo'));
      await tester.pump();
      expect(find.text('2 deportes'), findsOneWidget);

      await tester.enterText(_buscador, 'fut');
      await tester.pump();
      expect(find.text('1 deporte'), findsOneWidget);
      expect(find.text('FÚTBOL SALA'), findsOneWidget);
    });
  });

  group('Filtros en celular', () {
    testWidgets('se abren en una hoja y el botón cuenta los activos', (
      tester,
    ) async {
      await _mostrar(tester, _catalogoCon(_catalogo));
      expect(find.text('Solo con cupos'), findsNothing);

      await tester.tap(find.byKey(const Key('botonFiltros')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acuático'));
      await tester.pump();

      final verResultados = find.text('Ver resultados');
      await tester.ensureVisible(verResultados);
      await tester.tap(verResultados);
      await tester.pumpAndSettle();

      expect(find.text('Filtros (1)'), findsOneWidget);
      expect(find.text('1 deporte'), findsOneWidget);
      expect(find.text('NATACIÓN'), findsOneWidget);
    });
  });

  testWidgets('la pestaña Explorar del inicio muestra el catálogo', (
    tester,
  ) async {
    await _mostrar(
      tester,
      InicioEstudianteScreen(
        nombre: 'Ana Pérez',
        onCerrarSesion: () {},
        reloj: () => DateTime(2026, 11, 7, 9),
        deportes: _RepositorioFalso(Stream.value(_catalogo)),
      ),
    );

    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Explorar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encuentra una disciplina para ti.'), findsOneWidget);
    expect(find.text('FÚTBOL SALA'), findsOneWidget);
  });
}

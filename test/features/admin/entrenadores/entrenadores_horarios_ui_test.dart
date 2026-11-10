import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/entrenador_repository.dart';
import 'package:saman_deportivo/features/admin/entrenadores/presentation/entrenadores_admin_screen.dart';
import 'package:saman_deportivo/features/admin/entrenadores/presentation/horarios_admin_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/entrenador.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

const entrenador = Entrenador(
  uid: 'ent-1',
  cedula: '12345678',
  nombre: 'Carlos Rojas',
  correo: 'entrenador1@saman.test',
  especialidad: 'Fútbol',
  aniosExperiencia: 8,
);

const lunes16a18 = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '16:00',
  horaFin: '18:00',
  lugar: 'Cancha A',
);
const lunes17a19 = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '17:00',
  horaFin: '19:00',
  lugar: 'Cancha B',
);

Deporte deporte(
  String codigo, {
  String? entrenadorUid,
  String? entrenadorNombre,
  List<HorarioSesion> horarios = const [],
}) {
  return Deporte(
    codigo: codigo,
    nombre: codigo == 'FUT-01' ? 'Fútbol sala' : 'Tenis',
    descripcion: 'Entrenamientos deportivos',
    disciplina: Disciplina.colectivo,
    costo: 0,
    cupoMaximo: 10,
    creadoEn: DateTime(2026, 11, 5),
    horarios: horarios,
    entrenadorUid: entrenadorUid,
    entrenadorNombre: entrenadorNombre,
  );
}

class _EntrenadoresFake implements EntrenadorRepository {
  @override
  Stream<List<Entrenador>> observarEntrenadores() => Stream.value([entrenador]);
}

class _DeportesFake implements DeporteRepository {
  _DeportesFake(this.deportes);

  final List<Deporte> deportes;
  final _cambios = StreamController<List<Deporte>>.broadcast();

  void _emitir() => _cambios.add(List<Deporte>.of(deportes));

  Future<void> cerrar() => _cambios.close();

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) async* {
    yield deportes.where((d) => !soloActivos || d.activo).toList();
    yield* _cambios.stream;
  }

  @override
  Stream<Deporte?> observar(String codigo) async* {
    yield deportes.where((d) => d.codigo == codigo).firstOrNull;
  }

  @override
  Stream<List<Deporte>> observarPorEntrenador(String uid) async* {
    yield deportes.where((d) => d.entrenadorUid == uid).toList();
  }

  @override
  Future<void> crear(Deporte nuevo) async {
    deportes.add(nuevo);
    _emitir();
  }

  @override
  Future<void> actualizar(Deporte nuevo) async {
    final indice = deportes.indexWhere((d) => d.codigo == nuevo.codigo);
    if (indice < 0) {
      throw StateError('No existe');
    }
    deportes[indice] = nuevo;
    _emitir();
  }

  @override
  Future<void> desactivar(String codigo) async {
    final indice = deportes.indexWhere((d) => d.codigo == codigo);
    if (indice < 0) {
      throw StateError('No existe');
    }
    deportes[indice] = deportes[indice].copyWith(activo: false);
    _emitir();
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  Widget pantalla, {
  _DeportesFake? deportes,
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (deportes != null) {
    addTearDown(deportes.cerrar);
  }
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: pantalla)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A2: muestra entrenadores y filtra por especialidad', (
    tester,
  ) async {
    await _mostrar(
      tester,
      EntrenadoresAdminScreen(repositorio: _EntrenadoresFake()),
    );
    expect(find.text('Carlos Rojas'), findsOneWidget);
    expect(find.text('Fútbol'), findsOneWidget);
    // Regresión: especialidad con tilde, búsqueda sin tilde.
    await tester.enterText(
      find.byKey(const Key('buscar-entrenador')),
      'futbol',
    );
    await tester.pumpAndSettle();
    expect(find.text('Carlos Rojas'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('buscar-entrenador')),
      'natación',
    );
    await tester.pumpAndSettle();
    expect(find.text('Carlos Rojas'), findsNothing);
  });

  testWidgets('A2: muestra sesiones y entrenador de cada deporte', (
    tester,
  ) async {
    final repo = _DeportesFake([
      deporte(
        'FUT-01',
        entrenadorUid: 'ent-1',
        entrenadorNombre: 'Carlos Rojas',
        horarios: [lunes16a18],
      ),
    ]);
    await _mostrar(
      tester,
      HorariosAdminScreen(deportes: repo, entrenadores: _EntrenadoresFake()),
      deportes: repo,
    );
    expect(find.text('Fútbol sala'), findsOneWidget);
    // Regresión: deporte con tilde, búsqueda sin tilde en Horarios.
    await tester.enterText(find.byKey(const Key('buscar-agenda')), 'futbol');
    await tester.pumpAndSettle();
    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('Entrenador: Carlos Rojas'), findsOneWidget);
    expect(find.textContaining('16:00 - 18:00'), findsOneWidget);
  });

  testWidgets('A2: asigna entrenador desde diálogo', (tester) async {
    final repo = _DeportesFake([
      deporte('FUT-01', horarios: [lunes16a18]),
    ]);
    await _mostrar(
      tester,
      HorariosAdminScreen(deportes: repo, entrenadores: _EntrenadoresFake()),
      deportes: repo,
    );
    await tester.tap(find.byKey(const Key('asignar-FUT-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seleccionar-entrenador')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Rojas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-asignacion')));
    await tester.pumpAndSettle();
    expect(repo.deportes.single.entrenadorUid, 'ent-1');
    expect(repo.deportes.single.horarios, hasLength(1));
  });

  testWidgets('A2: muestra error cuando hay horario de entrenador solapado', (
    tester,
  ) async {
    final repo = _DeportesFake([
      deporte(
        'FUT-01',
        entrenadorUid: 'ent-1',
        entrenadorNombre: 'Carlos Rojas',
        horarios: [lunes16a18],
      ),
      deporte('TEN-01', horarios: [lunes17a19]),
    ]);
    await _mostrar(
      tester,
      HorariosAdminScreen(deportes: repo, entrenadores: _EntrenadoresFake()),
      deportes: repo,
    );
    await tester.tap(find.byKey(const Key('asignar-TEN-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seleccionar-entrenador')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Rojas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-asignacion')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ya tiene una sesión'), findsOneWidget);
    expect(repo.deportes.last.entrenadorUid, isNull);
  });

  testWidgets('A2: impide guardar horarios con hora inválida', (tester) async {
    final repo = _DeportesFake([
      deporte('FUT-01', horarios: [lunes16a18]),
    ]);
    await _mostrar(
      tester,
      HorariosAdminScreen(deportes: repo, entrenadores: _EntrenadoresFake()),
      deportes: repo,
    );
    await tester.tap(find.byKey(const Key('horarios-FUT-01')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('inicio-0')), '25:99');
    await tester.tap(find.byKey(const Key('guardar-horarios')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hora inválida'), findsOneWidget);
    expect(repo.deportes.single.horarios.single.horaInicio, '16:00');
  });

  testWidgets('A2: desasigna sin borrar horarios', (tester) async {
    final repo = _DeportesFake([
      deporte(
        'FUT-01',
        entrenadorUid: 'ent-1',
        entrenadorNombre: 'Carlos Rojas',
        horarios: [lunes16a18],
      ),
    ]);
    await _mostrar(
      tester,
      HorariosAdminScreen(deportes: repo, entrenadores: _EntrenadoresFake()),
      deportes: repo,
    );
    await tester.tap(find.byKey(const Key('desasignar-FUT-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-desasignacion')));
    await tester.pumpAndSettle();
    expect(repo.deportes.single.entrenadorUid, isNull);
    expect(repo.deportes.single.horarios, hasLength(1));
  });
}

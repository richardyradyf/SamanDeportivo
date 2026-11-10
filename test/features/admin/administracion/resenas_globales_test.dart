import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/administracion/data/resenas_admin_repository.dart';
import 'package:saman_deportivo/features/admin/administracion/presentation/resenas_admin_screen.dart';
import 'package:saman_deportivo/features/admin/deportes/presentation/deportes_admin_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

class _ResenasFake implements ResenasAdminRepository {
  final deportes = deportesDePrueba().take(2).toList();
  final datos = <String, List<Resena>>{
    'FUT-01': [
      Resena(
        estudianteUid: 'u1',
        estudianteNombre: 'Ana Pérez',
        puntuacion: 5,
        comentario: 'Entrenamiento de fútbol excelente',
        fecha: DateTime(2026, 11, 1),
      ),
    ],
    'BAL-01': [
      Resena(
        estudianteUid: 'u1',
        estudianteNombre: 'Ana Pérez',
        puntuacion: 4,
        comentario: 'Clase de baloncesto muy buena',
        fecha: DateTime(2026, 11, 4),
      ),
    ],
  };
  final _cambios = <String, StreamController<List<Resena>>>{};
  final _cambiosDeportes = StreamController<List<Deporte>>.broadcast();

  @override
  Stream<List<Deporte>> observarDeportes() async* {
    yield List.of(deportes);
    yield* _cambiosDeportes.stream;
  }

  @override
  Stream<List<Resena>> observarResenas(String codigo) async* {
    yield List.of(datos[codigo] ?? const <Resena>[]);
    yield* _cambios
        .putIfAbsent(codigo, () => StreamController<List<Resena>>.broadcast())
        .stream;
  }

  @override
  Future<void> cambiarVisibilidad(
    String codigo,
    String uid, {
    required bool oculta,
  }) async {
    final resenas = datos[codigo]!;
    final i = resenas.indexWhere((r) => r.estudianteUid == uid);
    if (i < 0) throw StateError('No encontrado');
    final anterior = resenas[i];
    resenas[i] = Resena(
      estudianteUid: anterior.estudianteUid,
      estudianteNombre: anterior.estudianteNombre,
      puntuacion: anterior.puntuacion,
      comentario: anterior.comentario,
      fecha: anterior.fecha,
      oculta: oculta,
    );
    _cambios[codigo]?.add(List.of(resenas));
  }

  Future<void> cerrar() async {
    await _cambiosDeportes.close();
    await Future.wait(_cambios.values.map((s) => s.close()));
  }
}

class _DeportesFake implements DeporteRepository {
  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) async* {
    yield deportesDePrueba().take(1).toList();
  }

  @override
  Stream<Deporte?> observar(String codigo) async* {
    yield deportesDePrueba().first;
  }

  @override
  Stream<List<Deporte>> observarPorEntrenador(String entrenadorUid) async* {
    yield const [];
  }

  @override
  Future<void> crear(Deporte deporte) async {}

  @override
  Future<void> actualizar(Deporte deporte) async {}

  @override
  Future<void> desactivar(String codigo) async {}
}

Future<void> _mostrar(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra todas las reseñas y el deporte de cada una', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    expect(find.text('Todos los deportes'), findsOneWidget);
    expect(find.text('Entrenamiento de fútbol excelente'), findsOneWidget);
    expect(find.text('Clase de baloncesto muy buena'), findsOneWidget);
    expect(find.byKey(const Key('deporte-resena-FUT-01/u1')), findsOneWidget);
    expect(find.byKey(const Key('deporte-resena-BAL-01/u1')), findsOneWidget);
    expect(find.text('2 reseña(s) encontradas'), findsOneWidget);
  });

  testWidgets('puede filtrar por deporte desde la vista global', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    await tester.tap(find.byKey(const Key('selector-deporte-resenas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fútbol sala').last);
    await tester.pumpAndSettle();
    expect(find.text('Entrenamiento de fútbol excelente'), findsOneWidget);
    expect(find.text('Clase de baloncesto muy buena'), findsNothing);
  });

  testWidgets('deporteInicial abre las reseñas del deporte indicado', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(
      tester,
      ResenasAdminScreen(repositorio: repo, deporteInicial: 'BAL-01'),
    );
    expect(find.text('Clase de baloncesto muy buena'), findsOneWidget);
    expect(find.text('Entrenamiento de fútbol excelente'), findsNothing);
  });

  testWidgets('busca por nombre del deporte sin tildes', (tester) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    await tester.enterText(
      find.byKey(const Key('buscar-resena-admin')),
      'futbol',
    );
    await tester.pumpAndSettle();
    expect(find.text('Entrenamiento de fútbol excelente'), findsOneWidget);
    expect(find.text('Clase de baloncesto muy buena'), findsNothing);
  });

  testWidgets('moderación global modifica solo la reseña del deporte elegido', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    await tester.tap(find.byKey(const Key('visibilidad-FUT-01-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-visibilidad-resena')));
    await tester.pumpAndSettle();
    expect(repo.datos['FUT-01']!.first.oculta, isTrue);
    expect(repo.datos['BAL-01']!.first.oculta, isFalse);
    expect(repo.datos['FUT-01']!.first.puntuacion, 5);
  });

  testWidgets('Deportes ofrece acceso directo a reseñas', (tester) async {
    await _mostrar(
      tester,
      Scaffold(body: DeportesAdminScreen(repositorio: _DeportesFake())),
    );
    final acceso = find.byKey(const Key('resenas-FUT-01'));
    expect(acceso, findsOneWidget);
    await tester.tap(acceso);
    await tester.pumpAndSettle();
    expect(find.text('Moderación de reseñas'), findsOneWidget);
  });
}

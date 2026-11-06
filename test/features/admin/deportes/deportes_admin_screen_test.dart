import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/deportes/presentation/deportes_admin_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

class _DeportesFake implements DeporteRepository {
  _DeportesFake()
    : deportes = [deportesDePrueba().first, deportesDePrueba()[1]];

  final List<Deporte> deportes;
  final _cambios = StreamController<List<Deporte>>.broadcast();

  void _emitir() => _cambios.add(List<Deporte>.of(deportes));

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
  Stream<List<Deporte>> observarPorEntrenador(String entrenadorUid) async* {
    yield deportes.where((d) => d.entrenadorUid == entrenadorUid).toList();
  }

  @override
  Future<void> crear(Deporte deporte) async {
    if (deportes.any((d) => d.codigo == deporte.codigo)) {
      throw StateError('Código repetido');
    }
    deportes.add(deporte);
    _emitir();
  }

  @override
  Future<void> actualizar(Deporte deporte) async {
    final indice = deportes.indexWhere((d) => d.codigo == deporte.codigo);
    if (indice < 0) throw StateError('No encontrado');
    deportes[indice] = deporte;
    _emitir();
  }

  @override
  Future<void> desactivar(String codigo) async {
    final indice = deportes.indexWhere((d) => d.codigo == codigo);
    if (indice < 0) throw StateError('No encontrado');
    deportes[indice] = deportes[indice].copyWith(activo: false);
    _emitir();
  }

  Future<void> cerrar() => _cambios.close();
}

Future<void> _mostrar(WidgetTester tester, _DeportesFake repo) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(repo.cerrar);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DeportesAdminScreen(repositorio: repo)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra deportes del repositorio y permite filtrar', (
    tester,
  ) async {
    final repo = _DeportesFake();
    await _mostrar(tester, repo);
    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('Baloncesto'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('buscar-deporte')), 'FUT-01');
    await tester.pumpAndSettle();
    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('Baloncesto'), findsNothing);
  });

  testWidgets('formulario valida antes de crear deporte', (tester) async {
    final repo = _DeportesFake();
    await _mostrar(tester, repo);
    await tester.tap(find.byKey(const Key('nuevo-deporte')));
    await tester.pumpAndSettle();
    expect(find.text('Crear deporte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guardar-deporte')));
    await tester.pumpAndSettle();
    expect(find.textContaining('tres letras'), findsOneWidget);
    expect(repo.deportes.length, 2);
  });

  testWidgets('edición actualiza nombre y mantiene el mismo código', (
    tester,
  ) async {
    final repo = _DeportesFake();
    await _mostrar(tester, repo);
    await tester.tap(find.byKey(const Key('editar-FUT-01')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre')),
      'Fútbol sala mixto',
    );
    await tester.tap(find.byKey(const Key('guardar-deporte')));
    await tester.pumpAndSettle();
    final resultado = repo.deportes.firstWhere((d) => d.codigo == 'FUT-01');
    expect(resultado.nombre, 'Fútbol sala mixto');
    expect(resultado.codigo, 'FUT-01');
    expect(resultado.cuposOcupados, 0);
  });

  testWidgets('desactivar solicita confirmación antes de cambiar estado', (
    tester,
  ) async {
    final repo = _DeportesFake();
    await _mostrar(tester, repo);
    await tester.tap(find.byKey(const Key('estado-FUT-01')));
    await tester.pumpAndSettle();
    expect(find.text('Desactivar deporte'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.deportes.first.activo, isTrue);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/features/admin/espacios/presentation/espacios_admin_screen.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';

class _EspaciosFake implements EspacioRepository {
  final _cambios = StreamController<List<EspacioDeportivo>>.broadcast();
  final espacios = <EspacioDeportivo>[];

  @override
  Stream<List<EspacioDeportivo>> observarTodos() async* {
    yield List.of(espacios);
    yield* _cambios.stream;
  }

  void _emitir() => _cambios.add(List.of(espacios));

  @override
  Future<String> crear({
    required String nombre,
    required String tipo,
    String descripcion = '',
  }) async {
    final id = 'esp-${espacios.length + 1}';
    espacios.add(EspacioDeportivo(
      id: id,
      nombre: nombre,
      tipo: tipo,
      descripcion: descripcion,
      creadoEn: DateTime(2026, 11, 15),
    ));
    _emitir();
    return id;
  }

  @override
  Future<void> actualizar(EspacioDeportivo espacio) async {
    espacios[espacios.indexWhere((e) => e.id == espacio.id)] = espacio;
    _emitir();
  }

  @override
  Future<void> cambiarEstado(String espacioId, {required bool activo}) async {
    final indice = espacios.indexWhere((e) => e.id == espacioId);
    espacios[indice] = espacios[indice].copyWith(activo: activo);
    _emitir();
  }

  Future<void> dispose() => _cambios.close();
}

void main() {
  testWidgets('H4: registra una instalación desde la administración',
      (tester) async {
    final repo = _EspaciosFake();
    addTearDown(repo.dispose);
    await tester.pumpWidget(MaterialApp(
      home: EspaciosAdminScreen(repositorio: repo),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('nuevo-espacio')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nombre-espacio')),
        'Cancha de tenis 1');
    await tester.enterText(find.widgetWithText(TextFormField,
        'Tipo de instalación'), 'Tenis');
    await tester.tap(find.byKey(const Key('guardar-espacio')));
    await tester.pumpAndSettle();

    expect(repo.espacios, hasLength(1));
    expect(repo.espacios.single.nombre, 'Cancha de tenis 1');
    expect(find.text('Cancha de tenis 1'), findsOneWidget);
  });

  testWidgets('H4: puede desactivar sin borrar la instalación',
      (tester) async {
    final repo = _EspaciosFake();
    addTearDown(repo.dispose);
    await repo.crear(nombre: 'Gimnasio 1', tipo: 'Gimnasio');
    await tester.pumpWidget(MaterialApp(
      home: EspaciosAdminScreen(repositorio: repo),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('estado-espacio-esp-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar').last);
    await tester.pumpAndSettle();

    expect(repo.espacios.single.activo, isFalse);
    expect(repo.espacios.single.nombre, 'Gimnasio 1');
    expect(find.text('Inactivo'), findsOneWidget);
  });
}

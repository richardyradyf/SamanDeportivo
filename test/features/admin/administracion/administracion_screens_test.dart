import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/administracion/data/estudiantes_admin_repository.dart';
import 'package:saman_deportivo/features/admin/administracion/data/resenas_admin_repository.dart';
import 'package:saman_deportivo/features/admin/administracion/presentation/estudiantes_admin_screen.dart';
import 'package:saman_deportivo/features/admin/administracion/presentation/resenas_admin_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/resena.dart';

class _EstudiantesFake implements EstudiantesAdminRepository {
  final estudiantes = <Estudiante>[
    const Estudiante(
      uid: 'u1',
      cedula: '21000001',
      carnet: '20230001',
      correo: 'ana@unimet.edu.ve',
      nombre: 'Ana Pérez',
    ),
    const Estudiante(
      uid: 'u2',
      cedula: '21000002',
      carnet: '20230002',
      correo: 'luis@unimet.edu.ve',
      nombre: 'Luis Gómez',
      estado: EstadoEstudiante.inactivo,
    ),
  ];

  final _eventos = StreamController<List<Estudiante>>.broadcast();

  @override
  Stream<List<Estudiante>> observarEstudiantes() async* {
    yield List.of(estudiantes);
    yield* _eventos.stream;
  }

  @override
  Future<void> cambiarEstado(String uid, EstadoEstudiante nuevo) async {
    final indice = estudiantes.indexWhere((e) => e.uid == uid);
    if (indice < 0) throw StateError('No existe');
    estudiantes[indice] = estudiantes[indice].copyWith(estado: nuevo);
    _eventos.add(List.of(estudiantes));
  }

  Future<void> cerrar() => _eventos.close();
}

class _ResenasFake implements ResenasAdminRepository {
  final deportes = deportesDePrueba().take(2).toList();
  final resenas = <String, List<Resena>>{
    'FUT-01': [
      Resena(
        estudianteUid: 'u1',
        estudianteNombre: 'Ana Pérez',
        puntuacion: 5,
        comentario: 'Excelente entrenamiento',
        fecha: DateTime(2026, 11, 1),
      ),
    ],
    'BAL-01': [],
  };
  final _eventos = StreamController<List<Resena>>.broadcast();

  @override
  Stream<List<Deporte>> observarDeportes() async* {
    yield List.of(deportes);
  }

  @override
  Stream<List<Resena>> observarResenas(String codigo) async* {
    yield List.of(resenas[codigo] ?? []);
    yield* _eventos.stream;
  }

  @override
  Future<void> cambiarVisibilidad(
    String codigo,
    String uid, {
    required bool oculta,
  }) async {
    final items = resenas[codigo]!;
    final indice = items.indexWhere((r) => r.estudianteUid == uid);
    if (indice < 0) throw StateError('No existe');
    final anterior = items[indice];
    items[indice] = Resena(
      estudianteUid: anterior.estudianteUid,
      estudianteNombre: anterior.estudianteNombre,
      puntuacion: anterior.puntuacion,
      comentario: anterior.comentario,
      fecha: anterior.fecha,
      oculta: oculta,
    );
    _eventos.add(List.of(items));
  }

  Future<void> cerrar() => _eventos.close();
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('estudiantes: muestra usuarios y permite búsqueda sin tildes', (
    tester,
  ) async {
    final repo = _EstudiantesFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, EstudiantesAdminScreen(repositorio: repo));

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Gómez'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('buscar-estudiante-admin')),
      'perez',
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Gómez'), findsNothing);
  });

  testWidgets('estudiantes: solicita confirmación antes de desactivar', (
    tester,
  ) async {
    final repo = _EstudiantesFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, EstudiantesAdminScreen(repositorio: repo));

    await tester.tap(find.byKey(const Key('estado-estudiante-u1')));
    await tester.pumpAndSettle();
    expect(find.text('Desactivar estudiante'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.estudiantes.first.estaActivo, isTrue);

    await tester.tap(find.byKey(const Key('estado-estudiante-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-estado-estudiante')));
    await tester.pumpAndSettle();
    expect(repo.estudiantes.first.estaActivo, isFalse);
  });

  testWidgets('estudiantes: filtra solo inactivos', (tester) async {
    final repo = _EstudiantesFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, EstudiantesAdminScreen(repositorio: repo));

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Luis Gómez'), findsOneWidget);
  });

  testWidgets('reseñas: muestra contenido del deporte seleccionado', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));

    // El primer deporte alfabético es Baloncesto; seleccionar Fútbol sala.
    await tester.tap(find.byKey(const Key('selector-deporte-resenas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fútbol sala').last);
    await tester.pumpAndSettle();
    expect(find.text('Excelente entrenamiento'), findsOneWidget);
  });

  testWidgets('reseñas: oculta y conserva comentario y puntuación', (
    tester,
  ) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    await tester.tap(find.byKey(const Key('selector-deporte-resenas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fútbol sala').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('visibilidad-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-visibilidad-resena')));
    await tester.pumpAndSettle();
    final resena = repo.resenas['FUT-01']!.first;
    expect(resena.oculta, isTrue);
    expect(resena.comentario, 'Excelente entrenamiento');
    expect(resena.puntuacion, 5);
  });

  testWidgets('reseñas: filtra nombre sin acento', (tester) async {
    final repo = _ResenasFake();
    addTearDown(repo.cerrar);
    await _mostrar(tester, ResenasAdminScreen(repositorio: repo));
    await tester.tap(find.byKey(const Key('selector-deporte-resenas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fútbol sala').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('buscar-resena-admin')),
      'perez',
    );
    await tester.pumpAndSettle();
    expect(find.text('Excelente entrenamiento'), findsOneWidget);
  });
}

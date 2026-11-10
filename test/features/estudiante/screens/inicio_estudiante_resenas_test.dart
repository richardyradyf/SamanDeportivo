import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/permiso_resena.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

class _DeportesFalsos implements DeporteRepository {
  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value([_futbol]);

  @override
  Stream<Deporte?> observar(String codigo) => Stream.value(_futbol);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No se usa ${invocation.memberName}');
}

class _ResenasFalsas implements ResenaRepository {
  @override
  Stream<List<Resena>> observar(
    String codigoDeporte, {
    bool incluirOcultas = false,
  }) => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No se usa ${invocation.memberName}');
}

final _futbol = Deporte(
  codigo: 'FUT-01',
  nombre: 'Fútbol sala',
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 11, 1),
);

Inscripcion _inscripcion(String codigo, EstadoInscripcion estado) {
  final fecha = DateTime(2026, 11, 5);
  return Inscripcion(
    id: 'est-1_$codigo',
    estudianteUid: 'est-1',
    estudianteCedula: '28000001',
    estudianteNombre: 'Ana Pérez',
    estudianteCarnet: '20231001',
    estudianteCorreo: 'ana@correo.unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: codigo == 'FUT-01' ? 'Fútbol sala' : 'Natación',
    estado: estado,
    fechaInscripcion: fecha,
    fechaLimitePago: fecha.add(const Duration(hours: 24)),
  );
}

Future<void> _abrirFutbol(
  WidgetTester tester,
  Stream<List<Inscripcion>> inscripciones,
) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: InicioEstudianteScreen(
        nombre: 'Ana Pérez',
        uid: 'est-1',
        onCerrarSesion: () {},
        reloj: () => DateTime(2026, 11, 8, 9),
        deportes: _DeportesFalsos(),
        resenas: _ResenasFalsas(),
        inscripcionesStream: inscripciones,
      ),
    ),
  );
  await tester.pump();

  final barra = find.byType(NavigationBar);
  await tester.tap(find.descendant(of: barra, matching: find.text('Explorar')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('FÚTBOL SALA'));
  await tester.pumpAndSettle();
}

final _soloInscritos = find.textContaining(
  'Solo los estudiantes con inscripción confirmada',
);

void main() {
  group('Quién puede calificar', () {
    test('solo con una inscripción confirmada en ese mismo deporte', () {
      final lista = [
        _inscripcion('FUT-01', EstadoInscripcion.pendiente),
        _inscripcion('NAT-01', EstadoInscripcion.confirmada),
      ];

      expect(tieneInscripcionConfirmada(lista, 'NAT-01'), isTrue);
      expect(tieneInscripcionConfirmada(lista, 'FUT-01'), isFalse);
      expect(tieneInscripcionConfirmada(lista, 'TEN-01'), isFalse);
      expect(tieneInscripcionConfirmada(null, 'NAT-01'), isFalse);
    });

    test('cancelada o expirada no cuenta', () {
      for (final estado in [
        EstadoInscripcion.cancelada,
        EstadoInscripcion.expirada,
        EstadoInscripcion.rechazada,
      ]) {
        expect(
          tieneInscripcionConfirmada([_inscripcion('FUT-01', estado)], 'FUT-01'),
          isFalse,
          reason: estado.name,
        );
      }
    });
  });

  group('Formulario de reseña en el detalle', () {
    testWidgets('con la inscripción confirmada aparece el formulario', (
      tester,
    ) async {
      await _abrirFutbol(
        tester,
        Stream.value([_inscripcion('FUT-01', EstadoInscripcion.confirmada)]),
      );

      expect(find.text('Califica este deporte'), findsOneWidget);
      expect(find.text('Publicar reseña'), findsOneWidget);
      expect(_soloInscritos, findsNothing);
    });

    testWidgets('con la inscripción pendiente no aparece', (tester) async {
      await _abrirFutbol(
        tester,
        Stream.value([
          _inscripcion('FUT-01', EstadoInscripcion.pendiente),
          _inscripcion('NAT-01', EstadoInscripcion.confirmada),
        ]),
      );

      expect(find.text('Publicar reseña'), findsNothing);
      expect(_soloInscritos, findsOneWidget);
    });

    testWidgets('aparece solo si la inscripción se confirma con el detalle '
        'abierto', (tester) async {
      // Primero llega la inscripción pendiente; 5 segundos después, el pago
      // la confirma. El tiempo de la prueba lo maneja tester.pump.
      Stream<List<Inscripcion>> inscripciones() async* {
        yield [_inscripcion('FUT-01', EstadoInscripcion.pendiente)];
        await Future<void>.delayed(const Duration(seconds: 5));
        yield [_inscripcion('FUT-01', EstadoInscripcion.confirmada)];
      }

      await _abrirFutbol(tester, inscripciones());
      expect(find.text('Publicar reseña'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Publicar reseña'), findsOneWidget);
    });
  });

  testWidgets('"Inscripciones" sigue mostrando las inscripciones aunque el '
      'stream solo admita una suscripción', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Un StreamController normal falla si alguien lo escucha dos veces.
    final inscripciones = StreamController<List<Inscripcion>>();
    addTearDown(inscripciones.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: InicioEstudianteScreen(
          nombre: 'Ana Pérez',
          uid: 'est-1',
          onCerrarSesion: () {},
          reloj: () => DateTime(2026, 11, 8, 9),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas(),
          inscripcionesStream: inscripciones.stream,
        ),
      ),
    );
    inscripciones.add([_inscripcion('NAT-01', EstadoInscripcion.confirmada)]);
    await tester.pump();

    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Inscripciones')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Código: NAT-01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

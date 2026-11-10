import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/entrenador/asistencia/presentation/tomar_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/nomina/presentation/nomina_screen.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

Deporte _deporte() => Deporte.fromMap('BAL-01', {
      'codigo': 'BAL-01',
      'nombre': 'Baloncesto',
      'descripcion': 'Fundamentos',
      'disciplina': 'colectivo',
      'costo': 10,
      'imagenUrl': null,
      'cupoMaximo': 15,
      'cuposOcupados': 1,
      'cuposConfirmados': 1,
      'entrenadorUid': 'ent-1',
      'entrenadorNombre': 'Carlos Rojas',
      'entrenadorEspecialidad': 'Baloncesto',
      'horarios': <Object>[],
      'dias': <Object>[],
      'activo': true,
      'promedioCalificacion': 0,
      'totalResenas': 0,
      'creadoEn': Timestamp.fromDate(DateTime(2026, 11, 1)),
      'actualizadoEn': null,
    });

Inscripcion _ana() => Inscripcion(
      id: 'est-1_BAL-01',
      estudianteUid: 'est-1',
      estudianteCedula: '28000001',
      estudianteNombre: 'Ana Pérez',
      estudianteCarnet: '20231001',
      estudianteCorreo: 'estudiante1@correo.unimet.edu.ve',
      deporteId: 'BAL-01',
      deporteNombre: 'Baloncesto',
      entrenadorUid: 'ent-1',
      estado: EstadoInscripcion.confirmada,
      fechaInscripcion: DateTime(2026, 11, 8, 10),
      fechaLimitePago: DateTime(2026, 11, 9, 10),
    );

/// Repositorio en memoria: guarda lo que recibe y devuelve lo guardado.
class _AsistenciasFalsas implements AsistenciaRepository {
  final guardadas = <Asistencia>[];

  @override
  Future<void> guardarSesion(List<Asistencia> registros) async {
    guardadas
      ..removeWhere((a) => registros.any((r) => r.id == a.id))
      ..addAll(registros);
  }

  @override
  Stream<List<Asistencia>> observarDeDeporte(
    String codigoDeporte, {
    required DateTime desde,
    required DateTime hasta,
  }) =>
      Stream.value([
        for (final a in guardadas)
          if (a.deporteId == codigoDeporte &&
              !a.fecha.isBefore(desde) &&
              a.fecha.isBefore(hasta))
            a,
      ]);

  @override
  Stream<List<Asistencia>> observarDeEstudiante(
    String estudianteUid, {
    required DateTime desde,
    required DateTime hasta,
  }) =>
      Stream.value([
        for (final a in guardadas)
          if (a.estudianteUid == estudianteUid) a,
      ]);
}

void main() {
  testWidgets('la nómina muestra los inscritos confirmados con sus datos',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NominaScreen(
          deportes: Stream.value([_deporte()]),
          confirmadas: (_) => Stream.value([_ana()]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Baloncesto (BAL-01)'), findsOneWidget);
    expect(find.text('1 inscritos confirmados'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('Cédula 28000001'), findsOneWidget);
    expect(find.textContaining('Carnet 20231001'), findsOneWidget);
  });

  testWidgets('la nómina avisa cuando no hay confirmados', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NominaScreen(
          deportes: Stream.value([_deporte()]),
          confirmadas: (_) => Stream.value(const <Inscripcion>[]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay inscritos confirmados.'), findsOneWidget);
  });

  testWidgets('tomar asistencia guarda presentes y ausentes', (tester) async {
    final asistencias = _AsistenciasFalsas();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TomarAsistenciaScreen(
          deportes: Stream.value([_deporte()]),
          confirmadas: (_) => Stream.value([_ana()]),
          asistencias: asistencias,
          entrenadorUid: 'ent-1',
          hoy: () => DateTime(2026, 11, 8, 18),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('08/11/2026'), findsOneWidget);
    expect(find.text('Ausente'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Presente'), findsOneWidget);

    await tester.tap(find.text('Guardar asistencia'));
    await tester.pumpAndSettle();

    expect(asistencias.guardadas, hasLength(1));
    expect(asistencias.guardadas.single.estudianteUid, 'est-1');
    expect(asistencias.guardadas.single.estuvoPresente, isTrue);
    expect(asistencias.guardadas.single.entrenadorUid, 'ent-1');
    expect(find.text('Asistencia guardada.'), findsOneWidget);
  });

  testWidgets('al reabrir el mismo día carga lo ya guardado', (tester) async {
    final asistencias = _AsistenciasFalsas();
    await asistencias.guardarSesion([
      Asistencia.registrar(
        inscripcionId: 'est-1_BAL-01',
        estudianteUid: 'est-1',
        estudianteNombre: 'Ana Pérez',
        deporteId: 'BAL-01',
        entrenadorUid: 'ent-1',
        fecha: DateTime(2026, 11, 8),
        estado: EstadoAsistencia.presente,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TomarAsistenciaScreen(
          deportes: Stream.value([_deporte()]),
          confirmadas: (_) => Stream.value([_ana()]),
          asistencias: asistencias,
          entrenadorUid: 'ent-1',
          hoy: () => DateTime(2026, 11, 8, 18),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Presente'), findsOneWidget);
  });
}
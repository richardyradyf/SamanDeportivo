import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/domain/resumen_asistencia.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/historial_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/tomar_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/nomina/presentation/nomina_screen.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

/// Guarda en memoria lo que la pantalla manda a guardar.
class _AsistenciasFalsas implements AsistenciaRepository {
  _AsistenciasFalsas({this.previas = const [], this.falla = false});

  final List<Asistencia> previas;
  final bool falla;
  final guardadas = <Asistencia>[];
  final rangos = <({DateTime desde, DateTime hasta})>[];

  @override
  Future<void> guardarSesion(List<Asistencia> registros) async {
    if (falla) throw Exception('sin permiso');
    guardadas.addAll(registros);
  }

  @override
  Stream<List<Asistencia>> observarDeDeporte(
    String codigoDeporte, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    rangos.add((desde: desde, hasta: hasta));
    return Stream.value([
      for (final a in previas)
        if (a.deporteId == codigoDeporte) a,
    ]);
  }

  @override
  Stream<List<Asistencia>> observarDeEstudiante(
    String estudianteUid, {
    required DateTime desde,
    required DateTime hasta,
  }) => Stream.value(const []);
}

Deporte _deporte(String codigo, String nombre) => Deporte(
  codigo: codigo,
  nombre: nombre,
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 11, 1),
  entrenadorUid: 'ent-1',
);

final _futbol = _deporte('FUT-01', 'Fútbol sala');
final _natacion = _deporte('NAT-01', 'Natación');

Inscripcion _confirmada(String uid, String nombre, {String codigo = 'FUT-01'}) {
  final fecha = DateTime(2026, 11, 2);
  return Inscripcion(
    id: '${uid}_$codigo',
    estudianteUid: uid,
    estudianteCedula: '28000001',
    estudianteNombre: nombre,
    estudianteCarnet: '20231001',
    estudianteCorreo: '$uid@correo.unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: codigo,
    entrenadorUid: 'ent-1',
    estado: EstadoInscripcion.confirmada,
    fechaInscripcion: fecha,
    fechaLimitePago: fecha.add(const Duration(hours: 24)),
  );
}

/// Ana y Luis en fútbol; Carla en natación.
Stream<List<Inscripcion>> _confirmadas(String codigo) => Stream.value([
  if (codigo == 'FUT-01') ...[
    _confirmada('est-2', 'Luis Gómez'),
    _confirmada('est-1', 'Ana Pérez'),
  ],
  if (codigo == 'NAT-01') _confirmada('est-3', 'Carla Ruiz', codigo: 'NAT-01'),
]);

Asistencia _registro(String uid, String nombre, DateTime dia, EstadoAsistencia estado) =>
    Asistencia.registrar(
      inscripcionId: '${uid}_FUT-01',
      estudianteUid: uid,
      estudianteNombre: nombre,
      deporteId: 'FUT-01',
      entrenadorUid: 'ent-1',
      fecha: dia,
      estado: estado,
    );

final _hoy = DateTime(2026, 11, 5, 16, 30); // jueves

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.claro, home: Scaffold(body: pantalla)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Cálculos del historial', () {
    test('la semana va de lunes a lunes', () {
      final r = PeriodoHistorial.semana.rango(_hoy);

      expect(r.desde, DateTime(2026, 11, 2));
      expect(r.hasta, DateTime(2026, 11, 9));
    });

    test('el día y el mes no incluyen el límite final', () {
      expect(PeriodoHistorial.dia.rango(_hoy).desde, DateTime(2026, 11, 5));
      expect(PeriodoHistorial.dia.rango(_hoy).hasta, DateTime(2026, 11, 6));
      expect(PeriodoHistorial.mes.rango(_hoy).desde, DateTime(2026, 11));
      expect(PeriodoHistorial.mes.rango(_hoy).hasta, DateTime(2026, 12));
    });

    test('el porcentaje cuenta solo los presentes y redondea', () {
      final dia = DateTime(2026, 11, 5);
      final registros = [
        _registro('est-1', 'Ana', dia, EstadoAsistencia.presente),
        _registro('est-2', 'Luis', dia, EstadoAsistencia.presente),
        _registro('est-3', 'Carla', dia, EstadoAsistencia.ausente),
      ];

      expect(porcentajeAsistencia(registros), 67);
      expect(porcentajeAsistencia(const []), 0);
    });

    test('la lista se guarda en lotes de 8 sin perder a nadie', () {
      final lotes = dividirEnLotes(List.generate(20, (i) => i), 8);

      expect(lotes.map((l) => l.length), [8, 8, 4]);
      expect(lotes.expand((l) => l), List.generate(20, (i) => i));
      expect(dividirEnLotes(const <int>[], 8), isEmpty);
    });
  });

  group('Nómina', () {
    testWidgets('muestra los inscritos confirmados en orden alfabético', (
      tester,
    ) async {
      await _mostrar(
        tester,
        NominaScreen(
          deportes: Stream.value([_futbol, _natacion]),
          confirmadas: _confirmadas,
        ),
      );

      expect(find.text('2 inscritos confirmados'), findsOneWidget);
      final ana = tester.getTopLeft(find.text('Ana Pérez'));
      final luis = tester.getTopLeft(find.text('Luis Gómez'));
      expect(ana.dy, lessThan(luis.dy));
    });

    testWidgets('al elegir otro deporte cambia la lista', (tester) async {
      await _mostrar(
        tester,
        NominaScreen(
          deportes: Stream.value([_futbol, _natacion]),
          confirmadas: _confirmadas,
        ),
      );

      await tester.tap(find.text('Fútbol sala (FUT-01)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Natación (NAT-01)').last);
      await tester.pumpAndSettle();

      expect(find.text('Carla Ruiz'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsNothing);
    });

    testWidgets('sin deportes asignados lo dice', (tester) async {
      await _mostrar(
        tester,
        NominaScreen(deportes: Stream.value(const []), confirmadas: _confirmadas),
      );

      expect(find.text('Todavía no tienes deportes asignados.'), findsOneWidget);
    });
  });

  group('Toma de asistencia', () {
    testWidgets('guarda presente a quien se marcó y ausente al resto', (
      tester,
    ) async {
      final repo = _AsistenciasFalsas();
      await _mostrar(
        tester,
        TomarAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          confirmadas: _confirmadas,
          asistencias: repo,
          entrenadorUid: 'ent-1',
          hoy: () => _hoy,
        ),
      );

      expect(find.text('05/11/2026'), findsOneWidget);
      await tester.tap(find.text('Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar asistencia'));
      await tester.pumpAndSettle();

      expect(find.text('Asistencia guardada.'), findsOneWidget);
      final porUid = {for (final a in repo.guardadas) a.estudianteUid: a};
      expect(porUid.keys, unorderedEquals(['est-1', 'est-2']));
      expect(porUid['est-1']!.estado, EstadoAsistencia.presente);
      expect(porUid['est-2']!.estado, EstadoAsistencia.ausente);
      expect(porUid['est-1']!.id, 'FUT-01_2026-11-05_est-1');
      expect(porUid['est-1']!.inscripcionId, 'est-1_FUT-01');
      expect(porUid['est-1']!.entrenadorUid, 'ent-1');
      expect(porUid['est-1']!.fecha, DateTime(2026, 11, 5));
    });

    testWidgets('si ya se tomó ese día, carga lo guardado para corregirlo', (
      tester,
    ) async {
      final dia = DateTime(2026, 11, 5);
      await _mostrar(
        tester,
        TomarAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          confirmadas: _confirmadas,
          asistencias: _AsistenciasFalsas(
            previas: [_registro('est-2', 'Luis Gómez', dia, EstadoAsistencia.presente)],
          ),
          entrenadorUid: 'ent-1',
          hoy: () => _hoy,
        ),
      );

      final luis = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Luis Gómez'),
      );
      final ana = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Ana Pérez'),
      );
      expect(luis.value, isTrue);
      expect(ana.value, isFalse);
    });

    testWidgets('"Marcar todos presentes" marca a toda la lista', (
      tester,
    ) async {
      final repo = _AsistenciasFalsas();
      await _mostrar(
        tester,
        TomarAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          confirmadas: _confirmadas,
          asistencias: repo,
          entrenadorUid: 'ent-1',
          hoy: () => _hoy,
        ),
      );

      await tester.tap(find.text('Marcar todos presentes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar asistencia'));
      await tester.pumpAndSettle();

      expect(repo.guardadas, hasLength(2));
      expect(
        repo.guardadas.every((a) => a.estado == EstadoAsistencia.presente),
        isTrue,
      );
    });

    testWidgets('si no se puede guardar, avisa', (tester) async {
      await _mostrar(
        tester,
        TomarAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          confirmadas: _confirmadas,
          asistencias: _AsistenciasFalsas(falla: true),
          entrenadorUid: 'ent-1',
          hoy: () => _hoy,
        ),
      );

      await tester.tap(find.text('Guardar asistencia'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo guardar la asistencia. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });
  });

  group('Historial', () {
    final martes = DateTime(2026, 11, 3);
    final jueves = DateTime(2026, 11, 5);
    final registros = [
      _registro('est-1', 'Ana Pérez', martes, EstadoAsistencia.presente),
      _registro('est-1', 'Ana Pérez', jueves, EstadoAsistencia.ausente),
      _registro('est-2', 'Luis Gómez', jueves, EstadoAsistencia.presente),
    ];

    testWidgets('por defecto muestra la semana con su porcentaje', (
      tester,
    ) async {
      final repo = _AsistenciasFalsas(previas: registros);
      await _mostrar(
        tester,
        HistorialAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          asistencias: repo,
          hoy: () => _hoy,
        ),
      );

      expect(repo.rangos.last.desde, DateTime(2026, 11, 2));
      expect(repo.rangos.last.hasta, DateTime(2026, 11, 9));
      expect(find.text('Asistencia: 67% (2 de 3 registros)'), findsOneWidget);
    });

    testWidgets('filtrado por estudiante, calcula solo su porcentaje', (
      tester,
    ) async {
      await _mostrar(
        tester,
        HistorialAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          asistencias: _AsistenciasFalsas(previas: registros),
          hoy: () => _hoy,
        ),
      );

      await tester.tap(find.text('Todos los estudiantes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Pérez').last);
      await tester.pumpAndSettle();

      expect(find.text('Asistencia: 50% (1 de 2 registros)'), findsOneWidget);
    });

    testWidgets('al cambiar a "Mes" consulta el mes completo', (tester) async {
      final repo = _AsistenciasFalsas(previas: registros);
      await _mostrar(
        tester,
        HistorialAsistenciaScreen(
          deportes: Stream.value([_futbol]),
          asistencias: repo,
          hoy: () => _hoy,
        ),
      );

      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();

      expect(repo.rangos.last.desde, DateTime(2026, 11));
      expect(repo.rangos.last.hasta, DateTime(2026, 12));
    });
  });
}

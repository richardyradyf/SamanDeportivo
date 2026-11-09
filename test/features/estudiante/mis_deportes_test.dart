import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/mis_deportes_screen.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/proxima_sesion.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

// Jueves 5 de noviembre de 2026, 4:30 p. m.
final _ahora = DateTime(2026, 11, 5, 16, 30);

const _sesion = HorarioSesion(
  dia: DiaSemana.jueves,
  horaInicio: '18:00',
  horaFin: '20:00',
  lugar: 'Cancha principal',
);

Deporte _deporte(
  String codigo,
  String nombre, {
  List<HorarioSesion> horarios = const [],
}) => Deporte(
  codigo: codigo,
  nombre: nombre,
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 11, 1),
  entrenadorUid: 'ent-1',
  entrenadorNombre: 'María Pérez',
  horarios: horarios,
);

final _futbol = _deporte(
  'FUT-01',
  'Fútbol sala',
  horarios: const [
    HorarioSesion(
      dia: DiaSemana.martes,
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha principal',
    ),
    _sesion,
  ],
);
final _natacion = _deporte(
  'NAT-01',
  'Natación',
  horarios: const [
    HorarioSesion(
      dia: DiaSemana.viernes,
      horaInicio: '07:00',
      horaFin: '08:00',
      lugar: 'Piscina',
    ),
  ],
);

class _DeportesFalsos implements DeporteRepository {
  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value([_futbol, _natacion]);

  @override
  Stream<Deporte?> observar(String codigo) =>
      Stream.value(codigo == 'FUT-01' ? _futbol : _natacion);

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

class _AsistenciasFalsas implements AsistenciaRepository {
  _AsistenciasFalsas(this.registros);

  final List<Asistencia> registros;
  String? uidConsultado;

  @override
  Stream<List<Asistencia>> observarDeEstudiante(
    String estudianteUid, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    uidConsultado = estudianteUid;
    return Stream.value(registros);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No se usa ${invocation.memberName}');
}

Asistencia _registro(String codigo, DateTime dia, EstadoAsistencia estado) =>
    Asistencia.registrar(
      inscripcionId: 'est-1_$codigo',
      estudianteUid: 'est-1',
      estudianteNombre: 'Ana Pérez',
      deporteId: codigo,
      entrenadorUid: 'ent-1',
      fecha: dia,
      estado: estado,
    );

Inscripcion _inscripcion(String codigo, String nombre, EstadoInscripcion estado) {
  final fecha = DateTime(2026, 11, 1);
  return Inscripcion(
    id: 'est-1_$codigo',
    estudianteUid: 'est-1',
    estudianteCedula: '28000001',
    estudianteNombre: 'Ana Pérez',
    estudianteCarnet: '20231001',
    estudianteCorreo: 'ana@correo.unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: nombre,
    estado: estado,
    fechaInscripcion: fecha,
    fechaLimitePago: fecha.add(const Duration(hours: 24)),
  );
}

final _confirmadaFutbol = _inscripcion(
  'FUT-01',
  'Fútbol sala',
  EstadoInscripcion.confirmada,
);
final _pendienteNatacion = _inscripcion(
  'NAT-01',
  'Natación',
  EstadoInscripcion.pendiente,
);

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.claro, home: Scaffold(body: pantalla)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Próxima sesión', () {
    test('hoy, si la sesión de hoy todavía no termina', () {
      final proxima = proximaSesion([_futbol, _natacion], _ahora)!;

      expect(proxima.deporte.codigo, 'FUT-01');
      expect(proxima.inicio, DateTime(2026, 11, 5, 18));
      expect(cuandoEs(proxima.inicio, _ahora), 'Hoy · 18:00');
    });

    test('si la de hoy ya terminó, pasa a la siguiente', () {
      final tarde = DateTime(2026, 11, 5, 20, 30);
      final proxima = proximaSesion([_futbol, _natacion], tarde)!;

      expect(proxima.deporte.codigo, 'NAT-01');
      expect(cuandoEs(proxima.inicio, tarde), 'Mañana · 07:00');
    });

    test('una sesión en curso todavía cuenta', () {
      final enCurso = DateTime(2026, 11, 5, 19);

      expect(
        proximaSesion([_futbol], enCurso)!.inicio,
        DateTime(2026, 11, 5, 18),
      );
    });

    test('pasado mañana o más, dice el día de la semana', () {
      final sabado = DateTime(2026, 11, 7, 10);
      final proxima = proximaSesion([_futbol], sabado)!;

      expect(proxima.inicio, DateTime(2026, 11, 10, 16));
      expect(cuandoEs(proxima.inicio, sabado), 'Martes · 16:00');
    });

    test('sin horarios no hay próxima sesión', () {
      expect(proximaSesion([_deporte('TEN-01', 'Tenis')], _ahora), isNull);
    });
  });

  test('la asistencia se agrupa por deporte', () {
    final resumen = ResumenAsistenciaDeporte.porDeporte([
      _registro('FUT-01', DateTime(2026, 11, 3), EstadoAsistencia.presente),
      _registro('FUT-01', DateTime(2026, 11, 5), EstadoAsistencia.ausente),
      _registro('NAT-01', DateTime(2026, 11, 6), EstadoAsistencia.presente),
    ]);

    expect(resumen['FUT-01']!.porcentaje, 50);
    expect(resumen['FUT-01']!.total, 2);
    expect(resumen['NAT-01']!.porcentaje, 100);
  });

  group('Pantalla Mis deportes', () {
    testWidgets('muestra solo los deportes confirmados, con su asistencia', (
      tester,
    ) async {
      final asistencias = _AsistenciasFalsas([
        _registro('FUT-01', DateTime(2026, 11, 3), EstadoAsistencia.presente),
        _registro('FUT-01', DateTime(2026, 11, 5), EstadoAsistencia.ausente),
      ]);
      await _mostrar(
        tester,
        MisDeportesScreen(
          inscripciones: [_confirmadaFutbol, _pendienteNatacion],
          deportes: _DeportesFalsos(),
          asistencias: asistencias,
          estudianteUid: 'est-1',
          reloj: () => _ahora,
        ),
      );

      expect(asistencias.uidConsultado, 'est-1');
      expect(find.text('Tu próxima sesión'), findsOneWidget);
      expect(find.text('Hoy · 18:00'), findsOneWidget);
      expect(find.text('Cancha principal'), findsOneWidget);
      expect(find.text('Asistencia: 50% (1 de 2 sesiones)'), findsOneWidget);
      expect(find.text('Entrenador: María Pérez'), findsOneWidget);
      // Natación está pendiente: no tiene tarjeta, solo el aviso.
      expect(find.text('NATACIÓN'), findsNothing);
      expect(find.textContaining('1 inscripción pendiente de pago'), findsOneWidget);
    });

    testWidgets('sin asistencia registrada lo dice', (tester) async {
      await _mostrar(
        tester,
        MisDeportesScreen(
          inscripciones: [_confirmadaFutbol],
          deportes: _DeportesFalsos(),
          asistencias: _AsistenciasFalsas(const []),
          estudianteUid: 'est-1',
          reloj: () => _ahora,
        ),
      );

      expect(find.text('Todavía no hay sesiones registradas.'), findsOneWidget);
    });

    testWidgets('la tarjeta y "Ver detalles" abren el deporte', (tester) async {
      final abiertos = <String>[];
      await _mostrar(
        tester,
        MisDeportesScreen(
          inscripciones: [_confirmadaFutbol],
          deportes: _DeportesFalsos(),
          asistencias: _AsistenciasFalsas(const []),
          estudianteUid: 'est-1',
          reloj: () => _ahora,
          onVerDeporte: (deporte) => abiertos.add(deporte.codigo),
        ),
      );

      await tester.tap(find.text('Ver detalles'));
      final verDisciplina = find.text('Ver disciplina');
      await tester.ensureVisible(verDisciplina);
      await tester.tap(verDisciplina);

      expect(abiertos, ['FUT-01', 'FUT-01']);
    });

    testWidgets('sin deportes confirmados invita a explorar o a pagar', (
      tester,
    ) async {
      var explorar = 0;
      var inscripciones = 0;
      await _mostrar(
        tester,
        MisDeportesScreen(
          inscripciones: [_pendienteNatacion],
          deportes: _DeportesFalsos(),
          reloj: () => _ahora,
          onExplorar: () => explorar++,
          onVerInscripciones: () => inscripciones++,
        ),
      );

      expect(find.text('Todavía no tienes deportes confirmados.'), findsOneWidget);
      await tester.tap(find.text('Ver inscripciones'));
      await tester.tap(find.text('Explorar deportes'));

      expect(inscripciones, 1);
      expect(explorar, 1);
    });

    testWidgets('mientras cargan las inscripciones muestra un indicador', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: MisDeportesScreen(
              inscripciones: null,
              deportes: _DeportesFalsos(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Inicio del estudiante', () {
    Future<void> abrir(
      WidgetTester tester,
      List<Inscripcion> inscripciones,
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
            reloj: () => _ahora,
            deportes: _DeportesFalsos(),
            resenas: _ResenasFalsas(),
            asistencias: _AsistenciasFalsas([
              _registro('FUT-01', DateTime(2026, 11, 3), EstadoAsistencia.presente),
            ]),
            inscripcionesStream: Stream.value(inscripciones),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con un deporte confirmado muestra la próxima sesión', (
      tester,
    ) async {
      await abrir(tester, [_confirmadaFutbol]);

      expect(find.text('Hoy · 18:00'), findsOneWidget);
      expect(find.text('Mis disciplinas'), findsOneWidget);
      expect(
        find.text('Todavía no estás inscrito en ninguna disciplina.'),
        findsNothing,
      );
    });

    testWidgets('sin deportes confirmados sigue invitando a explorar', (
      tester,
    ) async {
      await abrir(tester, [_pendienteNatacion]);

      expect(
        find.text('Todavía no estás inscrito en ninguna disciplina.'),
        findsOneWidget,
      );
    });

    testWidgets('la pestaña Mis deportes muestra la asistencia y abre el '
        'detalle', (tester) async {
      await abrir(tester, [_confirmadaFutbol]);

      final barra = find.byType(NavigationBar);
      await tester.tap(
        find.descendant(of: barra, matching: find.text('Mis deportes')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asistencia: 100% (1 de 1 sesiones)'), findsOneWidget);

      final verDisciplina = find.text('Ver disciplina');
      await tester.ensureVisible(verDisciplina);
      await tester.tap(verDisciplina);
      await tester.pumpAndSettle();

      // El detalle del catálogo, con el formulario de reseña porque la
      // inscripción está confirmada.
      expect(find.text('Califica este deporte'), findsOneWidget);
    });
  });
}

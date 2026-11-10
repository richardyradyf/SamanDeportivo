import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

class _DeportesFalsos implements DeporteRepository {
  _DeportesFalsos({this.uno, this.catalogo});

  final Stream<Deporte?>? uno;
  final List<Deporte>? catalogo;

  @override
  Stream<Deporte?> observar(String codigo) => uno ?? const Stream.empty();

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value(catalogo ?? const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El detalle no usa ${invocation.memberName}');
}

class _ResenasFalsas implements ResenaRepository {
  _ResenasFalsas(this.lista, {this.fallar = false});

  final List<Resena> lista;
  final bool fallar;
  final guardadas = <Resena>[];

  @override
  Stream<List<Resena>> observar(
    String codigoDeporte, {
    bool incluirOcultas = false,
  }) => Stream.value(lista);

  @override
  Future<void> guardar(String codigoDeporte, Resena resena) async {
    if (fallar) throw Exception('sin permiso');
    guardadas.add(resena);
  }

  @override
  Future<void> cambiarVisibilidad(
    String codigoDeporte,
    String estudianteUid, {
    required bool oculta,
  }) async {}
}

Deporte _futbol({
  int cupoMaximo = 20,
  int cuposOcupados = 0,
  double promedio = 0,
  int totalResenas = 0,
}) {
  return Deporte(
    codigo: 'FUT-01',
    nombre: 'Fútbol sala',
    descripcion: 'Entrenamientos para todos los niveles.',
    disciplina: Disciplina.colectivo,
    costo: 10,
    cupoMaximo: cupoMaximo,
    cuposOcupados: cuposOcupados,
    entrenadorUid: 'uid-pedro',
    entrenadorNombre: 'Pedro Gómez',
    entrenadorEspecialidad: 'Fútbol',
    promedioCalificacion: promedio,
    totalResenas: totalResenas,
    horarios: const [
      HorarioSesion(
        dia: DiaSemana.miercoles,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'Cancha techada',
      ),
      HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'Cancha techada',
      ),
    ],
    creadoEn: DateTime(2026, 11, 1),
  );
}

Resena _resena(
  String uid,
  String nombre,
  int puntuacion,
  String comentario, {
  bool oculta = false,
}) => Resena(
  estudianteUid: uid,
  estudianteNombre: nombre,
  puntuacion: puntuacion,
  comentario: comentario,
  oculta: oculta,
  fecha: DateTime(2026, 11, 5),
);

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
  await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: pantalla));
  await tester.pump();
}

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
}

void main() {
  group('Datos del deporte', () {
    testWidgets('muestra descripción, entrenador, horarios, lugar y costo', (
      tester,
    ) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(deporte: _futbol(), deportes: _DeportesFalsos()),
      );

      expect(find.text('FUT-01 · COLECTIVO'), findsOneWidget);
      expect(find.text('Entrenamientos para todos los niveles.'), findsOneWidget);
      expect(find.text('Pedro Gómez'), findsOneWidget);
      expect(find.text('Lunes · 16:00 - 18:00 · Cancha techada'), findsOneWidget);
      expect(
        find.text('Miércoles · 16:00 - 18:00 · Cancha techada'),
        findsOneWidget,
      );
      expect(find.text('\$10.00'), findsOneWidget);
      expect(find.text('0 de 20 cupos ocupados'), findsOneWidget);
    });

    testWidgets('los cupos se actualizan en tiempo real', (tester) async {
      // La pantalla se abre con el deporte del catálogo (0 ocupados) y
      // luego Firestore entrega la versión nueva (5 ocupados).
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(
            uno: Stream.value(_futbol(cuposOcupados: 5)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('5 de 20 cupos ocupados'), findsOneWidget);
      // Se ve en el encabezado y en la tarjeta de inscripción.
      expect(find.text('15 cupos disponibles'), findsNWidgets(2));
    });

    testWidgets('sin cupos el botón de inscripción queda inactivo', (
      tester,
    ) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(cupoMaximo: 2, cuposOcupados: 2),
          deportes: _DeportesFalsos(),
          onInscribirse: (_) {},
        ),
      );

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sin cupos'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('"Inscribirme" avisa qué deporte se eligió', (tester) async {
      Deporte? elegido;
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          onInscribirse: (d) => elegido = d,
        ),
      );

      await _tocar(tester, find.text('Inscribirme'));

      expect(elegido?.codigo, 'FUT-01');
    });

    testWidgets('si el deporte se desactiva lo avisa', (tester) async {
      // Firestore deja de entregar el deporte (null).
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(uno: Stream.value(null)),
        ),
      );
      await tester.pump();

      expect(find.text('Este deporte ya no está disponible.'), findsOneWidget);
    });

    testWidgets('en computadora se ve a dos columnas sin desbordes', (
      tester,
    ) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas(const []),
        ),
        tamano: _escritorio,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Inscripción'), findsOneWidget);
      expect(find.text('Calificaciones y comentarios'), findsOneWidget);
    });
  });

  group('Calificación y comentarios', () {
    testWidgets('muestra el promedio y las reseñas visibles', (tester) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(promedio: 4.5, totalResenas: 2),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas([
            _resena('a', 'María López', 5, 'Muy buen entrenador.'),
            _resena('b', 'Luis Mora', 4, ''),
            _resena('c', 'Anónimo', 1, 'Comentario ofensivo', oculta: true),
          ]),
        ),
      );

      expect(find.text('4,5 · 2 reseñas'), findsOneWidget);
      expect(find.text('María López'), findsOneWidget);
      expect(find.text('Muy buen entrenador.'), findsOneWidget);
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(find.text('05/11/2026'), findsNWidgets(2));
      expect(find.text('Comentario ofensivo'), findsNothing);
    });

    testWidgets('sin reseñas lo dice', (tester) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas(const []),
        ),
      );

      expect(find.text('Sin calificaciones'), findsOneWidget);
      expect(
        find.text('Todavía nadie ha calificado este deporte.'),
        findsOneWidget,
      );
    });

    testWidgets('sin inscripción confirmada no deja calificar', (
      tester,
    ) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas(const []),
          estudianteUid: 'yo',
        ),
      );

      expect(
        find.textContaining('Solo los estudiantes con inscripción confirmada'),
        findsOneWidget,
      );
      expect(find.text('Publicar reseña'), findsNothing);
    });

    testWidgets('con inscripción confirmada publica la reseña', (
      tester,
    ) async {
      final resenas = _ResenasFalsas(const []);
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: resenas,
          estudianteUid: 'yo',
          estudianteNombre: 'Ana Pérez',
          puedeResenar: true,
        ),
      );

      await _tocar(tester, find.byTooltip('4 estrellas'));
      await tester.enterText(
        find.byKey(const Key('comentarioResena')),
        '  Me gustó mucho.  ',
      );
      await _tocar(tester, find.text('Publicar reseña'));
      await tester.pump();

      expect(resenas.guardadas, hasLength(1));
      final guardada = resenas.guardadas.single;
      expect(guardada.estudianteUid, 'yo');
      expect(guardada.estudianteNombre, 'Ana Pérez');
      expect(guardada.puntuacion, 4);
      expect(guardada.comentario, 'Me gustó mucho.');
      expect(find.text('Gracias por tu reseña.'), findsOneWidget);
    });

    testWidgets('pide elegir las estrellas antes de publicar', (tester) async {
      final resenas = _ResenasFalsas(const []);
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: resenas,
          estudianteUid: 'yo',
          puedeResenar: true,
        ),
      );

      await _tocar(tester, find.text('Publicar reseña'));

      expect(find.text('Elige de 1 a 5 estrellas.'), findsOneWidget);
      expect(resenas.guardadas, isEmpty);
    });

    testWidgets('si no se puede guardar muestra el error', (tester) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas(const [], fallar: true),
          estudianteUid: 'yo',
          puedeResenar: true,
        ),
      );

      await _tocar(tester, find.byTooltip('5 estrellas'));
      await _tocar(tester, find.text('Publicar reseña'));
      await tester.pump();

      expect(
        find.text('No se pudo guardar tu reseña. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('carga la reseña propia para editarla', (tester) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(
          deporte: _futbol(promedio: 3, totalResenas: 1),
          deportes: _DeportesFalsos(),
          resenas: _ResenasFalsas([
            _resena('yo', 'Ana Pérez', 3, 'Regular.'),
          ]),
          estudianteUid: 'yo',
          puedeResenar: true,
        ),
      );
      await tester.pump();

      expect(find.text('Tu reseña'), findsOneWidget);
      expect(find.text('Actualizar reseña'), findsOneWidget);
      expect(find.text('Ana Pérez (tú)'), findsOneWidget);
      final campo = tester.widget<TextField>(
        find.byKey(const Key('comentarioResena')),
      );
      expect(campo.controller!.text, 'Regular.');
    });

    testWidgets('sin repositorio de reseñas avisa que no están disponibles', (
      tester,
    ) async {
      await _mostrar(
        tester,
        DetalleDeporteScreen(deporte: _futbol(), deportes: _DeportesFalsos()),
      );

      expect(
        find.text('Las reseñas no están disponibles por ahora.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('tocar un deporte del catálogo abre su detalle', (tester) async {
    await _mostrar(
      tester,
      InicioEstudianteScreen(
        nombre: 'Ana Pérez',
        onCerrarSesion: () {},
        reloj: () => DateTime(2026, 11, 7, 9),
        deportes: _DeportesFalsos(catalogo: [_futbol()]),
      ),
    );

    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Explorar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('FÚTBOL SALA'));
    await tester.pumpAndSettle();

    final detalle = find.byType(DetalleDeporteScreen);
    expect(detalle, findsOneWidget);
    expect(
      find.descendant(of: detalle, matching: find.text('Pedro Gómez')),
      findsOneWidget,
    );
  });
}

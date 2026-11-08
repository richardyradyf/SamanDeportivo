import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/publico/landing/landing_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

class _DeportesFalsos implements DeporteRepository {
  _DeportesFalsos(this._catalogo);

  final Stream<List<Deporte>> _catalogo;

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      _catalogo;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El landing no usa ${invocation.memberName}');
}

Deporte _deporte(String codigo, String nombre, {bool lleno = false}) {
  return Deporte(
    codigo: codigo,
    nombre: nombre,
    descripcion: '',
    disciplina: Disciplina.colectivo,
    costo: 10,
    cupoMaximo: 10,
    cuposOcupados: lleno ? 10 : 0,
    creadoEn: DateTime(2026, 11, 1),
  );
}

final _catalogo = [
  _deporte('TEN-01', 'Tenis', lleno: true),
  _deporte('FUT-01', 'Fútbol sala'),
  _deporte('NAT-01', 'Natación'),
  _deporte('BAS-01', 'Baloncesto'),
];

const _celular = Size(390, 900);
const _computadora = Size(1400, 1000);

/// Lo que el visitante tocó en el landing.
class _Acciones {
  int iniciarSesion = 0;
  int crearCuenta = 0;
  final explorar = <String>[];
  final vistos = <String>[];
}

Future<_Acciones> _mostrar(
  WidgetTester tester, {
  Size tamano = _computadora,
  Stream<List<Deporte>>? catalogo,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final acciones = _Acciones();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: LandingScreen(
        deportes: _DeportesFalsos(catalogo ?? Stream.value(_catalogo)),
        onIniciarSesion: () => acciones.iniciarSesion++,
        onCrearCuenta: () => acciones.crearCuenta++,
        onExplorar: acciones.explorar.add,
        onVerDeporte: (d) => acciones.vistos.add(d.codigo),
      ),
    ),
  );
  await tester.pump();
  return acciones;
}

void main() {
  test('destaca primero los deportes con cupo, por nombre, hasta 3', () {
    final destacados = LandingScreen.destacados(_catalogo);

    expect(destacados.map((d) => d.codigo), ['BAS-01', 'FUT-01', 'NAT-01']);
  });

  group('En computadora', () {
    testWidgets('muestra el título, el buscador y el menú del Figma', (
      tester,
    ) async {
      await _mostrar(tester);

      expect(
        find.text('Encuentra tu próximo deporte en la UNIMET.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('buscadorLanding')), findsOneWidget);
      for (final texto in [
        'Deportes',
        'Cómo funciona',
        'Iniciar sesión',
        'Crear cuenta',
        'Explorar deportes',
      ]) {
        expect(find.text(texto), findsWidgets, reason: texto);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Explora disciplinas" muestra 3 deportes reales', (
      tester,
    ) async {
      final acciones = await _mostrar(tester);

      expect(find.text('BALONCESTO'), findsOneWidget);
      expect(find.text('FÚTBOL SALA'), findsOneWidget);
      expect(find.text('NATACIÓN'), findsOneWidget);
      expect(find.text('TENIS'), findsNothing);

      await tester.tap(find.text('NATACIÓN'));
      expect(acciones.vistos, ['NAT-01']);
    });

    testWidgets('buscar y pulsar "Explorar deportes" abre el catálogo', (
      tester,
    ) async {
      final acciones = await _mostrar(tester);

      await tester.enterText(find.byKey(const Key('buscadorLanding')), ' tenis ');
      // Con Enter en el teclado y con el botón.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.tap(find.text('Explorar deportes'));

      expect(acciones.explorar, ['tenis', 'tenis']);
    });

    testWidgets('"Ver todos" abre el catálogo sin texto', (tester) async {
      final acciones = await _mostrar(tester);

      await tester.tap(find.text('Ver todos'));

      expect(acciones.explorar, ['']);
    });

    testWidgets('los botones de la barra llevan a iniciar sesión y registro', (
      tester,
    ) async {
      final acciones = await _mostrar(tester);

      await tester.tap(find.byKey(const Key('landingIniciarSesion')));
      await tester.tap(find.byKey(const Key('landingCrearCuenta')));

      expect(acciones.iniciarSesion, 1);
      expect(acciones.crearCuenta, 1);
    });

    testWidgets('"Cómo funciona" baja hasta los pasos', (tester) async {
      await _mostrar(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Cómo funciona'));
      await tester.pumpAndSettle();

      expect(find.text('4. Paga y listo').hitTestable(), findsOneWidget);
    });
  });

  group('En celular', () {
    testWidgets('se ve sin desbordes y con los botones a mano', (
      tester,
    ) async {
      final acciones = await _mostrar(tester, tamano: _celular);

      expect(tester.takeException(), isNull);
      // El menú de enlaces se oculta; "Crear cuenta" baja al encabezado.
      expect(find.widgetWithText(TextButton, 'Cómo funciona'), findsNothing);

      await tester.tap(find.byKey(const Key('landingIniciarSesion')));
      await tester.tap(find.byKey(const Key('landingCrearCuenta')));
      expect(acciones.iniciarSesion, 1);
      expect(acciones.crearCuenta, 1);
    });
  });

  group('Estados del catálogo', () {
    testWidgets('si falla la carga lo dice', (tester) async {
      await _mostrar(
        tester,
        catalogo: Stream.error(Exception('sin red')),
      );

      expect(
        find.textContaining('No pudimos cargar los deportes'),
        findsOneWidget,
      );
    });

    testWidgets('sin deportes publicados lo dice', (tester) async {
      await _mostrar(tester, catalogo: Stream.value(const []));

      expect(
        find.text('Pronto publicaremos las disciplinas del semestre.'),
        findsOneWidget,
      );
    });
  });
}

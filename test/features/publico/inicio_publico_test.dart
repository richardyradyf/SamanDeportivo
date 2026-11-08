import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/publico/inicio_publico.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

class _DeportesFalsos implements DeporteRepository {
  _DeportesFalsos(this.catalogo);

  final List<Deporte> catalogo;

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value(catalogo);

  @override
  Stream<Deporte?> observar(String codigo) =>
      Stream.value(catalogo.firstWhere((d) => d.codigo == codigo));

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

class _BusquedasFalsas implements BusquedaRepository {
  final guardadas = <Busqueda>[];

  @override
  Future<void> registrar(Busqueda busqueda) async {
    guardadas.add(busqueda);
  }

  @override
  Stream<List<Busqueda>> observarDesde(DateTime desde) =>
      const Stream.empty();
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
];

InicioPublico _inicioPublico({_BusquedasFalsas? busquedas}) => InicioPublico(
  deportes: _DeportesFalsos(_catalogo),
  resenas: _ResenasFalsas(),
  busquedas: busquedas ?? _BusquedasFalsas(),
  construirLogin: (_) => const Scaffold(body: Text('Pantalla de login')),
  construirRegistro: (_) => const Scaffold(body: Text('Pantalla de registro')),
);

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: pantalla));
  await tester.pump();
}

Future<void> _explorar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('buscadorLanding')), texto);
  final explorar = find.text('Explorar deportes');
  await tester.ensureVisible(explorar);
  await tester.tap(explorar);
  await tester.pumpAndSettle();
}

void main() {
  group('Catálogo sin iniciar sesión', () {
    testWidgets('"Explorar deportes" abre el catálogo con lo que se buscó', (
      tester,
    ) async {
      await _mostrar(tester, _inicioPublico());

      await _explorar(tester, 'fut');

      expect(find.byType(CatalogoScreen), findsOneWidget);
      expect(find.text('FÚTBOL SALA'), findsOneWidget);
      expect(find.text('NATACIÓN'), findsNothing);
      final buscador = tester.widget<TextField>(
        find.byKey(const Key('buscadorCatalogo')),
      );
      expect(buscador.controller!.text, 'fut');
    });

    testWidgets('se puede abrir el detalle y leer las reseñas', (
      tester,
    ) async {
      await _mostrar(tester, _inicioPublico());
      await _explorar(tester, '');

      await tester.tap(find.text('FÚTBOL SALA'));
      await tester.pumpAndSettle();

      expect(find.byType(DetalleDeporteScreen), findsOneWidget);
      expect(find.text('Calificaciones y comentarios'), findsOneWidget);
      // Sin sesión no aparece el formulario para calificar.
      expect(find.text('Publicar reseña'), findsNothing);
    });

    testWidgets('"Inscribirme" sin sesión lleva a iniciar sesión', (
      tester,
    ) async {
      await _mostrar(tester, _inicioPublico());
      await _explorar(tester, 'fut');
      await tester.tap(find.text('FÚTBOL SALA'));
      await tester.pumpAndSettle();

      final inscribirme = find.text('Inscribirme');
      await tester.ensureVisible(inscribirme);
      await tester.tap(inscribirme);
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de login'), findsOneWidget);
    });

    testWidgets('las búsquedas sin sesión se registran sin usuario', (
      tester,
    ) async {
      final busquedas = _BusquedasFalsas();
      await _mostrar(tester, _inicioPublico(busquedas: busquedas));
      await _explorar(tester, '');

      await tester.enterText(find.byKey(const Key('buscadorCatalogo')), 'nat');
      await tester.pump(const Duration(seconds: 1));

      final guardada = busquedas.guardadas.single;
      expect(guardada.termino, 'nat');
      expect(guardada.usuarioUid, isNull);
      expect(guardada.deporteIds, ['NAT-01']);
    });
  });

  group('Sesión', () {
    testWidgets('"Iniciar sesión" y "Crear cuenta" abren sus pantallas', (
      tester,
    ) async {
      await _mostrar(tester, _inicioPublico());

      await tester.tap(find.byKey(const Key('landingIniciarSesion')));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de login'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final crearCuenta = find.byKey(const Key('landingCrearCuenta'));
      await tester.ensureVisible(crearCuenta);
      await tester.tap(crearCuenta);
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de registro'), findsOneWidget);
    });

    testWidgets('desde el login se puede volver al landing', (tester) async {
      await _mostrar(tester, _inicioPublico());

      await tester.tap(find.byKey(const Key('landingIniciarSesion')));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de login'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de login'), findsNothing);
      expect(find.byKey(const Key('buscadorLanding')), findsOneWidget);
    });

    testWidgets('al iniciar sesión se cierran las páginas públicas', (
      tester,
    ) async {
      final conSesion = ValueNotifier(false);
      addTearDown(conSesion.dispose);

      // Hace de AuthGate: sin sesión el inicio público; con sesión, otra.
      await _mostrar(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: conSesion,
          builder: (context, sesion, _) => sesion
              ? const Scaffold(body: Text('Inicio del estudiante'))
              : _inicioPublico(),
        ),
      );
      await tester.tap(find.byKey(const Key('landingIniciarSesion')));
      await tester.pumpAndSettle();

      conSesion.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Pantalla de login'), findsNothing);
      expect(find.text('Inicio del estudiante'), findsOneWidget);
    });
  });
}

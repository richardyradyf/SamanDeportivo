import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/analitica_admin_screen.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/dashboard_admin_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';

class _DashboardFake implements DashboardRepository {
  _DashboardFake({this.fallarUsuarios = false});

  final bool fallarUsuarios;

  @override
  Stream<List<Deporte>> observarDeportes() => Stream.value(deportesDePrueba());

  @override
  Stream<List<UsuarioDashboard>> observarUsuarios() => fallarUsuarios
      ? Stream.error(StateError('sin permisos'))
      : Stream.value(const [
          UsuarioDashboard(rol: 'estudiante', estado: 'activo'),
          UsuarioDashboard(rol: 'entrenador'),
        ]);
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: pantalla)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dashboard muestra saludo y estadísticas reales del repositorio',
    (tester) async {
      await _mostrar(
        tester,
        DashboardAdminScreen(
          nombre: 'Ana Pérez',
          repositorio: _DashboardFake(),
        ),
      );
      expect(find.text('Hola, Ana'), findsOneWidget);
      final tarjeta = tester.widget<Text>(
        find.byKey(const Key('a3-valor-deportes')),
      );
      expect(tarjeta.data, '5');
      expect(find.text('Deportes activos'), findsOneWidget);
      expect(find.text('Cupos disponibles'), findsOneWidget);
    },
  );

  testWidgets('analítica presenta gráficos de ocupación y disciplinas', (
    tester,
  ) async {
    await _mostrar(tester, AnaliticaAdminScreen(repositorio: _DashboardFake()));
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Indicadores operativos'), findsOneWidget);
    expect(
      find.byKey(const Key('a34-no-conectada-inscripciones')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('a34-no-conectada-pagos')), findsOneWidget);
    expect(find.byKey(const Key('a34-no-conectada-busquedas')), findsOneWidget);
  });

  testWidgets('se adapta a pantallas estrechas', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardAdminScreen(
            nombre: 'Ana',
            repositorio: _DashboardFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('error de permisos no se representa como cero usuarios', (
    tester,
  ) async {
    await _mostrar(
      tester,
      DashboardAdminScreen(
        nombre: 'Ana',
        repositorio: _DashboardFake(fallarUsuarios: true),
      ),
    );
    expect(find.byKey(const Key('a3-error-fuentes')), findsOneWidget);
    expect(find.byKey(const Key('a3-valor-estudiantes')), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/screens/inicio_admin_screen.dart';

Future<void> _mostrar(
  WidgetTester tester,
  double ancho, {
  Widget? perfil,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: InicioAdminScreen(
        nombre: 'Ana Pérez',
        onCerrarSesion: () {},
        perfil: perfil,
      ),
    ),
  );
}

void main() {
  testWidgets('saluda con "Hola" y el primer nombre', (tester) async {
    await _mostrar(tester, 1280);

    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('en escritorio muestra sus 7 secciones y no tiene Perfil', (
    tester,
  ) async {
    await _mostrar(tester, 1280);

    expect(find.text('ADMINISTRADOR'), findsOneWidget);
    final menu = find.byType(NavigationRail);
    for (final seccion in [
      'Dashboard',
      'Deportes',
      'Entrenadores',
      'Horarios',
      'Inscripciones',
      'Analítica',
      'Configuración',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(seccion)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: menu, matching: find.text('Perfil')),
      findsNothing,
    );
  });

  testWidgets('Configuración muestra perfil real cuando se inyecta', (
    tester,
  ) async {
    await _mostrar(tester, 1280, perfil: const Text('Perfil admin de prueba'));
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil admin de prueba'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('en móvil usa el menú desplegable porque son 7 secciones', (
    tester,
  ) async {
    await _mostrar(tester, 400);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
  });
}

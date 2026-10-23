import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/entrenador/screens/inicio_entrenador_screen.dart';

Future<void> _mostrar(WidgetTester tester, double ancho) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: InicioEntrenadorScreen(
        nombre: 'María Pérez',
        onCerrarSesion: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('saluda con "Hola" y el primer nombre', (tester) async {
    await _mostrar(tester, 1280);

    expect(find.text('Hola, María'), findsOneWidget);
  });

  testWidgets('en escritorio muestra el rol y sus 6 secciones', (tester) async {
    await _mostrar(tester, 1280);

    expect(find.text('ENTRENADOR'), findsOneWidget);
    final menu = find.byType(NavigationRail);
    for (final seccion in [
      'Dashboard',
      'Mis disciplinas',
      'Estudiantes',
      'Asistencia',
      'Historial',
      'Perfil',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(seccion)),
        findsOneWidget,
      );
    }
  });

  testWidgets('en móvil usa el menú desplegable porque son 6 secciones', (
    tester,
  ) async {
    await _mostrar(tester, 400);

    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Historial'),
      ),
      findsOneWidget,
    );
  });
}

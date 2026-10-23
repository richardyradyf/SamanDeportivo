import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
}

int _seccionVisible(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index ?? 0;

InicioEstudianteScreen _pantalla({Widget? perfil}) => InicioEstudianteScreen(
  nombre: 'Ana Pérez',
  onCerrarSesion: () {},
  perfil: perfil,
  reloj: () => DateTime(2026, 10, 22, 9),
);

void main() {
  testWidgets('saluda según la hora y muestra sus 5 secciones', (tester) async {
    await _mostrar(tester, _pantalla());

    expect(find.text('Buenos días, Ana 👋'), findsOneWidget);
    final barra = find.byType(NavigationBar);
    for (final seccion in [
      'Inicio',
      'Explorar',
      'Mis deportes',
      'Inscripciones',
      'Perfil',
    ]) {
      expect(
        find.descendant(of: barra, matching: find.text(seccion)),
        findsOneWidget,
      );
    }
  });

  testWidgets('"Explorar deportes" lleva a la sección Explorar', (
    tester,
  ) async {
    await _mostrar(tester, _pantalla());

    await tester.tap(find.text('Explorar deportes'));
    await tester.pumpAndSettle();

    expect(_seccionVisible(tester), InicioEstudianteScreen.indiceExplorar);
  });

  testWidgets('muestra la pantalla de perfil que se le pase', (tester) async {
    await _mostrar(tester, _pantalla(perfil: const Text('Pantalla de perfil')));

    final barra = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: barra, matching: find.text('Perfil')));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de perfil'), findsOneWidget);
  });
}

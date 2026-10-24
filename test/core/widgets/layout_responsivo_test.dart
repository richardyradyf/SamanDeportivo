import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';

const _dosDestinos = [
  DestinoNavegacion(
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    iconoSeleccionado: Icons.home,
    pantalla: Text('Contenido de Inicio'),
  ),
  DestinoNavegacion(
    etiqueta: 'Perfil',
    icono: Icons.person_outline,
    iconoSeleccionado: Icons.person,
    pantalla: Text('Contenido de Perfil'),
  ),
];

final _seisDestinos = [
  for (var i = 0; i < 6; i++)
    DestinoNavegacion(
      etiqueta: 'Sección $i',
      icono: Icons.circle_outlined,
      iconoSeleccionado: Icons.circle,
      pantalla: Text('Contenido $i'),
    ),
];

/// Dibuja el layout en una pantalla del ancho indicado (en píxeles).
Future<void> _mostrar(
  WidgetTester tester,
  double ancho, {
  List<DestinoNavegacion> destinos = _dosDestinos,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: LayoutResponsivo(
        titulo: 'Samán',
        subtitulo: 'Estudiante',
        destinos: destinos,
      ),
    ),
  );
}

int _seccionVisible(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index ?? 0;

void main() {
  testWidgets('en móvil con 5 secciones o menos usa la barra inferior', (
    tester,
  ) async {
    await _mostrar(tester, 400);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('en móvil con más de 5 secciones usa el menú desplegable', (
    tester,
  ) async {
    await _mostrar(tester, 400, destinos: _seisDestinos);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final menu = find.byType(NavigationDrawer);
    await tester.tap(
      find.descendant(of: menu, matching: find.text('Sección 4')),
    );
    await tester.pumpAndSettle();

    expect(_seccionVisible(tester), 4);
  });

  testWidgets('en tablet (600 a 1024 px) usa la barra lateral compacta', (
    tester,
  ) async {
    await _mostrar(tester, 800);

    expect(find.byType(NavigationBar), findsNothing);
    final menu = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(menu.extended, isFalse);
  });

  testWidgets('en escritorio la barra lateral se expande y muestra el rol', (
    tester,
  ) async {
    await _mostrar(tester, 1280);

    final menu = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(menu.extended, isTrue);
    expect(find.text('SAMÁN'), findsOneWidget);
    expect(find.text('ESTUDIANTE'), findsOneWidget);
  });

  testWidgets('tocar un destino cambia la sección visible', (tester) async {
    await _mostrar(tester, 400);

    final barra = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: barra, matching: find.text('Perfil')));
    await tester.pumpAndSettle();

    expect(_seccionVisible(tester), 1);
  });

  testWidgets('irA permite cambiar de sección desde el contenido', (
    tester,
  ) async {
    final destinos = [
      DestinoNavegacion(
        etiqueta: 'Inicio',
        icono: Icons.home_outlined,
        iconoSeleccionado: Icons.home,
        pantalla: Builder(
          builder: (context) => TextButton(
            onPressed: () => LayoutResponsivo.irA(context, 1),
            child: const Text('Ir a Perfil'),
          ),
        ),
      ),
      _dosDestinos.last,
    ];
    await _mostrar(tester, 400, destinos: destinos);

    await tester.tap(find.text('Ir a Perfil'));
    await tester.pumpAndSettle();

    expect(_seccionVisible(tester), 1);
  });
}

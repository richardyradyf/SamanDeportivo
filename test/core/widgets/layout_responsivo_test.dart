import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';

const _destinos = [
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

/// Dibuja el layout en una pantalla del ancho indicado (en píxeles).
Future<void> _mostrarConAncho(WidgetTester tester, double ancho) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: LayoutResponsivo(titulo: 'Prueba', destinos: _destinos),
    ),
  );
}

void main() {
  testWidgets('en móvil (< 600 px) usa la barra inferior', (tester) async {
    await _mostrarConAncho(tester, 400);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('en tablet (600 a 1024 px) usa el menú lateral compacto', (
    tester,
  ) async {
    await _mostrarConAncho(tester, 800);

    expect(find.byType(NavigationBar), findsNothing);
    final menu = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(menu.extended, isFalse);
  });

  testWidgets('en escritorio (> 1024 px) el menú lateral se expande', (
    tester,
  ) async {
    await _mostrarConAncho(tester, 1280);

    final menu = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(menu.extended, isTrue);
  });

  testWidgets('tocar un destino cambia la sección visible', (tester) async {
    await _mostrarConAncho(tester, 400);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    final secciones = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(secciones.index, 1);
  });
}

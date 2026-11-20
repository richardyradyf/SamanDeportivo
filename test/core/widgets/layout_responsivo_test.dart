import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
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
  List<Widget> acciones = const [],
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: LayoutResponsivo(
        titulo: 'Samán',
        subtitulo: 'Estudiante',
        destinos: destinos,
        acciones: acciones,
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

  testWidgets('las acciones muestran texto en escritorio e ícono en móvil', (
    tester,
  ) async {
    final acciones = [
      AccionNavegacion(
        etiqueta: 'Reservas',
        icono: Icons.event_available_outlined,
        onPressed: () {},
      ),
      AccionNavegacion(
        etiqueta: 'Pagos',
        icono: Icons.payments_outlined,
        onPressed: () {},
      ),
    ];

    await _mostrar(tester, 1280, acciones: acciones);
    expect(find.widgetWithText(TextButton, 'Reservas'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Pagos'), findsOneWidget);

    // Los dos accesos deben comenzar en la misma columna que los destinos.
    final iconoInicio = tester.getTopLeft(find.byIcon(Icons.home)).dx;
    final textoInicio = tester.getTopLeft(find.text('Inicio')).dx;
    for (final (icono, etiqueta) in [
      (Icons.event_available_outlined, 'Reservas'),
      (Icons.payments_outlined, 'Pagos'),
    ]) {
      expect(
        (tester.getTopLeft(find.byIcon(icono)).dx - iconoInicio).abs(),
        lessThan(12),
      );
      expect(
        (tester.getTopLeft(find.text(etiqueta)).dx - textoInicio).abs(),
        lessThan(12),
      );
      expect(
        tester.widget<Text>(find.text(etiqueta)).style,
        AppTheme.claro.navigationRailTheme.unselectedLabelTextStyle,
      );
    }

    await _mostrar(tester, 400, acciones: acciones);
    expect(find.byTooltip('Reservas'), findsOneWidget);
    expect(find.byTooltip('Pagos'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reservas'), findsNothing);
  });

  testWidgets('las etiquetas largas del menú lateral no saltan de línea', (
    tester,
  ) async {
    await _mostrar(
      tester,
      1280,
      destinos: [
        const DestinoNavegacion(
          etiqueta: 'Mis disciplinas deportivas universitarias',
          icono: Icons.sports_outlined,
          iconoSeleccionado: Icons.sports,
          pantalla: Text('Contenido'),
        ),
        _dosDestinos.last,
      ],
    );

    final etiqueta = tester.widget<Text>(
      find.text('Mis disciplinas deportivas universitarias'),
    );
    expect(etiqueta.maxLines, 1);
    expect(etiqueta.softWrap, isFalse);
    expect(etiqueta.overflow, TextOverflow.ellipsis);
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

  testWidgets('en escritorio aparece fondo oscuro y marca blanca', (
    tester,
  ) async {
    await _mostrar(tester, 1280);

    final rail = find.byType(NavigationRail);
    final contexto = tester.element(rail);
    final estilo = Theme.of(contexto).navigationRailTheme;
    expect(estilo.backgroundColor, AppColors.primarioOscuro);
    expect(estilo.indicatorColor, AppColors.sidebarSeleccion);
    expect(tester.widget<Text>(find.text('SAMÁN')).style?.color, Colors.white);
    expect(
      tester.widget<Text>(find.text('ESTUDIANTE')).style?.color,
      AppColors.sidebarRol,
    );
  });

  testWidgets('en movil el menu desplegable mantiene la marca oscura', (
    tester,
  ) async {
    await _mostrar(tester, 400, destinos: _seisDestinos);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDrawer), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('SAMÁN')).style?.color,
      AppColors.texto,
    );
  });
}

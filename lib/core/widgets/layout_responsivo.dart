import 'package:flutter/material.dart';

/// Una sección de la navegación principal (por ejemplo "Explorar" o "Perfil").
class DestinoNavegacion {
  const DestinoNavegacion({
    required this.etiqueta,
    required this.icono,
    required this.iconoSeleccionado,
    required this.pantalla,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoSeleccionado;

  /// Contenido que se muestra al elegir este destino.
  final Widget pantalla;
}

/// Estructura común de las pantallas de inicio de los tres roles.
///
/// Cambia la navegación según el ancho disponible (convenciones, sección 10):
/// * móvil (< 600 px): barra inferior si hay 5 secciones o menos; si hay
///   más (entrenador y administrador), menú desplegable desde la izquierda,
///   porque una barra inferior con 6 o 7 botones queda ilegible;
/// * tablet (600 a 1024 px): barra lateral compacta;
/// * escritorio (> 1024 px): barra lateral expandida con la marca y el rol,
///   como en el Figma.
///
/// Los colores salen del tema de la app: aquí no se pone ninguno a mano.
class LayoutResponsivo extends StatefulWidget {
  const LayoutResponsivo({
    super.key,
    required this.titulo,
    required this.destinos,
    this.subtitulo,
    this.acciones = const [],
  });

  /// Marca que se muestra arriba del menú (por ejemplo "Samán").
  final String titulo;

  /// Texto bajo la marca; en la app, el rol (por ejemplo "Estudiante").
  final String? subtitulo;

  /// Secciones de la navegación. Deben ser al menos 2.
  final List<DestinoNavegacion> destinos;

  /// Botones extra, como cerrar sesión: van en la barra superior en móvil
  /// y debajo del menú lateral en tablet y escritorio.
  final List<Widget> acciones;

  static const double anchoTablet = 600;
  static const double anchoEscritorio = 1024;
  static const int maxDestinosBarraInferior = 5;

  /// Cambia de sección desde el contenido de otra sección; por ejemplo,
  /// el botón "Explorar deportes" del inicio del estudiante.
  static void irA(BuildContext context, int indice) {
    context.findAncestorStateOfType<_LayoutResponsivoState>()?._seleccionar(
      indice,
    );
  }

  @override
  State<LayoutResponsivo> createState() => _LayoutResponsivoState();
}

class _LayoutResponsivoState extends State<LayoutResponsivo> {
  final _llaveScaffold = GlobalKey<ScaffoldState>();

  // El destino elegido solo le importa a esta pantalla: por eso setState.
  int _indice = 0;

  void _seleccionar(int indice) {
    setState(() => _indice = indice);
  }

  /// Marca y rol que encabezan el menú lateral (como en el Figma).
  Widget _encabezado(BuildContext context, {required bool compacto}) {
    final tema = Theme.of(context);
    final subtitulo = widget.subtitulo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: compacto
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            widget.titulo.toUpperCase(),
            style:
                (compacto
                        ? tema.textTheme.labelLarge
                        : tema.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (!compacto && subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo.toUpperCase(),
              style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinos = widget.destinos;
    final indice = _indice.clamp(0, destinos.length - 1);

    // IndexedStack mantiene vivas todas las secciones: al volver a una
    // pestaña se conserva lo que el usuario estaba viendo.
    final contenido = IndexedStack(
      index: indice,
      children: [for (final destino in destinos) destino.pantalla],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;

        // ---------- Móvil ----------
        if (ancho < LayoutResponsivo.anchoTablet) {
          final usarBarraInferior =
              destinos.length <= LayoutResponsivo.maxDestinosBarraInferior;
          return Scaffold(
            key: _llaveScaffold,
            appBar: AppBar(
              title: Text(destinos[indice].etiqueta),
              actions: widget.acciones,
            ),
            body: contenido,
            bottomNavigationBar: usarBarraInferior
                ? NavigationBar(
                    selectedIndex: indice,
                    onDestinationSelected: _seleccionar,
                    destinations: [
                      for (final destino in destinos)
                        NavigationDestination(
                          icon: Icon(destino.icono),
                          selectedIcon: Icon(destino.iconoSeleccionado),
                          label: destino.etiqueta,
                        ),
                    ],
                  )
                : null,
            drawer: usarBarraInferior
                ? null
                : NavigationDrawer(
                    selectedIndex: indice,
                    onDestinationSelected: (nuevo) {
                      _seleccionar(nuevo);
                      _llaveScaffold.currentState?.closeDrawer();
                    },
                    children: [
                      _encabezado(context, compacto: false),
                      for (final destino in destinos)
                        NavigationDrawerDestination(
                          icon: Icon(destino.icono),
                          selectedIcon: Icon(destino.iconoSeleccionado),
                          label: Text(destino.etiqueta),
                        ),
                    ],
                  ),
          );
        }

        // ---------- Tablet y escritorio ----------
        final expandido = ancho > LayoutResponsivo.anchoEscritorio;
        return Scaffold(
          key: _llaveScaffold,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: indice,
                onDestinationSelected: _seleccionar,
                extended: expandido,
                // Expandido, los nombres van al lado del ícono; compacto,
                // debajo.
                labelType: expandido
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: _encabezado(context, compacto: !expandido),
                trailing: widget.acciones.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.acciones,
                        ),
                      ),
                destinations: [
                  for (final destino in destinos)
                    NavigationRailDestination(
                      icon: Icon(destino.icono),
                      selectedIcon: Icon(destino.iconoSeleccionado),
                      label: Text(destino.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: SafeArea(child: contenido)),
            ],
          ),
        );
      },
    );
  }
}

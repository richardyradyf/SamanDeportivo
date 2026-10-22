import 'package:flutter/material.dart';

/// Una sección de la navegación principal (por ejemplo "Deportes" o "Perfil").
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
/// * móvil (< 600 px): barra inferior ([NavigationBar]);
/// * tablet (600 a 1024 px): menú lateral compacto ([NavigationRail]);
/// * escritorio (> 1024 px): menú lateral expandido, con los nombres al lado.
class LayoutResponsivo extends StatefulWidget {
  const LayoutResponsivo({
    super.key,
    required this.titulo,
    required this.destinos,
    this.acciones = const [],
  });

  final String titulo;

  /// Secciones de la navegación. Deben ser al menos 2.
  final List<DestinoNavegacion> destinos;

  /// Botones a la derecha de la barra superior (por ejemplo, cerrar sesión).
  final List<Widget> acciones;

  static const double anchoTablet = 600;
  static const double anchoEscritorio = 1024;

  @override
  State<LayoutResponsivo> createState() => _LayoutResponsivoState();
}

class _LayoutResponsivoState extends State<LayoutResponsivo> {
  // El destino elegido solo le importa a esta pantalla: por eso setState.
  int _indice = 0;

  void _seleccionar(int indice) {
    setState(() => _indice = indice);
  }

  @override
  Widget build(BuildContext context) {
    final indice = _indice.clamp(0, widget.destinos.length - 1);

    // IndexedStack mantiene vivas todas las secciones: al volver a una
    // pestaña se conserva lo que el usuario estaba viendo.
    final contenido = IndexedStack(
      index: indice,
      children: [for (final destino in widget.destinos) destino.pantalla],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final barraSuperior = AppBar(
          title: Text(widget.titulo),
          actions: widget.acciones,
        );

        // Móvil: barra de navegación abajo, al alcance del pulgar.
        if (ancho < LayoutResponsivo.anchoTablet) {
          return Scaffold(
            appBar: barraSuperior,
            body: contenido,
            bottomNavigationBar: NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: _seleccionar,
              destinations: [
                for (final destino in widget.destinos)
                  NavigationDestination(
                    icon: Icon(destino.icono),
                    selectedIcon: Icon(destino.iconoSeleccionado),
                    label: destino.etiqueta,
                  ),
              ],
            ),
          );
        }

        // Tablet y escritorio: menú lateral; en escritorio, expandido.
        final expandido = ancho > LayoutResponsivo.anchoEscritorio;
        return Scaffold(
          appBar: barraSuperior,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: indice,
                onDestinationSelected: _seleccionar,
                extended: expandido,
                // Con el menú expandido los nombres ya se ven al lado
                // del ícono; en el compacto se muestran debajo.
                labelType: expandido
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final destino in widget.destinos)
                    NavigationRailDestination(
                      icon: Icon(destino.icono),
                      selectedIcon: Icon(destino.iconoSeleccionado),
                      label: Text(destino.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: contenido),
            ],
          ),
        );
      },
    );
  }
}

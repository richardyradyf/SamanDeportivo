import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/cuadricula_deportes.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Página de inicio pública, para quien todavía no inicia sesión
/// (página "Landing" del Figma).
///
/// Muestra la marca, un buscador, algunos deportes del catálogo y cómo
/// funciona la inscripción. No navega por su cuenta: avisa con callbacks
/// qué tocó el visitante, así se puede probar sin Firebase.
class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.onIniciarSesion,
    required this.onCrearCuenta,
    required this.onExplorar,
    this.onVerDeporte,
    this.deportes,
  });

  final VoidCallback onIniciarSesion;
  final VoidCallback onCrearCuenta;

  /// Abre el catálogo completo con el texto escrito en el buscador
  /// (vacío si no escribió nada).
  final ValueChanged<String> onExplorar;

  /// Abre el detalle de un deporte de "Explora disciplinas".
  final ValueChanged<Deporte>? onVerDeporte;

  /// Si es null y Firebase está iniciado, se usa Firestore.
  final DeporteRepository? deportes;

  /// Deportes que se muestran en "Explora disciplinas".
  static const int deportesDestacados = 3;

  /// Desde este ancho el menú y la imagen del encabezado se muestran
  /// completos; por debajo, la versión de celular.
  static const double anchoComputadora = 840;

  /// Primero los deportes con cupo y, dentro de cada grupo, por nombre.
  static List<Deporte> destacados(List<Deporte> catalogo) {
    final ordenados = [...catalogo]
      ..sort((a, b) {
        if (a.tieneCupo != b.tieneCupo) return a.tieneCupo ? -1 : 1;
        return normalizarBusqueda(a.nombre).compareTo(normalizarBusqueda(b.nombre));
      });
    return ordenados.take(deportesDestacados).toList();
  }

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _buscador = TextEditingController();
  final _llaveDeportes = GlobalKey();
  final _llaveComoFunciona = GlobalKey();
  Stream<List<Deporte>>? _catalogo;

  @override
  void initState() {
    super.initState();
    final deportes =
        widget.deportes ??
        (Firebase.apps.isNotEmpty ? FirestoreDeporteRepository() : null);
    _catalogo = deportes?.observarCatalogo();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  void _explorar() => widget.onExplorar(_buscador.text.trim());

  void _irA(GlobalKey llave) {
    final contexto = llave.currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth >= LandingScreen.anchoComputadora;
        final margen = ancho ? 48.0 : 16.0;

        Widget seccion(Widget hijo) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: margen),
              child: hijo,
            ),
          ),
        );

        return Scaffold(
          appBar: _Encabezado(
            ancho: ancho,
            onDeportes: () => _irA(_llaveDeportes),
            onComoFunciona: () => _irA(_llaveComoFunciona),
            onIniciarSesion: widget.onIniciarSesion,
            onCrearCuenta: widget.onCrearCuenta,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: ancho ? 48 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                seccion(
                  _Portada(
                    ancho: ancho,
                    buscador: _buscador,
                    onExplorar: _explorar,
                    onCrearCuenta: widget.onCrearCuenta,
                  ),
                ),
                SizedBox(height: ancho ? 56 : 32),
                seccion(
                  KeyedSubtree(
                    key: _llaveDeportes,
                    child: _Disciplinas(
                      catalogo: _catalogo,
                      onVerDeporte: widget.onVerDeporte,
                      onVerTodos: () => widget.onExplorar(''),
                    ),
                  ),
                ),
                SizedBox(height: ancho ? 56 : 32),
                seccion(
                  KeyedSubtree(
                    key: _llaveComoFunciona,
                    child: const _ComoFunciona(),
                  ),
                ),
                const SizedBox(height: 40),
                seccion(const _Pie()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra superior: marca, enlaces y botones de sesión.
class _Encabezado extends StatelessWidget implements PreferredSizeWidget {
  const _Encabezado({
    required this.ancho,
    required this.onDeportes,
    required this.onComoFunciona,
    required this.onIniciarSesion,
    required this.onCrearCuenta,
  });

  final bool ancho;
  final VoidCallback onDeportes;
  final VoidCallback onComoFunciona;
  final VoidCallback onIniciarSesion;
  final VoidCallback onCrearCuenta;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final marca = Text(
      'SAMÁN DEPORTIVO',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tema.textTheme.titleMedium?.copyWith(
        color: tema.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );

    return Material(
      color: tema.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: EdgeInsets.symmetric(horizontal: ancho ? 32 : 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tema.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              // En celular la marca usa el espacio que dejan los botones.
              if (ancho) marca else Expanded(child: marca),
              if (ancho) ...[
                const SizedBox(width: 48),
                TextButton(
                  onPressed: onDeportes,
                  style: TextButton.styleFrom(
                    foregroundColor: tema.colorScheme.onSurface,
                  ),
                  child: const Text('Deportes'),
                ),
                TextButton(
                  onPressed: onComoFunciona,
                  style: TextButton.styleFrom(
                    foregroundColor: tema.colorScheme.onSurface,
                  ),
                  child: const Text('Cómo funciona'),
                ),
              ],
              if (ancho) const Spacer() else const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('landingIniciarSesion'),
                onPressed: onIniciarSesion,
                style: ancho
                    ? null
                    : OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                child: const Text('Iniciar sesión'),
              ),
              if (ancho) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('landingCrearCuenta'),
                  onPressed: onCrearCuenta,
                  child: const Text('Crear cuenta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Título, buscador y botón "Explorar deportes", con la imagen al lado en
/// computadora.
class _Portada extends StatelessWidget {
  const _Portada({
    required this.ancho,
    required this.buscador,
    required this.onExplorar,
    required this.onCrearCuenta,
  });

  final bool ancho;
  final TextEditingController buscador;
  final VoidCallback onExplorar;
  final VoidCallback onCrearCuenta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encuentra tu próximo deporte en la UNIMET.',
          style: (ancho
                  ? tema.textTheme.headlineLarge
                  : tema.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 12),
        Text(
          'Consulta disciplinas, horarios y cupos disponibles e inscríbete '
          'desde un solo lugar.',
          style: tema.textTheme.bodyLarge?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: TextField(
            key: const Key('buscadorLanding'),
            controller: buscador,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onExplorar(),
            decoration: const InputDecoration(
              hintText: 'Busca fútbol, tenis, baloncesto…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: onExplorar,
              child: const Text('Explorar deportes'),
            ),
            // En computadora "Crear cuenta" ya está en la barra superior.
            if (!ancho)
              OutlinedButton(
                key: const Key('landingCrearCuenta'),
                onPressed: onCrearCuenta,
                child: const Text('Crear cuenta'),
              ),
          ],
        ),
      ],
    );

    if (!ancho) return textos;

    final colores = tema.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: textos),
        const SizedBox(width: 48),
        Expanded(
          child: ExcludeSemantics(
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                color: colores.secondary,
                borderRadius: BorderRadius.circular(AppTheme.radioTarjeta + 8),
              ),
              child: Center(
                child: Wrap(
                  spacing: 24,
                  children: [
                    for (final icono in const [
                      Icons.sports_soccer,
                      Icons.sports_tennis,
                      Icons.pool,
                      Icons.sports_basketball,
                    ])
                      Icon(icono, size: 48, color: colores.onSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Explora disciplinas": algunos deportes del catálogo en tiempo real.
class _Disciplinas extends StatelessWidget {
  const _Disciplinas({
    required this.catalogo,
    required this.onVerTodos,
    this.onVerDeporte,
  });

  final Stream<List<Deporte>>? catalogo;
  final VoidCallback onVerTodos;
  final ValueChanged<Deporte>? onVerDeporte;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final titulo = Row(
      children: [
        Expanded(
          child: Text('Explora disciplinas', style: tema.textTheme.headlineSmall),
        ),
        TextButton(
          onPressed: onVerTodos,
          child: const Text('Ver todos'),
        ),
      ],
    );

    final stream = catalogo;
    if (stream == null) return titulo;

    return StreamBuilder<List<Deporte>>(
      stream: stream,
      builder: (context, snapshot) {
        final Widget contenido;
        if (snapshot.hasError) {
          contenido = Text(
            'No pudimos cargar los deportes. Inténtalo de nuevo más tarde.',
            style: tema.textTheme.bodyMedium,
          );
        } else if (!snapshot.hasData) {
          contenido = const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.data!.isEmpty) {
          contenido = Text(
            'Pronto publicaremos las disciplinas del semestre.',
            style: tema.textTheme.bodyMedium,
          );
        } else {
          contenido = CuadriculaDeportes(
            deportes: LandingScreen.destacados(snapshot.data!),
            onVerDeporte: onVerDeporte,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [titulo, const SizedBox(height: 16), contenido],
        );
      },
    );
  }
}

/// "Cómo funciona": los pasos para inscribirse.
class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  static const _pasos = [
    (Icons.search, 'Busca', 'Filtra por disciplina, día, horario o cupos.'),
    (
      Icons.sports,
      'Elige tu deporte',
      'Revisa el horario, el entrenador y lo que opinan otros estudiantes.',
    ),
    (
      Icons.how_to_reg,
      'Inscríbete',
      'Inicia sesión con tu correo UNIMET y reserva tu cupo.',
    ),
    (
      Icons.payments_outlined,
      'Paga y listo',
      'Paga la reserva con PayPal y tu inscripción queda confirmada.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cómo funciona', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const espacio = 16.0;
            final columnas = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final anchoPaso =
                (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              children: [
                for (var i = 0; i < _pasos.length; i++)
                  SizedBox(
                    width: anchoPaso,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  tema.colorScheme.primaryContainer,
                              foregroundColor:
                                  tema.colorScheme.onPrimaryContainer,
                              child: Icon(_pasos[i].$1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${i + 1}. ${_pasos[i].$2}',
                              style: tema.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(_pasos[i].$3, style: tema.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Divider(color: tema.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(
          'Samán Deportivo · Universidad Metropolitana',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodySmall,
        ),
      ],
    );
  }
}

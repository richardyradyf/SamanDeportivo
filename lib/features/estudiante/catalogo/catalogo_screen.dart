import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/data/firestore_busqueda_repository.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/registro_busquedas.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/cuadricula_deportes.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/panel_filtros.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Catálogo de deportes del estudiante, pestaña "Explorar" (RF-05, RF-06).
///
/// Escucha los deportes activos en tiempo real y aplica la búsqueda y los
/// filtros en la app con [FiltroCatalogo]. El repositorio se puede pasar
/// por parámetro para probar la pantalla sin Firebase.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({
    super.key,
    this.repositorio,
    this.busquedas,
    this.usuarioUid,
    this.onVerDeporte,
  });

  final DeporteRepository? repositorio;

  /// Dónde se guardan las búsquedas para las métricas (RF-18). Si es null
  /// y Firebase está iniciado, se usa Firestore.
  final BusquedaRepository? busquedas;

  /// UID de quien busca; null si no hay sesión.
  final String? usuarioUid;

  /// Qué hacer al tocar una tarjeta (abrir el detalle del deporte).
  final void Function(Deporte deporte)? onVerDeporte;

  /// Desde este ancho los filtros van en un panel lateral; por debajo,
  /// en una hoja que se abre con el botón "Filtros".
  static const double anchoPanelLateral = 840;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _buscador = TextEditingController();
  Stream<List<Deporte>>? _deportes;
  FiltroCatalogo _filtro = const FiltroCatalogo();
  RegistroBusquedas? _registro;

  /// Último catálogo recibido, para calcular los resultados que se guardan.
  List<Deporte> _catalogoActual = const [];

  @override
  void initState() {
    super.initState();
    // Igual que en la pantalla de deportes del administrador: si Firebase
    // no está iniciado (pruebas del inicio), no se abre Firestore.
    final repositorio =
        widget.repositorio ??
        (Firebase.apps.isNotEmpty ? FirestoreDeporteRepository() : null);
    _deportes = repositorio?.observarCatalogo();

    final busquedas =
        widget.busquedas ??
        (Firebase.apps.isNotEmpty ? FirestoreBusquedaRepository() : null);
    if (busquedas != null) {
      _registro = RegistroBusquedas(
        repositorio: busquedas,
        usuarioUid: widget.usuarioUid,
      );
    }
  }

  @override
  void dispose() {
    _registro?.dispose();
    _buscador.dispose();
    super.dispose();
  }

  void _cambiarFiltro(FiltroCatalogo nuevo) {
    setState(() => _filtro = nuevo);
    _registro?.programar(nuevo, () => nuevo.aplicar(_catalogoActual));
  }

  void _confirmarBusqueda() {
    _registro?.confirmar(_filtro, _filtro.aplicar(_catalogoActual));
  }

  void _limpiarTodo() {
    _buscador.clear();
    _cambiarFiltro(const FiltroCatalogo());
  }

  Future<void> _abrirFiltros(List<String> especialidades) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, actualizarHoja) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PanelFiltros(
                  filtro: _filtro,
                  especialidades: especialidades,
                  onCambio: (nuevo) {
                    _cambiarFiltro(nuevo);
                    actualizarHoja(() {});
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ver resultados'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deportes = _deportes;
    if (deportes == null) {
      return const _Aviso(
        icono: Icons.cloud_off,
        titulo: 'Catálogo no disponible',
        mensaje: 'No hay conexión con la base de datos.',
      );
    }

    return StreamBuilder<List<Deporte>>(
      stream: deportes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Aviso(
            icono: Icons.error_outline,
            titulo: 'No pudimos cargar los deportes',
            mensaje: 'Revisa tu conexión e inténtalo de nuevo.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) => _contenido(
            context,
            snapshot.data!,
            lateral: constraints.maxWidth >= CatalogoScreen.anchoPanelLateral,
          ),
        );
      },
    );
  }

  Widget _contenido(
    BuildContext context,
    List<Deporte> catalogo, {
    required bool lateral,
  }) {
    final tema = Theme.of(context);
    _catalogoActual = catalogo;
    final especialidades = FiltroCatalogo.especialidadesDe(catalogo);
    final resultados = _filtro.aplicar(catalogo);
    final cantidad = _filtro.cantidadFiltros;

    final buscador = TextField(
      key: const Key('buscadorCatalogo'),
      controller: _buscador,
      onChanged: (texto) => _cambiarFiltro(_filtro.copyWith(texto: texto)),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _confirmarBusqueda(),
      decoration: InputDecoration(
        hintText: 'Buscar deporte o código',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buscador.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _buscador.clear();
                  _cambiarFiltro(_filtro.copyWith(texto: ''));
                },
              ),
      ),
    );

    final Widget lista;
    if (catalogo.isEmpty) {
      lista = const _Aviso(
        icono: Icons.sports,
        titulo: 'Todavía no hay deportes publicados',
        mensaje: 'Vuelve pronto para ver las disciplinas disponibles.',
      );
    } else if (resultados.isEmpty) {
      lista = _Aviso(
        icono: Icons.search_off,
        titulo: 'No encontramos deportes',
        mensaje: 'Prueba con otra búsqueda o quita algunos filtros.',
        accion: OutlinedButton(
          onPressed: _limpiarTodo,
          child: const Text('Limpiar búsqueda y filtros'),
        ),
      );
    } else {
      lista = CuadriculaDeportes(
        deportes: resultados,
        onVerDeporte: widget.onVerDeporte,
      );
    }

    final total = Text(
      resultados.length == 1
          ? '1 deporte'
          : '${resultados.length} deportes',
      style: tema.textTheme.bodySmall,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(lateral ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deportes',
            style: lateral
                ? tema.textTheme.headlineLarge
                : tema.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Encuentra una disciplina para ti.',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (lateral)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: buscador,
            )
          else
            Row(
              children: [
                Expanded(child: buscador),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('botonFiltros'),
                  onPressed: () => _abrirFiltros(especialidades),
                  icon: const Icon(Icons.tune),
                  label: Text(cantidad > 0 ? 'Filtros ($cantidad)' : 'Filtros'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (lateral)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PanelFiltros(
                        filtro: _filtro,
                        especialidades: especialidades,
                        onCambio: _cambiarFiltro,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [total, const SizedBox(height: 12), lista],
                  ),
                ),
              ],
            )
          else ...[
            total,
            const SizedBox(height: 12),
            lista,
          ],
        ],
      ),
    );
  }
}

/// Mensaje centrado para estados vacíos y errores.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: tema.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              mensaje,
              style: tema.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

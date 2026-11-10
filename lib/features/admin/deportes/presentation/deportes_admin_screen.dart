import 'package:saman_deportivo/features/admin/administracion/presentation/resenas_admin_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

import 'formulario_deporte.dart';

/// Gestión administrativa de deportes. Un repositorio inyectado permite
/// probar la pantalla sin Firebase y reutilizar el contrato del Hito 3.
class DeportesAdminScreen extends StatefulWidget {
  const DeportesAdminScreen({super.key, this.repositorio});

  final DeporteRepository? repositorio;

  @override
  State<DeportesAdminScreen> createState() => _DeportesAdminScreenState();
}

class _DeportesAdminScreenState extends State<DeportesAdminScreen> {
  late final DeporteRepository? _repositorio;
  late final Stream<List<Deporte>>? _deportes;
  final _busqueda = TextEditingController();
  bool _mostrarInactivos = true;

  @override
  void initState() {
    super.initState();
    // Las pruebas existentes del widget InicioAdminScreen no inicializan
    // Firebase. No intentamos abrir Firestore en ese caso.
    _repositorio =
        widget.repositorio ??
        (Firebase.apps.isNotEmpty ? FirestoreDeporteRepository() : null);
    _deportes = _repositorio?.observarCatalogo(soloActivos: false);
    _busqueda.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _busqueda.removeListener(_refrescar);
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario([Deporte? inicial]) async {
    final repo = _repositorio;
    if (repo == null) return;
    final exitoso = await showDialog<bool>(
      context: context,
      builder: (_) => FormularioDeporte(
        inicial: inicial,
        guardar: (deporte) =>
            inicial == null ? repo.crear(deporte) : repo.actualizar(deporte),
      ),
    );
    if (!mounted || exitoso != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inicial == null
              ? 'Deporte creado correctamente.'
              : 'Deporte actualizado correctamente.',
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Deporte deporte) async {
    final repo = _repositorio;
    if (repo == null) return;
    final activar = !deporte.activo;
    if (!activar) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Desactivar deporte'),
          content: Text(
            '¿Quieres desactivar ${deporte.nombre}? El deporte dejará '
            'de ofrecerse para nuevas inscripciones, pero conservará su historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }
    try {
      if (activar) {
        await repo.actualizar(deporte.copyWith(activo: true));
      } else {
        await repo.desactivar(deporte.codigo);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activar ? 'Deporte activado.' : 'Deporte desactivado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deportes', style: tema.textTheme.headlineSmall),
                  Text(
                    'Administra disciplinas y cupos.',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
              FilledButton.icon(
                key: const Key('nuevo-deporte'),
                onPressed: _repositorio == null
                    ? null
                    : () => _abrirFormulario(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo deporte'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('buscar-deporte'),
            controller: _busqueda,
            decoration: const InputDecoration(
              labelText: 'Buscar por código o nombre',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Mostrar deportes inactivos'),
            contentPadding: EdgeInsets.zero,
            value: _mostrarInactivos,
            onChanged: (valor) => setState(() => _mostrarInactivos = valor),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _deportes == null
                ? const Center(child: Text('Firebase no está inicializado.'))
                : StreamBuilder<List<Deporte>>(
                    stream: _deportes,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'No se pudo cargar el catálogo: ${snapshot.error}',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final termino = normalizarBusqueda(_busqueda.text.trim());
                      final resultado =
                          snapshot.data!
                              .where(
                                (deporte) =>
                                    _mostrarInactivos || deporte.activo,
                              )
                              .where(
                                (deporte) =>
                                    termino.isEmpty ||
                                    normalizarBusqueda(deporte.codigo)
                                        .contains(termino) ||
                                    normalizarBusqueda(deporte.nombre)
                                        .contains(termino),
                              )
                              .toList()
                            ..sort((a, b) => a.nombre.compareTo(b.nombre));
                      if (resultado.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay deportes que coincidan con la búsqueda.',
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: resultado.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final deporte = resultado[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        deporte.nombre,
                                        style: tema.textTheme.titleMedium,
                                      ),
                                      Chip(label: Text(deporte.codigo)),
                                      Chip(
                                        label: Text(
                                          deporte.activo
                                              ? 'Activo'
                                              : 'Inactivo',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    deporte.descripcion,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cupos: ${deporte.cuposOcupados}/${deporte.cupoMaximo}  ·  '
                                    'Confirmados: ${deporte.cuposConfirmados}  ·  '
                                    'Costo: USD ${deporte.costo.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        key: Key('editar-${deporte.codigo}'),
                                        onPressed: () =>
                                            _abrirFormulario(deporte),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Editar'),
                                      ),
                                      OutlinedButton.icon(
                                        key: Key('estado-${deporte.codigo}'),
                                        onPressed: () =>
                                            _cambiarEstado(deporte),
                                        icon: Icon(
                                          deporte.activo
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        label: Text(
                                          deporte.activo
                                              ? 'Desactivar'
                                              : 'Activar',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        key: Key('resenas-${deporte.codigo}'),
                                        onPressed: () => Navigator.of(context)
                                            .push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    ResenasAdminScreen(
                                                      deporteInicial:
                                                          deporte.codigo,
                                                    ),
                                              ),
                                            ),
                                        icon: const Icon(
                                          Icons.rate_review_outlined,
                                        ),
                                        label: const Text('Ver reseñas'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

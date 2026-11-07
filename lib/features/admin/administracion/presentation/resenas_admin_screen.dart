import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/admin/administracion/data/resenas_admin_repository.dart';
import 'package:saman_deportivo/features/admin/administracion/domain/filtro_administrativo.dart';
import 'package:saman_deportivo/features/admin/administracion/domain/panel_resenas_admin.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Vista global desde Dashboard, o filtrada cuando se abre desde Deportes.
class ResenasAdminScreen extends StatefulWidget {
  const ResenasAdminScreen({super.key, this.repositorio, this.deporteInicial});

  final ResenasAdminRepository? repositorio;
  final String? deporteInicial;

  @override
  State<ResenasAdminScreen> createState() => _ResenasAdminScreenState();
}

class _ResenasAdminScreenState extends State<ResenasAdminScreen> {
  static const _todos = '__todos__';
  late final ResenasAdminRepository? _repositorio;
  late final Stream<PanelResenasAdmin>? _panel;
  final _busqueda = TextEditingController();
  final _guardando = <String>{};
  String? _seleccionado;
  bool _soloOcultas = false;

  @override
  void initState() {
    super.initState();
    _seleccionado = widget.deporteInicial;
    _repositorio =
        widget.repositorio ??
        (Firebase.apps.isEmpty ? null : FirestoreResenasAdminRepository());
    _panel = _repositorio == null ? null : observarPanelResenas(_repositorio);
    _busqueda.addListener(_actualizar);
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _busqueda.removeListener(_actualizar);
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cambiarVisibilidad(String codigo, Resena resena) async {
    final repo = _repositorio;
    final clave = '$codigo/${resena.estudianteUid}';
    if (repo == null || _guardando.contains(clave)) return;
    final nuevaOculta = !resena.oculta;
    final accion = nuevaOculta ? 'Ocultar' : 'Mostrar';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$accion reseña'),
        content: Text(
          '¿Confirmas que deseas ${accion.toLowerCase()} la reseña de '
          '${resena.estudianteNombre}? El contenido se conserva sin editar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-visibilidad-resena'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    setState(() => _guardando.add(clave));
    try {
      await repo.cambiarVisibilidad(
        codigo,
        resena.estudianteUid,
        oculta: nuevaOculta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visibilidad de la reseña actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo modificar la reseña: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando.remove(clave));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Moderación de reseñas')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Todas las reseñas', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Consulta reseñas por deporte y controla su visibilidad sin '
              'cambiar el comentario ni la puntuación.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_panel == null)
              const Expanded(
                child: Center(child: Text('Firebase no está inicializado.')),
              )
            else
              Expanded(
                child: StreamBuilder<PanelResenasAdmin>(
                  stream: _panel,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error al consultar reseñas: ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final panel = snapshot.data!;
                    final deportes = panel.deportes.toList()
                      ..sort((a, b) => a.nombre.compareTo(b.nombre));
                    final codigos = deportes.map((d) => d.codigo).toSet();
                    final seleccionado =
                        _seleccionado != null && codigos.contains(_seleccionado)
                        ? _seleccionado!
                        : _todos;
                    final consulta = normalizarTextoAdministrativo(
                      _busqueda.text,
                    );
                    final resenas = panel.resenas.where((r) {
                      if (seleccionado != _todos &&
                          r.deporte.codigo != seleccionado) {
                        return false;
                      }
                      if (_soloOcultas && !r.resena.oculta) return false;
                      return normalizarTextoAdministrativo(
                        '${r.resena.estudianteNombre} '
                        '${r.resena.comentario} '
                        '${r.deporte.nombre} ${r.deporte.codigo}',
                      ).contains(consulta);
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButton<String>(
                          key: const Key('selector-deporte-resenas'),
                          value: seleccionado,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: _todos,
                              child: Text('Todos los deportes'),
                            ),
                            for (final deporte in deportes)
                              DropdownMenuItem(
                                value: deporte.codigo,
                                child: Text(deporte.nombre),
                              ),
                          ],
                          onChanged: (nuevo) => setState(
                            () =>
                                _seleccionado = nuevo == _todos ? null : nuevo,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('buscar-resena-admin'),
                          controller: _busqueda,
                          decoration: const InputDecoration(
                            labelText: 'Buscar deporte, autor o comentario',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        SwitchListTile.adaptive(
                          title: const Text('Solo reseñas ocultas'),
                          contentPadding: EdgeInsets.zero,
                          value: _soloOcultas,
                          onChanged: (valor) =>
                              setState(() => _soloOcultas = valor),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${resenas.length} reseña(s) encontradas',
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: resenas.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No hay reseñas que coincidan con los filtros.',
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: resenas.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, indice) {
                                    final item = resenas[indice];
                                    final deporte = item.deporte;
                                    final resena = item.resena;
                                    final clave =
                                        '${deporte.codigo}/${resena.estudianteUid}';
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Chip(
                                                  key: Key(
                                                    'deporte-resena-$clave',
                                                  ),
                                                  avatar: const Icon(
                                                    Icons
                                                        .sports_soccer_outlined,
                                                    size: 18,
                                                  ),
                                                  label: Text(deporte.nombre),
                                                ),
                                                Chip(
                                                  label: Text(deporte.codigo),
                                                ),
                                                Chip(
                                                  label: Text(
                                                    resena.oculta
                                                        ? 'Oculta'
                                                        : 'Visible',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              resena.estudianteNombre,
                                              style: tema.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${resena.puntuacion}/5 estrellas',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              resena.comentario.isEmpty
                                                  ? 'Sin comentario'
                                                  : resena.comentario,
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: OutlinedButton.icon(
                                                key: Key(
                                                  seleccionado == _todos
                                                      ? 'visibilidad-${deporte.codigo}-${resena.estudianteUid}'
                                                      : 'visibilidad-${resena.estudianteUid}',
                                                ),
                                                onPressed:
                                                    _guardando.contains(clave)
                                                    ? null
                                                    : () => _cambiarVisibilidad(
                                                        deporte.codigo,
                                                        resena,
                                                      ),
                                                icon: Icon(
                                                  resena.oculta
                                                      ? Icons
                                                            .visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                ),
                                                label: Text(
                                                  resena.oculta
                                                      ? 'Mostrar'
                                                      : 'Ocultar',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

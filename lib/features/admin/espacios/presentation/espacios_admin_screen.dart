import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/features/admin/espacios/data/firestore_espacio_repository.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';

/// Catálogo físico usado tanto por las clases como por futuras reservas.
class EspaciosAdminScreen extends StatefulWidget {
  const EspaciosAdminScreen({super.key, this.repositorio});

  final EspacioRepository? repositorio;

  @override
  State<EspaciosAdminScreen> createState() => _EspaciosAdminScreenState();
}

class _EspaciosAdminScreenState extends State<EspaciosAdminScreen> {
  late final EspacioRepository? _repositorio;
  late final Stream<List<EspacioDeportivo>>? _espacios;
  final _busqueda = TextEditingController();
  bool _mostrarInactivos = true;

  @override
  void initState() {
    super.initState();
    _repositorio =
        widget.repositorio ??
        (Firebase.apps.isEmpty ? null : FirestoreEspacioRepository());
    _espacios = _repositorio?.observarTodos();
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

  Future<void> _formulario([EspacioDeportivo? espacio]) async {
    final repo = _repositorio;
    if (repo == null) return;
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioEspacio(repositorio: repo, inicial: espacio),
    );
    if (!mounted || guardado != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          espacio == null
              ? 'Espacio registrado correctamente.'
              : 'Espacio actualizado correctamente.',
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(EspacioDeportivo espacio) async {
    final repo = _repositorio;
    if (repo == null) return;
    if (espacio.activo) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Desactivar espacio'),
          content: Text(
            '¿Desactivar ${espacio.nombre}? No se borrarán sus '
            'horarios ni sus reservas existentes.',
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
      await repo.cambiarEstado(espacio.id, activo: !espacio.activo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            espacio.activo ? 'Espacio desactivado.' : 'Espacio activado.',
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Espacios deportivos')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Instalaciones disponibles para clases y reservas.'),
                FilledButton.icon(
                  key: const Key('nuevo-espacio'),
                  onPressed: _repositorio == null ? null : () => _formulario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo espacio'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _busqueda,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o tipo',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('Mostrar espacios inactivos'),
              contentPadding: EdgeInsets.zero,
              value: _mostrarInactivos,
              onChanged: (v) => setState(() => _mostrarInactivos = v),
            ),
            Expanded(
              child: _espacios == null
                  ? const Center(child: Text('Firebase no está inicializado.'))
                  : StreamBuilder<List<EspacioDeportivo>>(
                      stream: _espacios,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al consultar espacios: '
                              '${snapshot.error}',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final filtro = normalizarBusqueda(
                          _busqueda.text.trim(),
                        );
                        final resultado =
                            snapshot.data!
                                .where((e) => _mostrarInactivos || e.activo)
                                .where(
                                  (e) =>
                                      normalizarBusqueda(e.nombre)
                                          .contains(filtro) ||
                                      normalizarBusqueda(e.tipo)
                                          .contains(filtro),
                                )
                                .toList()
                              ..sort((a, b) => a.nombre.compareTo(b.nombre));
                        if (resultado.isEmpty) {
                          return const Center(
                            child: Text('No hay espacios con ese criterio.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: resultado.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final espacio = resultado[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          espacio.nombre,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Chip(label: Text(espacio.tipo)),
                                        Chip(
                                          label: Text(
                                            espacio.activo
                                                ? 'Activo'
                                                : 'Inactivo',
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (espacio.descripcion.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(espacio.descripcion),
                                      ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          key: Key(
                                            'editar-espacio-${espacio.id}',
                                          ),
                                          onPressed: () => _formulario(espacio),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Editar'),
                                        ),
                                        OutlinedButton.icon(
                                          key: Key(
                                            'estado-espacio-${espacio.id}',
                                          ),
                                          onPressed: () =>
                                              _cambiarEstado(espacio),
                                          icon: Icon(
                                            espacio.activo
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          label: Text(
                                            espacio.activo
                                                ? 'Desactivar'
                                                : 'Activar',
                                          ),
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
      ),
    );
  }
}

class _FormularioEspacio extends StatefulWidget {
  const _FormularioEspacio({required this.repositorio, this.inicial});

  final EspacioRepository repositorio;
  final EspacioDeportivo? inicial;

  @override
  State<_FormularioEspacio> createState() => _FormularioEspacioState();
}

class _FormularioEspacioState extends State<_FormularioEspacio> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _tipo;
  late final TextEditingController _descripcion;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.inicial?.nombre ?? '');
    _tipo = TextEditingController(text: widget.inicial?.tipo ?? '');
    _descripcion = TextEditingController(
      text: widget.inicial?.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _tipo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actual = widget.inicial;
      if (actual == null) {
        await widget.repositorio.crear(
          nombre: _nombre.text,
          tipo: _tipo.text,
          descripcion: _descripcion.text,
        );
      } else {
        await widget.repositorio.actualizar(
          actual.copyWith(
            nombre: _nombre.text,
            tipo: _tipo.text,
            descripcion: _descripcion.text,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.inicial == null ? 'Nuevo espacio' : 'Editar espacio'),
    content: SizedBox(
      width: 450,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('nombre-espacio'),
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                maxLength: 100,
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Escribe un nombre de al menos 3 caracteres.'
                    : null,
              ),
              TextFormField(
                controller: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de instalación',
                ),
                maxLength: 60,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Indica el tipo de instalación.'
                    : null,
              ),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
                maxLength: 500,
                maxLines: 3,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('guardar-espacio'),
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}

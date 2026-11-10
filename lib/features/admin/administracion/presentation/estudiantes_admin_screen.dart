import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/features/admin/administracion/data/estudiantes_admin_repository.dart';
import 'package:saman_deportivo/features/admin/administracion/domain/filtro_administrativo.dart';

class EstudiantesAdminScreen extends StatefulWidget {
  const EstudiantesAdminScreen({super.key, this.repositorio});

  final EstudiantesAdminRepository? repositorio;

  @override
  State<EstudiantesAdminScreen> createState() => _EstudiantesAdminScreenState();
}

class _EstudiantesAdminScreenState extends State<EstudiantesAdminScreen> {
  late final EstudiantesAdminRepository? _repositorio;
  late final Stream<List<Estudiante>>? _estudiantes;
  final _busqueda = TextEditingController();
  final _guardando = <String>{};
  bool _soloInactivos = false;

  @override
  void initState() {
    super.initState();
    _repositorio =
        widget.repositorio ??
        (Firebase.apps.isEmpty ? null : FirestoreEstudiantesAdminRepository());
    _estudiantes = _repositorio?.observarEstudiantes();
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

  Future<void> _cambiarEstado(Estudiante estudiante) async {
    final repo = _repositorio;
    if (repo == null || _guardando.contains(estudiante.uid)) return;
    final nuevo = estudiante.estaActivo
        ? EstadoEstudiante.inactivo
        : EstadoEstudiante.activo;
    final accion = nuevo == EstadoEstudiante.inactivo
        ? 'Desactivar'
        : 'Activar';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$accion estudiante'),
        content: Text(
          '¿Confirmas que deseas ${accion.toLowerCase()} a '
          '${estudiante.nombre}? Esta acción cambia su estado administrativo, '
          'pero no elimina sus inscripciones ni su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-estado-estudiante'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    setState(() => _guardando.add(estudiante.uid));
    try {
      await repo.cambiarEstado(estudiante.uid, nuevo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado de ${estudiante.nombre} actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando.remove(estudiante.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Administración de estudiantes')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estudiantes', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Consulta su estado administrativo. La solvencia institucional '
              'requiere una verificación independiente.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('buscar-estudiante-admin'),
              controller: _busqueda,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nombre, cédula o carnet',
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('Mostrar solamente inactivos'),
              contentPadding: EdgeInsets.zero,
              value: _soloInactivos,
              onChanged: (valor) => setState(() => _soloInactivos = valor),
            ),
            Expanded(
              child: _estudiantes == null
                  ? const Center(child: Text('Firebase no está inicializado.'))
                  : StreamBuilder<List<Estudiante>>(
                      stream: _estudiantes,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al consultar estudiantes: ${snapshot.error}',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final consulta = normalizarTextoAdministrativo(
                          _busqueda.text,
                        );
                        final estudiantes =
                            snapshot.data!
                                .where((e) => !_soloInactivos || !e.estaActivo)
                                .where(
                                  (e) => normalizarTextoAdministrativo(
                                    '${e.nombre} ${e.cedula} ${e.carnet}',
                                  ).contains(consulta),
                                )
                                .toList()
                              ..sort((a, b) => a.nombre.compareTo(b.nombre));
                        if (estudiantes.isEmpty) {
                          return const Center(
                            child: Text(
                              'No hay estudiantes que coincidan con los filtros.',
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: estudiantes.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, indice) {
                            final e = estudiantes[indice];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            e.nombre,
                                            style: tema.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cédula: ${e.cedula} · Carnet: ${e.carnet}',
                                          ),
                                          Text(
                                            e.correo,
                                            style: tema.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        e.estaActivo ? 'Activo' : 'Inactivo',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      key: Key('estado-estudiante-${e.uid}'),
                                      onPressed: _guardando.contains(e.uid)
                                          ? null
                                          : () => _cambiarEstado(e),
                                      icon: Icon(
                                        e.estaActivo
                                            ? Icons.person_off_outlined
                                            : Icons.person_add_alt_outlined,
                                      ),
                                      label: Text(
                                        e.estaActivo ? 'Desactivar' : 'Activar',
                                      ),
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

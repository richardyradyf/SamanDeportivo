import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/entrenador_repository.dart';
import 'package:saman_deportivo/features/admin/entrenadores/data/firestore_entrenador_repository.dart';
import 'package:saman_deportivo/models/entrenador.dart';

/// Directorio administrativo de entrenadores existentes.
///
/// No crea usuarios de Firebase Authentication desde el cliente.
/// La provisión de cuentas requiere un backend con privilegios y auditoría.
class EntrenadoresAdminScreen extends StatefulWidget {
  const EntrenadoresAdminScreen({super.key, this.repositorio});

  final EntrenadorRepository? repositorio;

  @override
  State<EntrenadoresAdminScreen> createState() =>
      _EntrenadoresAdminScreenState();
}

class _EntrenadoresAdminScreenState extends State<EntrenadoresAdminScreen> {
  final _busqueda = TextEditingController();
  late final Stream<List<Entrenador>>? _entrenadores;

  @override
  void initState() {
    super.initState();
    final repositorio =
        widget.repositorio ??
        (Firebase.apps.isNotEmpty ? FirestoreEntrenadorRepository() : null);
    _entrenadores = repositorio?.observarEntrenadores();
    _busqueda.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _busqueda.removeListener(_refrescar);
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entrenadores', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Consulta las cuentas existentes y su especialidad.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('buscar-entrenador'),
            controller: _busqueda,
            decoration: const InputDecoration(
              labelText: 'Buscar entrenador o especialidad',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _entrenadores == null
                ? const Center(child: Text('Firebase no está inicializado.'))
                : StreamBuilder<List<Entrenador>>(
                    stream: _entrenadores,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'No se pudieron cargar los entrenadores: ${snapshot.error}',
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
                                (e) =>
                                    normalizarBusqueda(e.nombre)
                                        .contains(termino) ||
                                    normalizarBusqueda(e.especialidad)
                                        .contains(termino) ||
                                    normalizarBusqueda(e.correo)
                                        .contains(termino),
                              )
                              .toList()
                            ..sort((a, b) => a.nombre.compareTo(b.nombre));
                      if (resultado.isEmpty) {
                        return const Center(
                          child: Text('No se encontraron entrenadores.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: resultado.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entrenador = resultado[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      entrenador.nombre.isNotEmpty
                                          ? entrenador.nombre[0].toUpperCase()
                                          : 'E',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entrenador.nombre,
                                          style: tema.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(entrenador.especialidad),
                                        Text(
                                          '${entrenador.aniosExperiencia} años de experiencia',
                                          style: tema.textTheme.bodySmall,
                                        ),
                                        Text(
                                          entrenador.correo,
                                          style: tema.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
    );
  }
}

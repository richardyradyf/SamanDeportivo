import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';

import '../data/firestore_perfil_repository.dart';
import '../data/perfil_repository.dart';
import '../domain/perfil_usuario.dart';

/// Contenido de perfil. El menú y el AuthGate son responsabilidad de Gabriel.
/// Montar este widget como página dentro del shell de navegación del rol.
class PerfilScreen extends StatefulWidget {
  PerfilScreen({
    super.key,
    PerfilRepository? repository,
    String? uid,
    Future<void> Function()? cerrarSesion,
  }) : repository = repository ?? FirestorePerfilRepository(),
       obtenerUid = (() => uid ?? FirebaseAuth.instance.currentUser?.uid),
       cerrarSesion = cerrarSesion ?? (() => FirebaseAuth.instance.signOut());

  final PerfilRepository repository;
  final String? Function() obtenerUid;
  final Future<void> Function() cerrarSesion;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _procesando = false;

  Future<void> _editar(PerfilUsuario perfil) async {
    final nombre = TextEditingController(text: perfil.nombre);
    final carnet = TextEditingController(text: perfil.carnet ?? '');
    final formKey = GlobalKey<FormState>();
    final cambio = await showDialog<({String nombre, String? carnet})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mi perfil'),
        content: Form(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  validator: (s) => s == null || s.trim().length < 2
                      ? 'Escribe un nombre válido'
                      : null,
                ),
                if (perfil.rol == RolPerfil.estudiante)
                  TextFormField(
                    controller: carnet,
                    decoration: const InputDecoration(labelText: 'Carnet'),
                    maxLength: 24,
                    validator: (s) =>
                        s == null ||
                            !RegExp(r'^[a-zA-Z0-9-]{4,24}$').hasMatch(s.trim())
                        ? 'Usa 4–24 letras, números o guiones'
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, (
                  nombre: nombre.text.trim(),
                  carnet: perfil.rol == RolPerfil.estudiante
                      ? carnet.text.trim()
                      : null,
                ));
              }
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
    // El diálogo ya terminó de usar sus controladores.
    // Se difiere el dispose al siguiente frame para evitar carreras con pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombre.dispose();
      carnet.dispose();
    });
    if (!mounted || cambio == null) return;
    setState(() => _procesando = true);
    try {
      await widget.repository.actualizarPerfil(
        uid: perfil.uid,
        nombre: cambio.nombre,
        carnet: cambio.carnet,
      );
      if (mounted) _mensaje('Perfil actualizado correctamente');
    } catch (error) {
      if (mounted) _mensaje('No se pudieron guardar los cambios: $error');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _salir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    setState(() => _procesando = true);
    try {
      await widget.cerrarSesion();
      // La redirección pertenece al AuthGate de Gabriel (authStateChanges).
    } catch (error) {
      if (mounted) _mensaje('No se pudo cerrar la sesión: $error');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.obtenerUid();
    if (uid == null) {
      return const Center(child: Text('Inicia sesión para ver tu perfil.'));
    }
    return StreamBuilder<PerfilUsuario?>(
      stream: widget.repository.observarPerfil(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar el perfil: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final perfil = snapshot.data;
        if (perfil == null) {
          return const Center(
            child: Text('No encontramos un perfil asociado a esta cuenta.'),
          );
        }
        return ColoredBox(
          color: AppColors.fondo,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1030),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final titulo = Text(
                          'Mi perfil',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize:
                                    34, // Tamano exacto en Figma, pantalla 13.
                                fontWeight: FontWeight.w700,
                              ),
                        );
                        // Con anchos intermedios, poner el titulo y los botones
                        // en la misma fila provoca un RenderFlex overflow.
                        if (constraints.maxWidth < 900) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titulo,
                              const SizedBox(height: 14),
                              _acciones(perfil),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: titulo),
                            const SizedBox(width: 16),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _acciones(perfil),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppColors.suave,
                          child: Text(
                            perfil.iniciales,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.primario,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                perfil.nombre,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                perfil.rol == RolPerfil.estudiante
                                    ? 'Estudiante ${perfil.estado ?? 'sin validar'}'
                                    : perfil.nombreRol,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.primario,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 38),
                    _seccion('INFORMACIÓN PERSONAL', [
                      _Dato('Nombre', perfil.nombre),
                      _Dato('Correo', perfil.correo),
                      _Dato('Cédula', perfil.cedula),
                    ]),
                    const SizedBox(height: 30),
                    if (perfil.rol == RolPerfil.estudiante)
                      _seccion('INFORMACIÓN ACADÉMICA', [
                        _Dato('Carnet', perfil.carnet ?? 'Sin asignar'),
                        _Dato('Estado', perfil.estado ?? 'Sin validar'),
                      ]),
                    if (perfil.rol == RolPerfil.entrenador)
                      _seccion('INFORMACIÓN DEL ENTRENADOR', [
                        _Dato(
                          'Especialidad',
                          perfil.especialidad ?? 'Sin asignar',
                        ),
                        _Dato(
                          'Años de experiencia',
                          perfil.aniosExperiencia?.toString() ?? 'Sin asignar',
                        ),
                      ]),
                    if (perfil.rol == RolPerfil.administrador)
                      _seccion('PERMISOS DE USUARIO', [
                        const _Dato('Rol', 'Administrador'),
                      ]),
                    if (_procesando) ...[
                      const SizedBox(height: 22),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _acciones(PerfilUsuario perfil) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _procesando ? null : () => _editar(perfil),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar perfil'),
        ),
        TextButton.icon(
          onPressed: _procesando ? null : _salir,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }

  Widget _seccion(String titulo, List<_Dato> datos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border.all(color: AppColors.borde),
        borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 24,
              runSpacing: 30,
              children: datos
                  .map(
                    (dato) => SizedBox(
                      width: constraints.maxWidth < 260
                          ? constraints.maxWidth
                          : 260.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dato.etiqueta,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            dato.valor,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato {
  const _Dato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;
}

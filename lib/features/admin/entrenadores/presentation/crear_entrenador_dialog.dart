import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Crea la cuenta con una segunda app de Firebase, preservando la sesión
/// del administrador. El servidor de Auth envía la recuperación de contraseña.
class CrearEntrenadorDialog extends StatefulWidget {
  const CrearEntrenadorDialog({super.key, required this.crear});

  final Future<String?> Function({
    required String nombre,
    required String correo,
    required String cedula,
    required String especialidad,
    required int aniosExperiencia,
  })
  crear;

  @override
  State<CrearEntrenadorDialog> createState() => _CrearEntrenadorDialogState();
}

class _CrearEntrenadorDialogState extends State<CrearEntrenadorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _cedula = TextEditingController();
  final _especialidad = TextEditingController();
  final _experiencia = TextEditingController(text: '0');
  String? _enlace;
  bool _creado = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _nombre,
      _correo,
      _cedula,
      _especialidad,
      _experiencia,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final enlace = await widget.crear(
        nombre: _nombre.text.trim(),
        correo: _correo.text.trim(),
        cedula: _cedula.text.trim(),
        especialidad: _especialidad.text.trim(),
        aniosExperiencia: int.parse(_experiencia.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _creado = true;
        _enlace = enlace;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_creado ? 'Entrenador creado' : 'Nuevo entrenador'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: _creado
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cuenta creada. Se solicitó el envío de un correo para establecer la contraseña. Si no llega, utiliza «Reenviar invitación» o «Recuperar contraseña».',
                    ),
                    if (_enlace != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        _enlace!,
                        key: const Key('enlace-invitacion'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _enlace!)),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar invitación'),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'No se muestra un enlace de invitación al administrador. Si el correo no llega, usa «Reenviar invitación» o «Recuperar contraseña».',
                        ),
                      ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        key: const Key('entrenador-nombre'),
                        controller: _nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        validator: (v) => (v ?? '').trim().length >= 3
                            ? null
                            : 'Introduce un nombre válido.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('entrenador-correo'),
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        validator: (v) =>
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch((v ?? '').trim())
                            ? null
                            : 'Correo inválido.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('entrenador-cedula'),
                        controller: _cedula,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: 'Cédula'),
                        validator: (v) =>
                            RegExp(r'^\d{5,20}$').hasMatch((v ?? '').trim())
                            ? null
                            : 'Cédula inválida.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('entrenador-especialidad'),
                        controller: _especialidad,
                        decoration: const InputDecoration(
                          labelText: 'Especialidad',
                        ),
                        validator: (v) => (v ?? '').trim().length >= 2
                            ? null
                            : 'Introduce una especialidad.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('entrenador-experiencia'),
                        controller: _experiencia,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Años de experiencia',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n != null && n >= 0 && n <= 60
                              ? null
                              : 'Introduce entre 0 y 60 años.';
                        },
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: Text(_creado ? 'Cerrar' : 'Cancelar'),
        ),
        if (!_creado)
          FilledButton(
            key: const Key('crear-entrenador-guardar'),
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Creando...' : 'Crear entrenador'),
          ),
      ],
    );
  }
}

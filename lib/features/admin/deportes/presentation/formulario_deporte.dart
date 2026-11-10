import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Formulario administrativo de A1.
/// La asignación de entrenadores y edición de horarios se integran en A2.
/// En edición, esos datos se conservan sin modificarlos.
class FormularioDeporte extends StatefulWidget {
  const FormularioDeporte({super.key, this.inicial, required this.guardar});

  final Deporte? inicial;
  final Future<void> Function(Deporte deporte) guardar;

  @override
  State<FormularioDeporte> createState() => _FormularioDeporteState();
}

class _FormularioDeporteState extends State<FormularioDeporte> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigo;
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _costo;
  late final TextEditingController _cupo;
  late Disciplina _disciplina;
  late bool _activo;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.inicial != null;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    _codigo = TextEditingController(text: inicial?.codigo ?? '');
    _nombre = TextEditingController(text: inicial?.nombre ?? '');
    _descripcion = TextEditingController(text: inicial?.descripcion ?? '');
    _costo = TextEditingController(text: inicial?.costo.toString() ?? '0');
    _cupo = TextEditingController(text: inicial?.cupoMaximo.toString() ?? '');
    _disciplina = inicial?.disciplina ?? Disciplina.colectivo;
    _activo = inicial?.activo ?? true;
  }

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _descripcion.dispose();
    _costo.dispose();
    _cupo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    final inicial = widget.inicial;
    final costo = double.parse(_costo.text.trim().replaceAll(',', '.'));
    final cupo = int.parse(_cupo.text.trim());
    final Deporte deporte;
    if (inicial == null) {
      deporte = Deporte(
        codigo: _codigo.text.trim().toUpperCase(),
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        disciplina: _disciplina,
        costo: costo,
        cupoMaximo: cupo,
        creadoEn: DateTime.now(),
        activo: _activo,
      );
    } else {
      deporte = inicial.copyWith(
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        disciplina: _disciplina,
        costo: costo,
        cupoMaximo: cupo,
        activo: _activo,
      );
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.guardar(deporte);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _editando ? 'Editar deporte' : 'Crear deporte',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('campo-codigo'),
                  controller: _codigo,
                  enabled: !_editando && !_guardando,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código (ej.: FUT-01)',
                  ),
                  validator: (valor) =>
                      Deporte.formatoCodigo.hasMatch(
                        (valor ?? '').trim().toUpperCase(),
                      )
                      ? null
                      : 'Introduce tres letras, guion y dos números (FUT-01).',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('campo-nombre'),
                  controller: _nombre,
                  enabled: !_guardando,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del deporte',
                  ),
                  validator: (valor) {
                    final largo = (valor ?? '').trim().length;
                    return largo >= 3 && largo <= 100
                        ? null
                        : 'El nombre debe tener entre 3 y 100 caracteres.';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcion,
                  enabled: !_guardando,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Disciplina>(
                  initialValue: _disciplina,
                  decoration: const InputDecoration(labelText: 'Disciplina'),
                  items: [
                    for (final d in Disciplina.values)
                      DropdownMenuItem(value: d, child: Text(d.etiqueta)),
                  ],
                  onChanged: _guardando
                      ? null
                      : (valor) {
                          if (valor != null) {
                            setState(() => _disciplina = valor);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('campo-costo'),
                  controller: _costo,
                  enabled: !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo de reserva (USD)',
                  ),
                  validator: (valor) {
                    final numero = double.tryParse(
                      (valor ?? '').trim().replaceAll(',', '.'),
                    );
                    return numero != null && numero.isFinite && numero >= 0
                        ? null
                        : 'Introduce un costo válido, mayor o igual que cero.';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('campo-cupo'),
                  controller: _cupo,
                  enabled: !_guardando,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cupo máximo'),
                  validator: (valor) {
                    final numero = int.tryParse((valor ?? '').trim());
                    if (numero == null || numero <= 0) {
                      return 'El cupo debe ser un entero mayor que cero.';
                    }
                    if (numero < (widget.inicial?.cuposOcupados ?? 0)) {
                      return 'No puede ser menor que los cupos ocupados.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deporte activo'),
                  value: _activo,
                  onChanged: _guardando
                      ? null
                      : (valor) => setState(() => _activo = valor),
                ),
                if (_editando)
                  const Text(
                    'Entrenador y horarios se gestionarán en el módulo A2.',
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      key: const Key('guardar-deporte'),
                      onPressed: _guardando ? null : _enviar,
                      child: Text(
                        _guardando ? 'Guardando…' : 'Guardar deporte',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

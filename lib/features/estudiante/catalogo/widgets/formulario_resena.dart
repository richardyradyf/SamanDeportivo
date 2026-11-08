import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/widgets/estrellas.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Formulario para calificar un deporte de 1 a 5 y dejar un comentario
/// (RF-17). Si el estudiante ya calificó, llega con su reseña cargada y
/// guardar la reemplaza.
class FormularioResena extends StatefulWidget {
  const FormularioResena({super.key, required this.onGuardar, this.inicial});

  /// Guarda la reseña. Si lanza un error, el formulario lo muestra.
  final Future<void> Function(int puntuacion, String comentario) onGuardar;

  /// Reseña que el estudiante ya había dejado, si existe.
  final Resena? inicial;

  @override
  State<FormularioResena> createState() => _FormularioResenaState();
}

class _FormularioResenaState extends State<FormularioResena> {
  final _comentario = TextEditingController();
  int _puntuacion = 0;
  bool _guardando = false;
  bool _editado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar(widget.inicial);
  }

  @override
  void didUpdateWidget(FormularioResena oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La reseña propia llega por el stream un poco después de abrir la
    // pantalla. Se carga solo si el estudiante no ha empezado a escribir.
    if (!_editado && oldWidget.inicial?.fecha != widget.inicial?.fecha) {
      _cargar(widget.inicial);
    }
  }

  void _cargar(Resena? resena) {
    _puntuacion = resena?.puntuacion ?? 0;
    _comentario.text = resena?.comentario ?? '';
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_puntuacion < 1) {
      setState(() => _error = 'Elige de 1 a 5 estrellas.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.onGuardar(_puntuacion, _comentario.text.trim());
      if (!mounted) return;
      _editado = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gracias por tu reseña.')));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'No se pudo guardar tu reseña. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yaCalifico = widget.inicial != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          yaCalifico ? 'Tu reseña' : 'Califica este deporte',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        SelectorEstrellas(
          valor: _puntuacion,
          onCambio: (valor) => setState(() {
            _puntuacion = valor;
            _editado = true;
            _error = null;
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('comentarioResena'),
          controller: _comentario,
          onChanged: (_) => _editado = true,
          maxLength: Resena.maxComentario,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            hintText: '¿Qué te pareció el entrenamiento?',
          ),
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(yaCalifico ? 'Actualizar reseña' : 'Publicar reseña'),
        ),
      ],
    );
  }
}

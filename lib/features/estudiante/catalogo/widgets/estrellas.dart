import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';

/// Cinco estrellas para mostrar una calificación de 1 a 5 (RF-17).
/// Acepta medias estrellas: 4,5 muestra cuatro llenas y una a la mitad.
class Estrellas extends StatelessWidget {
  const Estrellas({super.key, required this.valor, this.tamano = 18});

  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${valor.toStringAsFixed(1)} de 5 estrellas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                valor >= i
                    ? Icons.star
                    : valor >= i - 0.5
                    ? Icons.star_half
                    : Icons.star_border,
                size: tamano,
                color: AppColors.advertencia,
              ),
          ],
        ),
      ),
    );
  }
}

/// Estrellas que se pueden tocar para elegir la calificación.
class SelectorEstrellas extends StatelessWidget {
  const SelectorEstrellas({
    super.key,
    required this.valor,
    required this.onCambio,
  });

  /// Estrellas elegidas; 0 si todavía no se ha elegido.
  final int valor;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: i == 1 ? '1 estrella' : '$i estrellas',
            onPressed: () => onCambio(i),
            icon: Icon(
              i <= valor ? Icons.star : Icons.star_border,
              size: 32,
              color: AppColors.advertencia,
            ),
          ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/widgets/tarjeta_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Tarjetas de deportes en columnas que se ajustan al ancho: una en
/// celular, dos o tres en tablet y computadora. La usan el catálogo y el
/// landing.
class CuadriculaDeportes extends StatelessWidget {
  const CuadriculaDeportes({
    super.key,
    required this.deportes,
    this.onVerDeporte,
  });

  final List<Deporte> deportes;
  final void Function(Deporte deporte)? onVerDeporte;

  static const double anchoMinimo = 260;
  static const double espacio = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = math.max(
          1,
          ((ancho + espacio) / (anchoMinimo + espacio)).floor(),
        );
        final anchoTarjeta = (ancho - espacio * (columnas - 1)) / columnas;
        final abrir = onVerDeporte;

        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final deporte in deportes)
              SizedBox(
                width: anchoTarjeta,
                child: TarjetaDeporte(
                  key: ValueKey(deporte.codigo),
                  deporte: deporte,
                  onVer: abrir == null ? null : () => abrir(deporte),
                ),
              ),
          ],
        );
      },
    );
  }
}

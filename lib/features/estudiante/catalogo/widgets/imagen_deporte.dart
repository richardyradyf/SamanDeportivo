import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/widgets/tarjeta_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Imagen de un deporte, liviana (Hito 4, rendimiento).
///
/// - Se decodifica al tamaño en que se muestra ([cacheWidth]), no al tamaño
///   original de la foto: una foto de 4000 px en una tarjeta de 300 px gasta
///   memoria y tiempo sin que se note la diferencia.
/// - Mientras carga, o si no carga, se ve el verde de la marca con el ícono
///   de la disciplina, así la pantalla nunca queda vacía.
class ImagenDeporte extends StatelessWidget {
  const ImagenDeporte({
    super.key,
    required this.deporte,
    this.tamanoIcono = 40,
  });

  final Deporte deporte;
  final double tamanoIcono;

  /// Ancho en píxeles al que se decodifica la imagen: el ancho en pantalla
  /// por la densidad del dispositivo, con un máximo para pantallas enormes.
  static int anchoDecodificado(double anchoLogico, double densidad) {
    const maximo = 1600;
    final ancho = (anchoLogico * densidad).round();
    return ancho.clamp(1, maximo);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final respaldo = ColoredBox(
      color: colores.secondary,
      child: Center(
        child: Icon(
          TarjetaDeporte.iconoDe(deporte.disciplina),
          size: tamanoIcono,
          color: colores.onSecondary,
        ),
      ),
    );

    final url = deporte.imagenUrl;
    if (url == null || url.isEmpty) return respaldo;

    return LayoutBuilder(
      builder: (context, constraints) {
        final densidad = MediaQuery.devicePixelRatioOf(context);
        final ancho = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: anchoDecodificado(ancho, densidad),
          // Hasta que llega el primer cuadro de la imagen se ve el respaldo.
          frameBuilder: (_, imagen, cuadro, sincronica) =>
              sincronica || cuadro != null ? imagen : respaldo,
          errorBuilder: (_, _, _) => respaldo,
        );
      },
    );
  }
}

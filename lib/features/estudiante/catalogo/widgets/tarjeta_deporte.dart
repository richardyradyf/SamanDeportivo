import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/etiqueta_cupos.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/imagen_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Tarjeta de un deporte en el catálogo ("Card / Sport" del Figma).
///
/// Muestra lo que pide el RF-05: código, nombre, horario, entrenador y
/// cupos disponibles. Si se pasa [onVer], toda la tarjeta abre el detalle.
class TarjetaDeporte extends StatelessWidget {
  const TarjetaDeporte({super.key, required this.deporte, this.onVer});

  final Deporte deporte;
  final VoidCallback? onVer;

  static IconData iconoDe(Disciplina disciplina) {
    return switch (disciplina) {
      Disciplina.colectivo => Icons.groups,
      Disciplina.individual => Icons.directions_run,
      Disciplina.raqueta => Icons.sports_tennis,
      Disciplina.combate => Icons.sports_martial_arts,
      Disciplina.acuatico => Icons.pool,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final textoSecundario = tema.textTheme.bodySmall;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onVer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Portada(deporte: deporte),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deporte.codigo, style: tema.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    deporte.nombre.toUpperCase(),
                    style: tema.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _Dato(
                    icono: Icons.schedule,
                    texto: resumenHorarios(deporte.horarios),
                    estilo: textoSecundario,
                  ),
                  const SizedBox(height: 4),
                  _Dato(
                    icono: Icons.person_outline,
                    texto: deporte.entrenadorNombre ?? 'Entrenador por asignar',
                    estilo: textoSecundario,
                  ),
                  const SizedBox(height: 4),
                  _Dato(
                    icono: deporte.totalResenas > 0
                        ? Icons.star
                        : Icons.star_border,
                    texto: textoCalificacion(deporte),
                    estilo: textoSecundario,
                  ),
                  const SizedBox(height: 12),
                  EtiquetaCupos(deporte: deporte),
                  if (onVer != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Ver disciplina',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelLarge?.copyWith(
                              color: colores.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: colores.onSurface,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja superior de la tarjeta: la imagen del deporte o, si no tiene,
/// el verde de la marca con el ícono de la disciplina.
class _Portada extends StatelessWidget {
  const _Portada({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 96, child: ImagenDeporte(deporte: deporte));
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.estilo});

  final IconData icono;
  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: estilo?.color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: estilo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

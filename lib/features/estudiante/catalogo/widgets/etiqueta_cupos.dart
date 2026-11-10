import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Etiqueta con los cupos libres de un deporte. Se usa en la tarjeta del
/// catálogo y en el detalle. Los colores salen de AppColors.
class EtiquetaCupos extends StatelessWidget {
  const EtiquetaCupos({super.key, required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (EstadoCupos.de(deporte)) {
      EstadoCupos.disponible => (
        AppColors.disponibleFondo,
        AppColors.disponibleTexto,
      ),
      EstadoCupos.pocos => (AppColors.pocosCuposFondo, AppColors.pocosCuposTexto),
      EstadoCupos.completo => (AppColors.completoFondo, AppColors.completoTexto),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        textoCupos(deporte),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: texto),
      ),
    );
  }
}

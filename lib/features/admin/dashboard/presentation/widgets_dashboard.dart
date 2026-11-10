import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';
import 'package:saman_deportivo/models/enums.dart';

class TarjetaIndicador extends StatelessWidget {
  const TarjetaIndicador({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.id,
    this.aclaracion,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final String id;
  final String? aclaracion;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(valor, key: Key('a3-valor-$id'), style: estilo.headlineMedium),
            const SizedBox(height: 5),
            Text(etiqueta, style: estilo.bodyMedium),
            if (aclaracion != null) ...[
              const SizedBox(height: 5),
              Text(aclaracion!, style: estilo.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class CuadriculaIndicadores extends StatelessWidget {
  const CuadriculaIndicadores({super.key, required this.indicadores});

  final List<TarjetaIndicador> indicadores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimensiones) {
        final columnas = dimensiones.maxWidth >= 850
            ? 3
            : dimensiones.maxWidth >= 520
            ? 2
            : 1;
        final ancho = math.max(
          1.0,
          (dimensiones.maxWidth - (columnas - 1) * 12) / columnas,
        );
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final indicador in indicadores)
              SizedBox(width: ancho, child: indicador),
          ],
        );
      },
    );
  }
}

class OcupacionPorDeporte extends StatelessWidget {
  const OcupacionPorDeporte({super.key, required this.resumen});

  final ResumenDashboard resumen;

  @override
  Widget build(BuildContext context) {
    final deportes = resumen.ocupacionDeportes.take(6).toList();
    if (deportes.isEmpty) {
      return const Text('No hay deportes activos para comparar.');
    }
    final estiloEtiqueta = Theme.of(context).textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Porcentaje de cupos ocupados por deporte'),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 100,
              barTouchData: BarTouchData(enabled: true),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 25,
                    getTitlesWidget: (valor, meta) =>
                        Text('${valor.toInt()}%', style: estiloEtiqueta),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (valor, meta) {
                      final indice = valor.toInt();
                      if (indice < 0 || indice >= deportes.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          deportes[indice].codigo,
                          style: estiloEtiqueta,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < deportes.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: deportes[i].porcentaje,
                        color: AppColors.primario,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: AppColors.suave,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DistribucionDisciplinas extends StatelessWidget {
  const DistribucionDisciplinas({super.key, required this.resumen});

  final ResumenDashboard resumen;

  static const _colores = [
    AppColors.primario,
    AppColors.info,
    AppColors.advertencia,
    AppColors.primarioMas,
    AppColors.textoSecundario,
  ];

  @override
  Widget build(BuildContext context) {
    final entradas = resumen.porDisciplina.entries
        .where((entrada) => entrada.value > 0)
        .toList();
    if (entradas.isEmpty) {
      return const Text('No hay deportes activos para representar.');
    }
    final total = entradas.fold<int>(0, (anterior, e) => anterior + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 230,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              sections: [
                for (var i = 0; i < entradas.length; i++)
                  PieChartSectionData(
                    value: entradas[i].value.toDouble(),
                    title: '${(entradas[i].value * 100 / total).round()}%',
                    color: _colores[entradas[i].key.index % _colores.length],
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final e in entradas)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: _colores[e.key.index % _colores.length],
                  ),
                  const SizedBox(width: 5),
                  Text('${_nombreDisciplina(e.key)}: ${e.value}'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  String _nombreDisciplina(Disciplina d) => d.etiqueta;
}

class PanelAnalitico extends StatelessWidget {
  const PanelAnalitico({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

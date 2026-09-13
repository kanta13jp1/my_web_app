import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/resource_optimization.dart';

class HabitParetoChart extends StatelessWidget {
  const HabitParetoChart({super.key, required this.metrics});

  final List<HabitResourceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    final maxCost = metrics
        .map((metric) => metric.resourceCostIndex)
        .fold<double>(0, (current, value) => value > current ? value : current);
    final maxPerformance = metrics
        .map((metric) => metric.averageGoalContributionScore)
        .fold<double>(0, (current, value) => value > current ? value : current);
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: '習慣のコストと目標貢献度のパレート図',
      child: SizedBox(
        height: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 20, 8),
          child: ScatterChart(
            ScatterChartData(
              minX: 0,
              maxX: maxCost <= 0 ? 100 : maxCost * 1.15,
              minY: 0,
              maxY: maxPerformance <= 0
                  ? 100
                  : (maxPerformance * 1.15).clamp(20, 100),
              scatterSpots: metrics
                  .map(
                    (metric) => ScatterSpot(
                      metric.resourceCostIndex,
                      metric.averageGoalContributionScore,
                      dotPainter: FlDotCirclePainter(
                        radius: metric.isParetoOptimal ? 7 : 5,
                        color: metric.isParetoOptimal
                            ? const Color(0xFF168C5A)
                            : colors.outlineVariant,
                        strokeWidth: metric.isParetoOptimal ? 2 : 1,
                        strokeColor: colors.surface,
                      ),
                    ),
                  )
                  .toList(growable: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: colors.outlineVariant),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('目標貢献度'),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('リソースコスト'),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
  }
}

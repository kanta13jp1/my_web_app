import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/local_election_plan.dart';

class ElectionRegionalKpiChart extends StatelessWidget {
  final List<LocalElectionPrefecturePlan> prefectures;

  const ElectionRegionalKpiChart({
    super.key,
    required this.prefectures,
  });

  @override
  Widget build(BuildContext context) {
    if (prefectures.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '都道府県連別 目標配分 (現職維持 + 新人擁立)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(),
                  barTouchData: const BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < prefectures.length) {
                            final region =
                                prefectures[value.toInt()].prefecture;
                            final displayRegion = region.length > 3
                                ? region.substring(0, 2)
                                : region;
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                displayRegion,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return SideTitleWidget(
                              meta: meta, child: const SizedBox.shrink());
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: prefectures.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final retainTarget =
                        data.incumbentRetentionTarget.toDouble();
                    final newTarget = data.newCandidateTarget.toDouble();

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: retainTarget + newTarget,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                          rodStackItems: [
                            BarChartRodStackItem(
                                0, retainTarget, Colors.blue.shade300),
                            BarChartRodStackItem(
                                retainTarget,
                                retainTarget + newTarget,
                                Colors.orange.shade400),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.blue.shade300, '現職維持目標'),
                const SizedBox(width: 16),
                _buildLegend(Colors.orange.shade400, '新人擁立目標'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxY() {
    double max = 0;
    for (final data in prefectures) {
      final retain = data.incumbentRetentionTarget.toDouble();
      final newTarget = data.newCandidateTarget.toDouble();
      final total = retain + newTarget;
      if (total > max) {
        max = total;
      }
    }
    return max == 0 ? 10 : max * 1.2;
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/local_election_plan.dart';

class ElectionRegionalKpiChart extends StatefulWidget {
  final List<LocalElectionPrefecturePlan> prefectures;
  final GlobalKey? pieChartKey;

  const ElectionRegionalKpiChart({
    super.key,
    required this.prefectures,
    this.pieChartKey,
  });

  @override
  State<ElectionRegionalKpiChart> createState() => _ElectionRegionalKpiChartState();
}

class _ElectionRegionalKpiChartState extends State<ElectionRegionalKpiChart> {
  @override
  Widget build(BuildContext context) {
    if (widget.prefectures.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalRetain =
        widget.prefectures.fold<int>(0, (sum, p) => sum + p.incumbentRetentionTarget);
    final totalNew =
        widget.prefectures.fold<int>(0, (sum, p) => sum + p.newCandidateTarget);
    final totalTarget = totalRetain + totalNew;

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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('現職維持 合計', totalRetain.toString(), Colors.blue.shade700),
                      _buildSummaryItem('新人擁立 合計', totalNew.toString(), Colors.orange.shade700),
                      _buildSummaryItem('総合計', totalTarget.toString(), Colors.indigo.shade700),
                    ],
                  ),
                  if (totalTarget < 700) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '必達目標(700名)まで あと ${700 - totalTarget}名 不足しています',
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
                              value.toInt() < widget.prefectures.length) {
                            final region =
                                widget.prefectures[value.toInt()].prefecture;
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
                            meta: meta,
                            child: const SizedBox.shrink(),
                          );
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
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: widget.prefectures.asMap().entries.map((entry) {
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
                              0,
                              retainTarget,
                              Colors.blue.shade300,
                            ),
                            BarChartRodStackItem(
                              retainTarget,
                              retainTarget + newTarget,
                              Colors.orange.shade400,
                            ),
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
    for (final data in widget.prefectures) {
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

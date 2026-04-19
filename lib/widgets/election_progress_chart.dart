import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ElectionProgressChart extends StatelessWidget {
  final int currentTotal;
  final int shortfall;
  final int target;
  final String? caption;

  const ElectionProgressChart({
    super.key,
    required this.currentTotal,
    required this.shortfall,
    this.target = 700,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = currentTotal.toDouble();
    final shortfallValue = shortfall.toDouble();
    final targetValue = target.toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '党全体 必達目標（700名）への進捗',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFF1E88E5),
                      value: currentValue <= 0 ? 1 : currentValue,
                      title: '現在\n$currentTotal人',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.redAccent.shade400,
                      value: shortfallValue <= 0 ? 1 : shortfallValue,
                      title: '残り\n$shortfall人',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '目標: $target人 / 現在: $currentTotal人',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (caption != null && caption!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              targetValue > 0
                  ? '達成率 ${(currentTotal / targetValue * 100).toStringAsFixed(1)}%'
                  : '達成率 0%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

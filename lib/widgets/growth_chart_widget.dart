import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/growth_metrics.dart';

class GrowthChartWidget extends StatelessWidget {
  final List<GrowthMetrics> metrics;
  final String title;
  final String Function(GrowthMetrics) valueExtractor;
  final Color lineColor;

  const GrowthChartWidget({
    super.key,
    required this.metrics,
    required this.title,
    required this.valueExtractor,
    this.lineColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text('データがありません'),
          ),
        ),
      );
    }

    // Sort metrics by date
    final sortedMetrics = List<GrowthMetrics>.from(metrics)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Create data points
    final spots = sortedMetrics.asMap().entries.map((entry) {
      final index = entry.key;
      final metric = entry.value;
      final value = double.parse(valueExtractor(metric));
      return FlSpot(index.toDouble(), value);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 10 ? null : 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: sortedMetrics.length > 7
                            ? (sortedMetrics.length / 7).ceilToDouble()
                            : 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedMetrics.length) {
                            return const Text('');
                          }
                          final date = sortedMetrics[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY > 10 ? null : 1,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                      left: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  minX: 0,
                  maxX: (sortedMetrics.length - 1).toDouble(),
                  minY: minY > 0 ? 0 : minY,
                  maxY: maxY * 1.2, // Add 20% padding at top
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: lineColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index >= 0 && index < sortedMetrics.length) {
                            final metric = sortedMetrics[index];
                            final date = DateFormat('M/d').format(metric.date);
                            final value = barSpot.y.toInt();
                            return LineTooltipItem(
                              '$date\n$value',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

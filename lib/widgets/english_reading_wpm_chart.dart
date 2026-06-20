import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/english_reading_models.dart';
import '../services/english_reading_ability.dart';

/// 実効 WPM (= WPM × 理解率) と素の WPM の時系列推移チャート。
///
/// オレンジの太線が実効 WPM、薄い線が素の WPM。点線はネイティブ基準 (300 WPM)。
class EnglishReadingWpmChart extends StatelessWidget {
  const EnglishReadingWpmChart({super.key, required this.trend});

  final List<EnglishReadingTrendPoint> trend;

  static const Color _effectiveColor = Color(0xFFFF6B35);
  static const Color _rawColor = Color(0xFF7986CB);

  @override
  Widget build(BuildContext context) {
    if (trend.length < 2) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          trend.isEmpty
              ? 'まだ記録がありません。\n計測を1回行うと推移が表示されます。'
              : 'あと1回計測すると推移グラフが表示されます。',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 12,
            height: 1.7,
          ),
        ),
      );
    }

    final effSpots = <FlSpot>[];
    final rawSpots = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      effSpots.add(FlSpot(i.toDouble(), trend[i].effectiveWpm.toDouble()));
      rawSpots.add(FlSpot(i.toDouble(), trend[i].wpm.toDouble()));
    }

    final maxValue = [
      ...trend.map((t) => t.wpm),
      ...trend.map((t) => t.effectiveWpm),
      kNativeReadingWpm,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.15).ceilToDouble();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
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
                reservedSize: 28,
                interval:
                    trend.length > 6 ? (trend.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('M/d').format(trend[index].time),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB0B0B0),
                        height: 1.5,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFB0B0B0),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              left: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: kNativeReadingWpm.toDouble(),
                color: const Color(0xFFFFC107).withValues(alpha: 0.7),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  labelResolver: (_) => 'ネイティブ 300',
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: rawSpots,
              isCurved: true,
              color: _rawColor.withValues(alpha: 0.55),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: effSpots,
              isCurved: true,
              color: _effectiveColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: _effectiveColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _effectiveColor.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final index = barSpot.x.toInt();
                  if (index < 0 || index >= trend.length) return null;
                  final point = trend[index];
                  final isEffective = barSpot.barIndex == 1;
                  final label = isEffective ? '実効' : '素';
                  return LineTooltipItem(
                    '${DateFormat('M/d').format(point.time)}\n'
                    '$label ${barSpot.y.toInt()} WPM',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

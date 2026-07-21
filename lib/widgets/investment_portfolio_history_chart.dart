import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/investment_portfolio_history.dart';
import '../services/investment_portfolio_history_service.dart';

class InvestmentPortfolioHistoryChart extends StatelessWidget {
  const InvestmentPortfolioHistoryChart({
    super.key,
    required this.points,
    required this.period,
    required this.onPeriodChanged,
    this.currencyFormatter,
  });

  static const Color _marketColor = Color(0xFF2563EB);
  static const Color _costColor = Color(0xFF6B7280);

  final List<InvestmentPortfolioHistoryPoint> points;
  final InvestmentHistoryPeriod period;
  final ValueChanged<InvestmentHistoryPeriod> onPeriodChanged;
  final String Function(double value)? currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('investment_portfolio_history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '評価額の推移',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SegmentedButton<InvestmentHistoryPeriod>(
              key: const Key('investment_history_period_toggle'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: InvestmentHistoryPeriod.oneYear,
                  label: Text('1年'),
                ),
                ButtonSegment(
                  value: InvestmentHistoryPeriod.threeYears,
                  label: Text('3年'),
                ),
                ButtonSegment(
                  value: InvestmentHistoryPeriod.lifetime,
                  label: Text('全期間'),
                ),
              ],
              selected: {period},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onPeriodChanged(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (points.isEmpty)
          SizedBox(
            key: const Key('investment_history_empty'),
            height: 128,
            child: Center(
              child: Text(
                '選択期間の推移データはありません',
                style: theme.textTheme.bodySmall?.copyWith(color: _costColor),
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _Legend(color: _marketColor, label: '評価額'),
              _Legend(color: _costColor, label: '取得額', dashed: true),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            key: const Key('investment_history_chart'),
            height: 220,
            child: LineChart(_chartData(context)),
          ),
        ],
      ],
    );
  }

  LineChartData _chartData(BuildContext context) {
    final values = <double>[
      for (final point in points) ...[
        point.marketValueJpy,
        point.acquisitionCostJpy,
      ],
    ];
    final maxValue = values.reduce(math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.1;
    final lastIndex = points.length - 1;

    return LineChartData(
      minX: 0,
      maxX: math.max(1, lastIndex).toDouble(),
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 54,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                _compactYen(value),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: math.max(1, lastIndex / 4).toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  DateFormat('yy/M').format(points[index].recordedAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var index = 0; index < points.length; index++)
              FlSpot(index.toDouble(), points[index].marketValueJpy),
          ],
          color: _marketColor,
          barWidth: 3,
          isCurved: false,
          dotData: FlDotData(show: points.length <= 12),
          belowBarData: BarAreaData(
            show: true,
            color: _marketColor.withValues(alpha: 0.08),
          ),
        ),
        LineChartBarData(
          spots: [
            for (var index = 0; index < points.length; index++)
              FlSpot(index.toDouble(), points[index].acquisitionCostJpy),
          ],
          color: _costColor,
          barWidth: 2,
          isCurved: false,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((spot) {
            final index = spot.x.round();
            if (index < 0 || index >= points.length) return null;
            return LineTooltipItem(
              '${DateFormat('yyyy/M/d').format(points[index].recordedAt)}\n'
              '${spot.barIndex == 0 ? '評価額' : '取得額'} '
              '${_yen(spot.y)}',
              const TextStyle(color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _yen(double value) {
    final formatter = currencyFormatter;
    return formatter == null
        ? NumberFormat.currency(
            locale: 'ja_JP',
            symbol: '¥',
            decimalDigits: 0,
          ).format(value)
        : formatter(value);
  }

  String _compactYen(double value) {
    if (value.abs() >= 100000000) {
      return '¥${(value / 100000000).toStringAsFixed(1)}億';
    }
    if (value.abs() >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(0)}万';
    }
    return '¥${value.round()}';
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 2,
          child: dashed
              ? Row(
                  key: const Key('investment_history_dashed_legend'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var index = 0; index < 3; index++)
                      Container(width: 5, height: 2, color: color),
                  ],
                )
              : ColoredBox(color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

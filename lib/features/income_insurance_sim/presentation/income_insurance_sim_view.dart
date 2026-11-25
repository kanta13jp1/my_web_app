import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/income_insurance_controller.dart';
import '../domain/income_insurance_models.dart';

/// Pure presentation view for income insurance vs fixed direct payment (#2757).
class IncomeInsuranceSimView extends StatelessWidget {
  const IncomeInsuranceSimView({
    super.key,
    required this.state,
    required this.scenarioController,
    required this.baseRevenueController,
    required this.declineRateController,
    required this.yearsController,
    required this.windowController,
    required this.coveragePercentController,
    required this.payoutPercentController,
    required this.fixedBenchmarkController,
    required this.directPercentController,
    required this.onApplyPreset,
    required this.onRunSimulation,
    required this.onExportCsv,
  });

  final IncomeInsuranceSimState state;
  final TextEditingController scenarioController;
  final TextEditingController baseRevenueController;
  final TextEditingController declineRateController;
  final TextEditingController yearsController;
  final TextEditingController windowController;
  final TextEditingController coveragePercentController;
  final TextEditingController payoutPercentController;
  final TextEditingController fixedBenchmarkController;
  final TextEditingController directPercentController;
  final ValueChanged<IncomeInsuranceScenarioPreset> onApplyPreset;
  final VoidCallback onRunSimulation;
  final VoidCallback onExportCsv;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = state.result;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(colors: colors, result: result),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _BannerCard(
              key: const ValueKey<String>('income_sim_error_banner'),
              icon: Icons.error_outline,
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _BannerCard(
              key: const ValueKey<String>('income_sim_notice_banner'),
              icon: Icons.check_circle_outline,
              message: state.statusNotice!,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _ParameterFormCard(
            colors: colors,
            scenarioController: scenarioController,
            baseRevenueController: baseRevenueController,
            declineRateController: declineRateController,
            yearsController: yearsController,
            windowController: windowController,
            coveragePercentController: coveragePercentController,
            payoutPercentController: payoutPercentController,
            fixedBenchmarkController: fixedBenchmarkController,
            directPercentController: directPercentController,
            onApplyPreset: onApplyPreset,
            onRunSimulation: onRunSimulation,
          ),
          const SizedBox(height: 12),
          _KpiSummaryCard(colors: colors, result: result),
          const SizedBox(height: 12),
          _ComparisonChartCard(colors: colors, result: result),
          const SizedBox(height: 12),
          _YearlyTableCard(colors: colors, points: result.points),
          const SizedBox(height: 12),
          _CsvExportCard(
            colors: colors,
            csvPreview: state.csvPreview,
            onExportCsv: onExportCsv,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.colors,
    required this.result,
  });

  final ColorScheme colors;
  final IncomeInsuranceSimulationResult result;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.analytics_outlined, color: colors.primary),
                Text(
                  '収入保険課題分析・代替モデル比較シミュレーター',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${result.config.years}年間 / '
                      '年${result.config.annualDeclinePercent.toStringAsFixed(1)}%下落',
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '継続的な価格下落時に移動平均型（過去5年平均など）の基準収入が段階低下して下支えが縮小する構造と、'
              '固定基準による直接支払い方式（マルキン型等）の補償額推移を重ね合わせて比較します。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParameterFormCard extends StatelessWidget {
  const _ParameterFormCard({
    required this.colors,
    required this.scenarioController,
    required this.baseRevenueController,
    required this.declineRateController,
    required this.yearsController,
    required this.windowController,
    required this.coveragePercentController,
    required this.payoutPercentController,
    required this.fixedBenchmarkController,
    required this.directPercentController,
    required this.onApplyPreset,
    required this.onRunSimulation,
  });

  final ColorScheme colors;
  final TextEditingController scenarioController;
  final TextEditingController baseRevenueController;
  final TextEditingController declineRateController;
  final TextEditingController yearsController;
  final TextEditingController windowController;
  final TextEditingController coveragePercentController;
  final TextEditingController payoutPercentController;
  final TextEditingController fixedBenchmarkController;
  final TextEditingController directPercentController;
  final ValueChanged<IncomeInsuranceScenarioPreset> onApplyPreset;
  final VoidCallback onRunSimulation;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '1. 下落トレンド・補償パラメータ設定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: defaultIncomeInsurancePresets
                  .map(
                    (final IncomeInsuranceScenarioPreset preset) =>
                        OutlinedButton(
                      key: ValueKey<String>('income_sim_preset_${preset.id}'),
                      onPressed: () => onApplyPreset(preset),
                      child: Text(preset.label),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('income_sim_scenario_input'),
              controller: scenarioController,
              decoration: const InputDecoration(
                labelText: 'シナリオ名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_decline_input'),
              controller: declineRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '年次価格下落率 (%)',
                hintText: '8.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_years_input'),
              controller: yearsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'シミュレーション年数 (1〜30年)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_base_revenue_input'),
              controller: baseRevenueController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '初期基準収入 (万円)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_window_input'),
              controller: windowController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '移動平均ウィンドウ年数 (標準: 5年)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_coverage_input'),
              controller: coveragePercentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '収入保険 補償限度率 (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_payout_input'),
              controller: payoutPercentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '収入保険 支払率・補填率 (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_fixed_benchmark_input'),
              controller: fixedBenchmarkController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '固定基準価格/収入水準 (万円)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('income_sim_direct_rate_input'),
              controller: directPercentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '直接支払い 補填率 (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey<String>('income_sim_run_button'),
              onPressed: onRunSimulation,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('試算を実行'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiSummaryCard extends StatelessWidget {
  const _KpiSummaryCard({
    required this.colors,
    required this.result,
  });

  final ColorScheme colors;
  final IncomeInsuranceSimulationResult result;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('income_sim_kpi_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '2. 累計補償・基準下落サマリー',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetricBox(
                  key: const ValueKey<String>('income_sim_moving_total'),
                  label: '累計 移動平均補償',
                  value:
                      '${result.cumulativeMovingAveragePayout.toStringAsFixed(1)} 万円',
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                ),
                _MetricBox(
                  key: const ValueKey<String>('income_sim_fixed_total'),
                  label: '累計 固定基準補償',
                  value:
                      '${result.cumulativeFixedDirectPayout.toStringAsFixed(1)} 万円',
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                ),
                _MetricBox(
                  key: const ValueKey<String>('income_sim_gap_total'),
                  label: '累計保護ギャップ',
                  value: '${result.cumulativePayoutGap.toStringAsFixed(1)} 万円',
                  backgroundColor: colors.errorContainer,
                  foregroundColor: colors.onErrorContainer,
                ),
                _MetricBox(
                  key: const ValueKey<String>('income_sim_erosion_final'),
                  label: '最終年 移動平均基準低下率',
                  value:
                      '${result.finalYearBenchmarkErosionPercent.toStringAsFixed(1)}%',
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonChartCard extends StatelessWidget {
  const _ComparisonChartCard({
    required this.colors,
    required this.result,
  });

  final ColorScheme colors;
  final IncomeInsuranceSimulationResult result;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('income_sim_chart_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '3. 補償額推移の重ね合わせ比較グラフ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                _LegendDot(
                  label: '固定基準・直接支払い (実線・丸)',
                  color: colors.tertiary,
                  textColor: colors.onSurface,
                ),
                _LegendDot(
                  label: '移動平均型・収入保険 (実線・四角)',
                  color: colors.primary,
                  textColor: colors.onSurface,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '移動平均型収入保険と固定基準直接支払いの年次補償額比較グラフ',
              child: SizedBox(
                key: const ValueKey<String>('income_sim_chart_canvas'),
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _IncomeComparisonChartPainter(
                    points: result.points,
                    movingColor: colors.primary,
                    fixedColor: colors.tertiary,
                    gridColor: colors.outlineVariant,
                    axisLabelColor: colors.onSurfaceVariant,
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

class _IncomeComparisonChartPainter extends CustomPainter {
  const _IncomeComparisonChartPainter({
    required this.points,
    required this.movingColor,
    required this.fixedColor,
    required this.gridColor,
    required this.axisLabelColor,
  });

  final List<IncomeInsuranceYearPoint> points;
  final Color movingColor;
  final Color fixedColor;
  final Color gridColor;
  final Color axisLabelColor;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (points.isEmpty || size.width <= 40 || size.height <= 40) return;

    const padLeft = 12.0;
    const padRight = 12.0;
    const padTop = 14.0;
    const padBottom = 22.0;
    final chartWidth = size.width - padLeft - padRight;
    final chartHeight = size.height - padTop - padBottom;

    var maxPayout = 1.0;
    for (final pt in points) {
      maxPayout = math.max(
        maxPayout,
        math.max(pt.movingAveragePayout, pt.fixedDirectPayout),
      );
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (var step = 0; step <= 4; step += 1) {
      final y = padTop + (chartHeight * (step / 4.0));
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartWidth, y),
        gridPaint,
      );
    }

    Offset pointOffset(final int index, final double value) {
      final x = points.length == 1
          ? padLeft + chartWidth / 2
          : padLeft + (chartWidth * (index / (points.length - 1)));
      final normalized = (value / maxPayout).clamp(0.0, 1.0);
      final y = padTop + chartHeight * (1.0 - normalized);
      return Offset(x, y);
    }

    final fixedPaint = Paint()
      ..color = fixedColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    final movingPaint = Paint()
      ..color = movingColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final fixedPath = Path();
    final movingPath = Path();
    final fixedOffsets = <Offset>[];
    final movingOffsets = <Offset>[];

    for (var i = 0; i < points.length; i += 1) {
      final fOff = pointOffset(i, points[i].fixedDirectPayout);
      final mOff = pointOffset(i, points[i].movingAveragePayout);
      fixedOffsets.add(fOff);
      movingOffsets.add(mOff);
      if (i == 0) {
        fixedPath.moveTo(fOff.dx, fOff.dy);
        movingPath.moveTo(mOff.dx, mOff.dy);
      } else {
        fixedPath.lineTo(fOff.dx, fOff.dy);
        movingPath.lineTo(mOff.dx, mOff.dy);
      }
    }

    canvas.drawPath(fixedPath, fixedPaint);
    canvas.drawPath(movingPath, movingPaint);

    final fixedDotPaint = Paint()..color = fixedColor;
    final movingDotPaint = Paint()..color = movingColor;
    for (var i = 0; i < points.length; i += 1) {
      canvas.drawCircle(fixedOffsets[i], 4.5, fixedDotPaint);
      canvas.drawRect(
        Rect.fromCenter(center: movingOffsets[i], width: 8, height: 8),
        movingDotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant final _IncomeComparisonChartPainter oldDelegate,
  ) {
    return oldDelegate.points != points ||
        oldDelegate.movingColor != movingColor ||
        oldDelegate.fixedColor != fixedColor;
  }
}

class _YearlyTableCard extends StatelessWidget {
  const _YearlyTableCard({
    required this.colors,
    required this.points,
  });

  final ColorScheme colors;
  final List<IncomeInsuranceYearPoint> points;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('income_sim_table_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '4. 年次別詳細データ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ...points.map(
              (final IncomeInsuranceYearPoint pt) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${pt.year}年目 ・ 実収入 ${pt.actualRevenue.toStringAsFixed(1)} 万円 '
                      '(移動平均基準 ${pt.movingAverageBenchmark.toStringAsFixed(1)} 万円)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '移動平均補償: ${pt.movingAveragePayout.toStringAsFixed(1)} 万円 / '
                      '固定基準補償: ${pt.fixedDirectPayout.toStringAsFixed(1)} 万円 / '
                      '差額: ${pt.payoutGap.toStringAsFixed(1)} 万円',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CsvExportCard extends StatelessWidget {
  const _CsvExportCard({
    required this.colors,
    required this.csvPreview,
    required this.onExportCsv,
  });

  final ColorScheme colors;
  final String csvPreview;
  final VoidCallback onExportCsv;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '5. CSV エクスポート・検証データ出力',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                ElevatedButton.icon(
                  key: const ValueKey<String>('income_sim_export_csv_button'),
                  onPressed: onExportCsv,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('CSV 出力'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                csvPreview,
                key: const ValueKey<String>('income_sim_csv_preview'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    super.key,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: foregroundColor),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(final BuildContext context) {
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 12,
          height: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(color: textColor),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    super.key,
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(icon, color: foregroundColor),
          Text(
            message,
            style: TextStyle(color: foregroundColor),
          ),
        ],
      ),
    );
  }
}

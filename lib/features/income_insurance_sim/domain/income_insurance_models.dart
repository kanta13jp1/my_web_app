import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class IncomeInsuranceSimulationConfig {
  const IncomeInsuranceSimulationConfig({
    this.scenarioLabel = '継続価格下落シミュレーション',
    this.baseRevenue = 1000.0,
    this.annualDeclinePercent = 8.0,
    this.years = 10,
    this.movingAverageWindow = 5,
    this.coverageLimitRate = 0.9,
    this.payoutRate = 0.9,
    this.fixedBenchmarkRevenue = 1000.0,
    this.directPaymentSubsidyRate = 0.9,
  });

  final String scenarioLabel;
  final double baseRevenue;
  final double annualDeclinePercent;
  final int years;
  final int movingAverageWindow;
  final double coverageLimitRate;
  final double payoutRate;
  final double fixedBenchmarkRevenue;
  final double directPaymentSubsidyRate;

  IncomeInsuranceSimulationConfig copyWith({
    final String? scenarioLabel,
    final double? baseRevenue,
    final double? annualDeclinePercent,
    final int? years,
    final int? movingAverageWindow,
    final double? coverageLimitRate,
    final double? payoutRate,
    final double? fixedBenchmarkRevenue,
    final double? directPaymentSubsidyRate,
  }) {
    return IncomeInsuranceSimulationConfig(
      scenarioLabel: scenarioLabel ?? this.scenarioLabel,
      baseRevenue: baseRevenue ?? this.baseRevenue,
      annualDeclinePercent: annualDeclinePercent ?? this.annualDeclinePercent,
      years: years ?? this.years,
      movingAverageWindow: movingAverageWindow ?? this.movingAverageWindow,
      coverageLimitRate: coverageLimitRate ?? this.coverageLimitRate,
      payoutRate: payoutRate ?? this.payoutRate,
      fixedBenchmarkRevenue:
          fixedBenchmarkRevenue ?? this.fixedBenchmarkRevenue,
      directPaymentSubsidyRate:
          directPaymentSubsidyRate ?? this.directPaymentSubsidyRate,
    );
  }
}

@immutable
class IncomeInsuranceYearPoint {
  const IncomeInsuranceYearPoint({
    required this.year,
    required this.actualRevenue,
    required this.movingAverageBenchmark,
    required this.movingAverageTriggerFloor,
    required this.movingAveragePayout,
    required this.fixedBenchmark,
    required this.fixedDirectPayout,
    required this.payoutGap,
    required this.benchmarkErosionPercent,
  });

  final int year;
  final double actualRevenue;
  final double movingAverageBenchmark;
  final double movingAverageTriggerFloor;
  final double movingAveragePayout;
  final double fixedBenchmark;
  final double fixedDirectPayout;
  final double payoutGap;
  final double benchmarkErosionPercent;
}

@immutable
class IncomeInsuranceSimulationResult {
  const IncomeInsuranceSimulationResult({
    required this.config,
    required this.points,
    required this.cumulativeMovingAveragePayout,
    required this.cumulativeFixedDirectPayout,
    required this.cumulativePayoutGap,
    required this.finalYearBenchmarkErosionPercent,
    required this.year1MovingAveragePayout,
    required this.finalYearMovingAveragePayout,
    required this.movingAverageDecayPercent,
  });

  final IncomeInsuranceSimulationConfig config;
  final List<IncomeInsuranceYearPoint> points;
  final double cumulativeMovingAveragePayout;
  final double cumulativeFixedDirectPayout;
  final double cumulativePayoutGap;
  final double finalYearBenchmarkErosionPercent;
  final double year1MovingAveragePayout;
  final double finalYearMovingAveragePayout;
  final double movingAverageDecayPercent;
}

/// Deterministic calculation engine for moving-average vs fixed-benchmark pay.
class IncomeInsuranceEngine {
  const IncomeInsuranceEngine._();

  static String? validateConfig(final IncomeInsuranceSimulationConfig config) {
    if (!config.baseRevenue.isFinite || config.baseRevenue < 0) {
      return '基準収入は 0 以上の有限値で入力してください。';
    }
    if (!config.fixedBenchmarkRevenue.isFinite ||
        config.fixedBenchmarkRevenue < 0) {
      return '固定基準収入は 0 以上の有限値で入力してください。';
    }
    if (!config.annualDeclinePercent.isFinite ||
        config.annualDeclinePercent < 0 ||
        config.annualDeclinePercent > 100) {
      return '年次価格下落率は 0% 〜 100% の範囲で入力してください。';
    }
    if (config.years < 1 || config.years > 30) {
      return 'シミュレーション期間は 1 〜 30 年の範囲で指定してください。';
    }
    if (config.movingAverageWindow < 1 || config.movingAverageWindow > 10) {
      return '移動平均ウィンドウは 1 〜 10 年の範囲で指定してください。';
    }
    if (!config.coverageLimitRate.isFinite ||
        config.coverageLimitRate <= 0 ||
        config.coverageLimitRate > 1.0) {
      return '補償限度率（補償水準）は 0 超 〜 1.0 の範囲で指定してください。';
    }
    if (!config.payoutRate.isFinite ||
        config.payoutRate <= 0 ||
        config.payoutRate > 1.0) {
      return '支払率（補填率）は 0 超 〜 1.0 の範囲で指定してください。';
    }
    if (!config.directPaymentSubsidyRate.isFinite ||
        config.directPaymentSubsidyRate <= 0 ||
        config.directPaymentSubsidyRate > 1.0) {
      return '固定基準補填率は 0 超 〜 1.0 の範囲で指定してください。';
    }
    return null;
  }

  static IncomeInsuranceSimulationResult simulate(
    final IncomeInsuranceSimulationConfig config,
  ) {
    final validationError = validateConfig(config);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final history = List<double>.filled(
      config.movingAverageWindow,
      config.baseRevenue,
      growable: true,
    );
    final points = <IncomeInsuranceYearPoint>[];
    var totalMoving = 0.0;
    var totalFixed = 0.0;

    for (var year = 1; year <= config.years; year += 1) {
      final declineFactor = math
          .pow(
            1.0 - (config.annualDeclinePercent / 100.0),
            year,
          )
          .toDouble();
      final actualRevenue = config.annualDeclinePercent >= 100.0
          ? 0.0
          : math.max(0.0, config.baseRevenue * declineFactor);

      final windowSlice =
          history.sublist(history.length - config.movingAverageWindow);
      final sumWindow = windowSlice.fold<double>(
        0.0,
        (final double acc, final double value) => acc + value,
      );
      final movingAvgBenchmark = sumWindow / config.movingAverageWindow;
      final movingTriggerFloor = movingAvgBenchmark * config.coverageLimitRate;
      final movingShortfall = math.max(0.0, movingTriggerFloor - actualRevenue);
      final movingPayout = movingShortfall * config.payoutRate;

      final fixedShortfall =
          math.max(0.0, config.fixedBenchmarkRevenue - actualRevenue);
      final fixedPayout = fixedShortfall * config.directPaymentSubsidyRate;

      final erosionPercent = config.baseRevenue <= 0.0
          ? 0.0
          : (((config.baseRevenue - movingAvgBenchmark) / config.baseRevenue) *
                  100.0)
              .clamp(0.0, 100.0);

      points.add(
        IncomeInsuranceYearPoint(
          year: year,
          actualRevenue: actualRevenue,
          movingAverageBenchmark: movingAvgBenchmark,
          movingAverageTriggerFloor: movingTriggerFloor,
          movingAveragePayout: movingPayout,
          fixedBenchmark: config.fixedBenchmarkRevenue,
          fixedDirectPayout: fixedPayout,
          payoutGap: fixedPayout - movingPayout,
          benchmarkErosionPercent: erosionPercent,
        ),
      );

      totalMoving += movingPayout;
      totalFixed += fixedPayout;
      history.add(actualRevenue);
    }

    final year1Payout = points.first.movingAveragePayout;
    final finalPayout = points.last.movingAveragePayout;
    final peakMoving = points.fold<double>(
      0.0,
      (final double peak, final IncomeInsuranceYearPoint pt) =>
          math.max(peak, pt.movingAveragePayout),
    );
    final decayPercent = peakMoving <= 0.0
        ? 0.0
        : (((peakMoving - finalPayout) / peakMoving) * 100.0).clamp(0.0, 100.0);

    return IncomeInsuranceSimulationResult(
      config: config,
      points: List<IncomeInsuranceYearPoint>.unmodifiable(points),
      cumulativeMovingAveragePayout: totalMoving,
      cumulativeFixedDirectPayout: totalFixed,
      cumulativePayoutGap: totalFixed - totalMoving,
      finalYearBenchmarkErosionPercent: points.last.benchmarkErosionPercent,
      year1MovingAveragePayout: year1Payout,
      finalYearMovingAveragePayout: finalPayout,
      movingAverageDecayPercent: decayPercent,
    );
  }
}

/// Pure RFC-4180 CSV serializer with formula-injection neutralization.
class IncomeInsuranceCsvExporter {
  const IncomeInsuranceCsvExporter._();

  static String escapeCell(final String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final needsFormulaGuard = normalized.isNotEmpty &&
        (normalized.startsWith('=') ||
            normalized.startsWith('+') ||
            normalized.startsWith('-') ||
            normalized.startsWith('@') ||
            normalized.startsWith('\t'));
    final guarded = needsFormulaGuard ? "'$normalized" : normalized;
    final needsQuotes = guarded.contains(',') ||
        guarded.contains('"') ||
        guarded.contains('\n');
    if (!needsQuotes) {
      return guarded;
    }
    return '"${guarded.replaceAll('"', '""')}"';
  }

  static String toCsv(final IncomeInsuranceSimulationResult result) {
    final buffer = StringBuffer();
    buffer.writeln(
      'year,scenario_label,actual_revenue,moving_avg_benchmark,'
      'moving_avg_trigger_floor,moving_avg_payout,fixed_benchmark,'
      'fixed_direct_payout,payout_gap,benchmark_erosion_percent',
    );
    final labelCell = escapeCell(result.config.scenarioLabel);
    for (final pt in result.points) {
      buffer.writeln(
        <String>[
          pt.year.toString(),
          labelCell,
          pt.actualRevenue.toStringAsFixed(2),
          pt.movingAverageBenchmark.toStringAsFixed(2),
          pt.movingAverageTriggerFloor.toStringAsFixed(2),
          pt.movingAveragePayout.toStringAsFixed(2),
          pt.fixedBenchmark.toStringAsFixed(2),
          pt.fixedDirectPayout.toStringAsFixed(2),
          pt.payoutGap.toStringAsFixed(2),
          pt.benchmarkErosionPercent.toStringAsFixed(2),
        ].join(','),
      );
    }
    return buffer.toString();
  }
}

@immutable
class IncomeInsuranceScenarioPreset {
  const IncomeInsuranceScenarioPreset({
    required this.id,
    required this.label,
    required this.config,
  });

  final String id;
  final String label;
  final IncomeInsuranceSimulationConfig config;
}

const List<IncomeInsuranceScenarioPreset> defaultIncomeInsurancePresets =
    <IncomeInsuranceScenarioPreset>[
  IncomeInsuranceScenarioPreset(
    id: 'moderate_decline',
    label: '標準下落 (年8%/10年)',
    config: IncomeInsuranceSimulationConfig(
      scenarioLabel: '標準下落シナリオ (年8%)',
      baseRevenue: 1000.0,
      annualDeclinePercent: 8.0,
      years: 10,
      movingAverageWindow: 5,
      coverageLimitRate: 0.9,
      payoutRate: 0.9,
      fixedBenchmarkRevenue: 1000.0,
      directPaymentSubsidyRate: 0.9,
    ),
  ),
  IncomeInsuranceScenarioPreset(
    id: 'steep_decline',
    label: '急落 (年15%/10年)',
    config: IncomeInsuranceSimulationConfig(
      scenarioLabel: '継続急落シナリオ (年15%)',
      baseRevenue: 1000.0,
      annualDeclinePercent: 15.0,
      years: 10,
      movingAverageWindow: 5,
      coverageLimitRate: 0.9,
      payoutRate: 0.9,
      fixedBenchmarkRevenue: 1000.0,
      directPaymentSubsidyRate: 0.9,
    ),
  ),
  IncomeInsuranceScenarioPreset(
    id: 'flat_market',
    label: '価格安定 (年0%境界)',
    config: IncomeInsuranceSimulationConfig(
      scenarioLabel: '価格安定シナリオ (年0%)',
      baseRevenue: 1000.0,
      annualDeclinePercent: 0.0,
      years: 5,
      movingAverageWindow: 5,
      coverageLimitRate: 0.9,
      payoutRate: 0.9,
      fixedBenchmarkRevenue: 1000.0,
      directPaymentSubsidyRate: 0.9,
    ),
  ),
];

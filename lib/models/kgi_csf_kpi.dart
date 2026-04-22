class KgiCsfKpiMetric {
  final String csf;
  final String kpi;
  final String actualLabel;
  final String targetLabel;
  final double? progress;
  final String? remainingLabel;

  const KgiCsfKpiMetric({
    required this.csf,
    required this.kpi,
    required this.actualLabel,
    required this.targetLabel,
    this.progress,
    this.remainingLabel,
  });

  factory KgiCsfKpiMetric.number({
    required String csf,
    required String kpi,
    required num actual,
    required num target,
    String unit = '',
    String? remainingUnit,
  }) {
    final safeTarget = target <= 0 ? 0 : target.toDouble();
    final progress = safeTarget <= 0 ? 0.0 : actual / safeTarget;
    final remaining = target - actual;
    final suffix = remainingUnit ?? unit;
    return KgiCsfKpiMetric(
      csf: csf,
      kpi: kpi,
      actualLabel: '${_formatNumber(actual)}$unit',
      targetLabel: '${_formatNumber(target)}$unit',
      progress: progress.clamp(0, 1).toDouble(),
      remainingLabel:
          remaining > 0 ? '残り${_formatNumber(remaining)}$suffix' : '達成',
    );
  }
}

class KgiCsfKpiPlan {
  final String domain;
  final String kgi;
  final String actualLabel;
  final String targetLabel;
  final double? progress;
  final List<KgiCsfKpiMetric> metrics;

  const KgiCsfKpiPlan({
    required this.domain,
    required this.kgi,
    required this.actualLabel,
    required this.targetLabel,
    required this.metrics,
    this.progress,
  });

  double get averageProgress {
    final values = metrics
        .map((item) => item.progress)
        .whereType<double>()
        .map((value) => value.clamp(0, 1).toDouble())
        .toList();
    if (values.isEmpty) {
      return (progress ?? 0).clamp(0, 1).toDouble();
    }
    return values.reduce((sum, value) => sum + value) / values.length;
  }

  double get displayProgress =>
      (progress ?? averageProgress).clamp(0, 1).toDouble();
}

String _formatNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

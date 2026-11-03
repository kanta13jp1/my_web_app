class HabitResourceMetric {
  const HabitResourceMetric({
    required this.habitId,
    required this.habitTitle,
    required this.goalTitle,
    required this.sampleCount,
    required this.averageTimeMinutes,
    required this.averageFatigueScore,
    required this.averageGoalContributionScore,
    required this.resourceCostIndex,
    required this.efficiencyScore,
    required this.isParetoOptimal,
  });

  final String habitId;
  final String habitTitle;
  final String? goalTitle;
  final int sampleCount;
  final double averageTimeMinutes;
  final double averageFatigueScore;
  final double averageGoalContributionScore;
  final double resourceCostIndex;
  final double efficiencyScore;
  final bool isParetoOptimal;

  factory HabitResourceMetric.fromJson(Map<String, dynamic> json) {
    return HabitResourceMetric(
      habitId: (json['habit_id'] ?? '').toString(),
      habitTitle: (json['habit_title'] ?? '名称未設定の習慣').toString(),
      goalTitle: _nullableString(json['goal_title']),
      sampleCount: _asInt(json['sample_count']).clamp(0, 1000000),
      averageTimeMinutes: _asDouble(json['avg_time_minutes']).clamp(0, 1440),
      averageFatigueScore: _asDouble(json['avg_fatigue_score']).clamp(0, 10),
      averageGoalContributionScore: _asDouble(
        json['avg_goal_contribution_score'],
      ).clamp(0, 100),
      resourceCostIndex: _asDouble(json['resource_cost_index']).clamp(0, 2000),
      efficiencyScore: _asDouble(json['efficiency_score']).clamp(0, 1000),
      isParetoOptimal: json['is_pareto_optimal'] == true,
    );
  }
}

class ResourceRecommendation {
  const ResourceRecommendation({
    required this.habitId,
    required this.title,
    required this.reason,
  });

  final String habitId;
  final String title;
  final String reason;

  factory ResourceRecommendation.fromJson(Map<String, dynamic> json) {
    return ResourceRecommendation(
      habitId: (json['habit_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class ResourceScalingStep {
  const ResourceScalingStep({
    required this.stage,
    required this.durationDays,
    required this.loadMultiplier,
    required this.target,
    required this.guardrail,
  });

  final int stage;
  final int durationDays;
  final double loadMultiplier;
  final String target;
  final String guardrail;

  factory ResourceScalingStep.fromJson(Map<String, dynamic> json) {
    return ResourceScalingStep(
      stage: _asInt(json['stage']).clamp(1, 3),
      durationDays: _asInt(json['duration_days']).clamp(3, 30),
      loadMultiplier: _asDouble(json['load_multiplier']).clamp(0.8, 1.25),
      target: (json['target'] ?? '').toString(),
      guardrail: (json['guardrail'] ?? '').toString(),
    );
  }
}

class ResourceOptimizationReport {
  const ResourceOptimizationReport({
    required this.generatedBy,
    required this.windowDays,
    required this.sampleCount,
    required this.timePerformanceCorrelation,
    required this.fatiguePerformanceCorrelation,
    required this.metrics,
    required this.paretoFrontier,
    required this.mentorSummary,
    required this.recommendations,
    required this.scalingPlan,
  });

  final String generatedBy;
  final int windowDays;
  final int sampleCount;
  final double? timePerformanceCorrelation;
  final double? fatiguePerformanceCorrelation;
  final List<HabitResourceMetric> metrics;
  final List<HabitResourceMetric> paretoFrontier;
  final String mentorSummary;
  final List<ResourceRecommendation> recommendations;
  final List<ResourceScalingStep> scalingPlan;

  bool get hasData => metrics.isNotEmpty && sampleCount > 0;

  factory ResourceOptimizationReport.fromJson(Map<String, dynamic> json) {
    final correlations = json['correlations'] is Map
        ? Map<String, dynamic>.from(json['correlations'] as Map)
        : <String, dynamic>{};
    return ResourceOptimizationReport(
      generatedBy: (json['generated_by'] ?? 'deterministic').toString(),
      windowDays: _asInt(json['window_days']).clamp(7, 365),
      sampleCount: _asInt(json['sample_count']).clamp(0, 1000000),
      timePerformanceCorrelation: _asCorrelation(
        correlations['time_to_performance'],
      ),
      fatiguePerformanceCorrelation: _asCorrelation(
        correlations['fatigue_to_performance'],
      ),
      metrics: _mapList(json['metrics'], HabitResourceMetric.fromJson),
      paretoFrontier: _mapList(
        json['pareto_frontier'],
        HabitResourceMetric.fromJson,
      ),
      mentorSummary: (json['mentor_summary'] ?? '').toString(),
      recommendations: _mapList(
        json['recommendations'],
        ResourceRecommendation.fromJson,
      ),
      scalingPlan: _mapList(json['scaling_plan'], ResourceScalingStep.fromJson),
    );
  }
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) factory) {
  return ((value as List?) ?? const [])
      .whereType<Map>()
      .map((item) => factory(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return parsed.isFinite ? parsed : 0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) return null;
  final parsed =
      value is num ? value.toDouble() : double.tryParse(value.toString());
  return parsed != null && parsed.isFinite ? parsed : null;
}

double? _asCorrelation(Object? value) {
  final parsed = _asNullableDouble(value);
  return parsed?.clamp(-1, 1);
}

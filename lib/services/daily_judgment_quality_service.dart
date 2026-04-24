class DailyJudgmentQualityCriterion {
  const DailyJudgmentQualityCriterion({
    required this.id,
    required this.label,
    required this.score,
    required this.weight,
    required this.reason,
  });

  final String id;
  final String label;
  final int score;
  final int weight;
  final String reason;

  factory DailyJudgmentQualityCriterion.fromMap(Map<String, dynamic> map) {
    return DailyJudgmentQualityCriterion(
      id: _stringValue(map['id']),
      label: _stringValue(map['label']),
      score: _intValue(map['score']),
      weight: _intValue(map['weight']),
      reason: _stringValue(map['reason']),
    );
  }
}

class DailyJudgmentQualityEvaluation {
  const DailyJudgmentQualityEvaluation({
    required this.method,
    required this.threshold,
    required this.overallScore,
    required this.passed,
    required this.qualityGate,
    required this.criteria,
    required this.improvementActions,
    required this.monitoringCadence,
  });

  final String method;
  final int threshold;
  final int overallScore;
  final bool passed;
  final String qualityGate;
  final List<DailyJudgmentQualityCriterion> criteria;
  final List<String> improvementActions;
  final String monitoringCadence;

  factory DailyJudgmentQualityEvaluation.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    return DailyJudgmentQualityEvaluation(
      method: _stringValue(source['method'], fallback: 'not_evaluated'),
      threshold: _intValue(source['threshold'], fallback: 80),
      overallScore: _intValue(source['overall_score']),
      passed: source['passed'] == true,
      qualityGate: _stringValue(source['quality_gate'], fallback: 'unknown'),
      criteria: _criteria(source['criteria']),
      improvementActions: _stringList(source['improvement_actions']),
      monitoringCadence:
          _stringValue(source['monitoring_cadence'], fallback: 'daily'),
    );
  }

  bool get needsReview => !passed || overallScore < threshold;

  static List<DailyJudgmentQualityCriterion> _criteria(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => DailyJudgmentQualityCriterion.fromMap(
            item.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.round().clamp(0, 100);
  final parsed = int.tryParse(value?.toString() ?? '');
  return (parsed ?? fallback).clamp(0, 100);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

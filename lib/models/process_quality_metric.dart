class ProcessQualityMetricDraft {
  final String projectName;
  final String featureName;
  final String scopeUnit;
  final double scopeSize;
  final int reviewMinutes;
  final int findingCount;
  final double minimumReviewDensity;
  final double minimumFindingDensity;
  final DateTime reviewedAt;

  const ProcessQualityMetricDraft({
    required this.projectName,
    required this.featureName,
    required this.scopeUnit,
    required this.scopeSize,
    required this.reviewMinutes,
    required this.findingCount,
    required this.minimumReviewDensity,
    required this.minimumFindingDensity,
    required this.reviewedAt,
  });

  Map<String, dynamic> toInsertRow(String userId) => <String, dynamic>{
        'user_id': userId,
        'project_name': projectName.trim(),
        'feature_name': featureName.trim(),
        'scope_unit': scopeUnit,
        'scope_size': scopeSize,
        'review_minutes': reviewMinutes,
        'finding_count': findingCount,
        'minimum_review_density': minimumReviewDensity,
        'minimum_finding_density': minimumFindingDensity,
        'reviewed_at': reviewedAt.toUtc().toIso8601String(),
      };
}

class ProcessQualityMetric {
  final String id;
  final String projectName;
  final String featureName;
  final String scopeUnit;
  final double scopeSize;
  final int reviewMinutes;
  final int findingCount;
  final double minimumReviewDensity;
  final double minimumFindingDensity;
  final DateTime reviewedAt;

  const ProcessQualityMetric({
    required this.id,
    required this.projectName,
    required this.featureName,
    required this.scopeUnit,
    required this.scopeSize,
    required this.reviewMinutes,
    required this.findingCount,
    required this.minimumReviewDensity,
    required this.minimumFindingDensity,
    required this.reviewedAt,
  });

  double get reviewDensity => scopeSize <= 0 ? 0 : reviewMinutes / scopeSize;

  double get findingDensity => scopeSize <= 0 ? 0 : findingCount / scopeSize;

  bool get reviewDensityBelowThreshold =>
      reviewDensity < minimumReviewDensity;

  bool get findingDensityBelowThreshold =>
      findingDensity < minimumFindingDensity;

  bool get needsAttention =>
      reviewDensityBelowThreshold || findingDensityBelowThreshold;

  factory ProcessQualityMetric.fromJson(Map<String, dynamic> json) {
    return ProcessQualityMetric(
      id: json['id']?.toString() ?? '',
      projectName: json['project_name']?.toString() ?? '',
      featureName: json['feature_name']?.toString() ?? '',
      scopeUnit: json['scope_unit']?.toString() ?? 'features',
      scopeSize: _asDouble(json['scope_size']),
      reviewMinutes: _asInt(json['review_minutes']),
      findingCount: _asInt(json['finding_count']),
      minimumReviewDensity: _asDouble(json['minimum_review_density']),
      minimumFindingDensity: _asDouble(json['minimum_finding_density']),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

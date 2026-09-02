import 'dart:convert';

class TigerReviewStatusSnapshot {
  const TigerReviewStatusSnapshot({
    required this.schemaVersion,
    required this.generatedAt,
    required this.publicationState,
    required this.automation,
    required this.pool,
    required this.coursePool,
    required this.featurePool,
    required this.latestCycle,
    required this.courses,
    required this.features,
    required this.reviewers,
    required this.disclaimer,
  });

  final int schemaVersion;
  final DateTime? generatedAt;
  final TigerReviewAutomation automation;
  final TigerReviewPool pool;
  final TigerReviewPool coursePool;
  final TigerReviewPool featurePool;
  final String publicationState;
  final TigerReviewCycle? latestCycle;
  final List<TigerReviewedCourse> courses;
  final List<TigerReviewedFeature> features;
  final List<TigerReviewerStanding> reviewers;
  final String disclaimer;

  factory TigerReviewStatusSnapshot.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('虎レビュー状況JSONの形式が不正です。');
    }
    return TigerReviewStatusSnapshot.fromJson(decoded);
  }

  factory TigerReviewStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return TigerReviewStatusSnapshot(
      schemaVersion: _asInt(json['schema_version']),
      generatedAt: DateTime.tryParse(_asString(json['generated_at'])),
      publicationState: _asString(json['publication_state']),
      automation: TigerReviewAutomation.fromJson(_asMap(json['automation'])),
      pool: TigerReviewPool.fromJson(_asMap(json['pool'])),
      coursePool: TigerReviewPool.fromJson(_asMap(json['course_pool'])),
      featurePool: TigerReviewPool.fromJson(_asMap(json['feature_pool'])),
      latestCycle: json['latest_cycle'] is Map<String, dynamic>
          ? TigerReviewCycle.fromJson(_asMap(json['latest_cycle']))
          : null,
      reviewers: _asList(json['reviewers'])
          .whereType<Map<String, dynamic>>()
          .map(TigerReviewerStanding.fromJson)
          .toList(growable: false),
      courses: _asList(json['courses'])
          .whereType<Map<String, dynamic>>()
          .map(TigerReviewedCourse.fromJson)
          .toList(growable: false),
      features: _asList(json['features'])
          .whereType<Map<String, dynamic>>()
          .map(TigerReviewedFeature.fromJson)
          .toList(growable: false),
      disclaimer: _asString(json['disclaimer']),
    );
  }
}

class TigerReviewAutomation {
  const TigerReviewAutomation({
    required this.id,
    required this.name,
    required this.status,
    required this.schedule,
  });

  final String id;
  final String name;
  final String status;
  final String schedule;

  factory TigerReviewAutomation.fromJson(Map<String, dynamic> json) {
    return TigerReviewAutomation(
      id: _asString(json['id']),
      name: _asString(json['name']),
      status: _asString(json['status']),
      schedule: _asString(json['schedule']),
    );
  }
}

class TigerReviewPool {
  const TigerReviewPool({
    required this.total,
    required this.eligible,
    required this.provisional,
    required this.division1,
    required this.division2,
    required this.division3,
    required this.division4,
    required this.division5,
    required this.eliminated,
    required this.minimumEligiblePool,
  });

  final int total;
  final int eligible;
  final int provisional;
  final int division1;
  final int division2;
  final int division3;
  final int division4;
  final int division5;
  final int eliminated;
  final int minimumEligiblePool;

  factory TigerReviewPool.fromJson(Map<String, dynamic> json) {
    return TigerReviewPool(
      total: _asInt(json['total']),
      eligible: _asInt(json['eligible']),
      provisional: _asInt(json['provisional']),
      division1: _asInt(json['division_1']),
      division2: _asInt(json['division_2']),
      division3: _asInt(json['division_3']),
      division4: _asInt(json['division_4']),
      division5: _asInt(json['division_5']),
      eliminated: _asInt(json['eliminated']),
      minimumEligiblePool: _asInt(json['minimum_eligible_pool']),
    );
  }
}

class TigerReviewCycle {
  const TigerReviewCycle({
    required this.cycleId,
    required this.startedAt,
    required this.surfaceSlug,
    required this.surfaceUrl,
    required this.reviewerSeat,
    required this.reviewerName,
    required this.selectionScore,
    required this.cycleUtility,
    required this.aggregateUtility,
    required this.tier,
    required this.division,
    required this.courseReview,
    required this.featureReview,
    required this.status,
    required this.validation,
    required this.findingCount,
    required this.topFindings,
  });

  final String cycleId;
  final DateTime? startedAt;
  final String surfaceSlug;
  final String surfaceUrl;
  final int reviewerSeat;
  final String reviewerName;
  final double? selectionScore;
  final double? cycleUtility;
  final double? aggregateUtility;
  final String tier;
  final int division;
  final TigerCourseReviewCycle? courseReview;
  final TigerFeatureReviewCycle? featureReview;
  final String status;
  final String validation;
  final int findingCount;
  final List<TigerReviewFinding> topFindings;

  factory TigerReviewCycle.fromJson(Map<String, dynamic> json) {
    final surface = _asMap(json['surface']);
    final reviewer = _asMap(json['reviewer']);
    return TigerReviewCycle(
      cycleId: _asString(json['cycle_id']),
      startedAt: DateTime.tryParse(_asString(json['started_at'])),
      surfaceSlug: _asString(surface['slug']),
      surfaceUrl: _asString(surface['url']),
      reviewerSeat: _asInt(reviewer['seat']),
      reviewerName: _asString(reviewer['name']),
      selectionScore: _asDoubleOrNull(reviewer['selection_score']),
      cycleUtility: _asDoubleOrNull(reviewer['cycle_utility']),
      aggregateUtility: _asDoubleOrNull(reviewer['aggregate_utility']),
      tier: _asString(reviewer['tier']),
      division: _asInt(reviewer['division']),
      courseReview: json['course_review'] is Map<String, dynamic>
          ? TigerCourseReviewCycle.fromJson(_asMap(json['course_review']))
          : null,
      featureReview: json['feature_review'] is Map<String, dynamic>
          ? TigerFeatureReviewCycle.fromJson(_asMap(json['feature_review']))
          : null,
      status: _asString(json['status']),
      validation: _asString(json['validation']),
      findingCount: _asInt(json['finding_count']),
      topFindings: _asList(json['top_findings'])
          .whereType<Map<String, dynamic>>()
          .map(TigerReviewFinding.fromJson)
          .toList(growable: false),
    );
  }
}

class TigerReviewFinding {
  const TigerReviewFinding({
    required this.summary,
    required this.severity,
    required this.businessDimensions,
  });

  final String summary;
  final String severity;
  final List<String> businessDimensions;

  factory TigerReviewFinding.fromJson(Map<String, dynamic> json) {
    return TigerReviewFinding(
      summary: _asString(json['summary']),
      severity: _asString(json['severity']),
      businessDimensions: _asList(
        json['business_dimensions'],
      ).whereType<String>().toList(growable: false),
    );
  }
}

class TigerCourseReviewCycle {
  const TigerCourseReviewCycle({
    required this.contentId,
    required this.provider,
    required this.title,
    required this.sourceUrl,
    required this.cycleUtility,
    required this.aggregateUtility,
    required this.division,
    required this.reason,
  });

  final String contentId;
  final String provider;
  final String title;
  final String sourceUrl;
  final double? cycleUtility;
  final double? aggregateUtility;
  final int division;
  final String reason;

  factory TigerCourseReviewCycle.fromJson(Map<String, dynamic> json) {
    return TigerCourseReviewCycle(
      contentId: _asString(json['content_id']),
      provider: _asString(json['provider']),
      title: _asString(json['title']),
      sourceUrl: _asString(json['source_url']),
      cycleUtility: _asDoubleOrNull(json['cycle_utility']),
      aggregateUtility: _asDoubleOrNull(json['aggregate_utility']),
      division: _asInt(json['division']),
      reason: _asString(json['reason']),
    );
  }
}

class TigerReviewedCourse {
  const TigerReviewedCourse({
    required this.contentId,
    required this.provider,
    required this.title,
    required this.sourceUrl,
    required this.division,
    required this.provisional,
    required this.eligible,
    required this.utilityScore,
    required this.completedCycles,
    required this.lastCycleUtility,
    required this.lastReviewedAt,
    required this.reason,
  });

  final String contentId;
  final String provider;
  final String title;
  final String sourceUrl;
  final int division;
  final bool provisional;
  final bool eligible;
  final double? utilityScore;
  final int completedCycles;
  final double? lastCycleUtility;
  final DateTime? lastReviewedAt;
  final String reason;

  factory TigerReviewedCourse.fromJson(Map<String, dynamic> json) {
    return TigerReviewedCourse(
      contentId: _asString(json['content_id']),
      provider: _asString(json['provider']),
      title: _asString(json['title']),
      sourceUrl: _asString(json['source_url']),
      division: _asInt(json['division']),
      provisional: json['provisional'] == true,
      eligible: json['eligible'] == true,
      utilityScore: _asDoubleOrNull(json['utility_score']),
      completedCycles: _asInt(json['completed_cycles']),
      lastCycleUtility: _asDoubleOrNull(json['last_cycle_utility']),
      lastReviewedAt: DateTime.tryParse(_asString(json['last_reviewed_at'])),
      reason: _asString(json['reason']),
    );
  }
}

class TigerFeatureReviewCycle {
  const TigerFeatureReviewCycle({
    required this.slug,
    required this.title,
    required this.kind,
    required this.cycleUtility,
    required this.aggregateUtility,
    required this.division,
    required this.reason,
  });

  final String slug;
  final String title;
  final String kind;
  final double? cycleUtility;
  final double? aggregateUtility;
  final int division;
  final String reason;

  factory TigerFeatureReviewCycle.fromJson(Map<String, dynamic> json) {
    return TigerFeatureReviewCycle(
      slug: _asString(json['slug']),
      title: _asString(json['title']),
      kind: _asString(json['kind']),
      cycleUtility: _asDoubleOrNull(json['cycle_utility']),
      aggregateUtility: _asDoubleOrNull(json['aggregate_utility']),
      division: _asInt(json['division']),
      reason: _asString(json['reason']),
    );
  }
}

class TigerReviewedFeature {
  const TigerReviewedFeature({
    required this.slug,
    required this.title,
    required this.kind,
    required this.path,
    required this.source,
    required this.priority,
    required this.division,
    required this.provisional,
    required this.eligible,
    required this.utilityScore,
    required this.completedCycles,
    required this.lastCycleUtility,
    required this.lastReviewedAt,
    required this.reason,
  });

  final String slug;
  final String title;
  final String kind;
  final String path;
  final String source;
  final String priority;
  final int division;
  final bool provisional;
  final bool eligible;
  final double? utilityScore;
  final int completedCycles;
  final double? lastCycleUtility;
  final DateTime? lastReviewedAt;
  final String reason;

  factory TigerReviewedFeature.fromJson(Map<String, dynamic> json) {
    return TigerReviewedFeature(
      slug: _asString(json['slug']),
      title: _asString(json['title']),
      kind: _asString(json['kind']),
      path: _asString(json['path']),
      source: _asString(json['source']),
      priority: _asString(json['priority']),
      division: _asInt(json['division']),
      provisional: json['provisional'] == true,
      eligible: json['eligible'] == true,
      utilityScore: _asDoubleOrNull(json['utility_score']),
      completedCycles: _asInt(json['completed_cycles']),
      lastCycleUtility: _asDoubleOrNull(json['last_cycle_utility']),
      lastReviewedAt: DateTime.tryParse(_asString(json['last_reviewed_at'])),
      reason: _asString(json['reason']),
    );
  }
}

class TigerReviewerStanding {
  const TigerReviewerStanding({
    required this.seat,
    required this.name,
    required this.tier,
    required this.division,
    required this.provisional,
    required this.eligible,
    required this.floorProtected,
    required this.utilityScore,
    required this.completedCycles,
    required this.lowUtilityStreak,
    required this.lastCycleUtility,
    required this.lastSelectedAt,
    required this.reason,
  });

  final int seat;
  final String name;
  final String tier;
  final int division;
  final bool provisional;
  final bool eligible;
  final bool floorProtected;
  final double? utilityScore;
  final int completedCycles;
  final int lowUtilityStreak;
  final double? lastCycleUtility;
  final DateTime? lastSelectedAt;
  final String reason;

  factory TigerReviewerStanding.fromJson(Map<String, dynamic> json) {
    return TigerReviewerStanding(
      seat: _asInt(json['seat']),
      name: _asString(json['name']),
      tier: _asString(json['tier']),
      division: _asInt(json['division']),
      provisional: json['provisional'] == true,
      eligible: json['eligible'] == true,
      floorProtected: json['floor_protected'] == true,
      utilityScore: _asDoubleOrNull(json['utility_score']),
      completedCycles: _asInt(json['completed_cycles']),
      lowUtilityStreak: _asInt(json['low_utility_streak']),
      lastCycleUtility: _asDoubleOrNull(json['last_cycle_utility']),
      lastSelectedAt: DateTime.tryParse(_asString(json['last_selected_at'])),
      reason: _asString(json['reason']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> _asList(Object? value) =>
    value is List<dynamic> ? value : const <dynamic>[];

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value) => value is num ? value.toInt() : 0;

double? _asDoubleOrNull(Object? value) =>
    value is num ? value.toDouble() : null;

import 'kgi_csf_kpi.dart';

enum FeatureStrategyStatus { onTrack, watch, improve }

enum FeatureLifeCapitalResource {
  time,
  money,
  health,
  stamina,
  intelligence,
  focus,
}

class FeatureStrategyFocusActionStats {
  static const int habitUnlockDays = 3;

  final String featureId;
  final int completedDaysLast7;
  final int deferredDaysLast7;
  final int currentStreakDays;
  final DateTime? lastCompletedAt;

  const FeatureStrategyFocusActionStats({
    required this.featureId,
    required this.completedDaysLast7,
    required this.deferredDaysLast7,
    required this.currentStreakDays,
    required this.lastCompletedAt,
  });

  factory FeatureStrategyFocusActionStats.empty(String featureId) {
    return FeatureStrategyFocusActionStats(
      featureId: featureId,
      completedDaysLast7: 0,
      deferredDaysLast7: 0,
      currentStreakDays: 0,
      lastCompletedAt: null,
    );
  }

  int get closedDaysLast7 => completedDaysLast7 + deferredDaysLast7;
  bool get hasHistory => closedDaysLast7 > 0 || currentStreakDays > 0;
  double get completionRateLast7 => completedDaysLast7 / 7;
  double get closeRateLast7 => closedDaysLast7 / 7;
  int get habitEvidenceDays => currentStreakDays > completedDaysLast7
      ? currentStreakDays
      : completedDaysLast7;
  int get remainingUnlockDays {
    final remaining = habitUnlockDays - habitEvidenceDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isHabitStable => remainingUnlockDays == 0;
  String get unlockStatusLabel =>
      isHabitStable ? '次へ進める' : '固定 あと$remainingUnlockDays日';
}

class FeatureStrategyCatalogItem {
  final String id;
  final String sectionId;
  final String title;
  final String subtitle;
  final List<String> keywords;
  final bool requiresClearDeck;

  const FeatureStrategyCatalogItem({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.keywords,
    this.requiresClearDeck = false,
  });
}

class FeatureStrategySignal {
  final String featureId;
  final String featureName;
  final String sectionId;
  final String sectionName;
  final bool requiresClearDeck;
  final DateTime monitoredAt;
  final FeatureStrategyStatus status;
  final KgiCsfKpiPlan plan;
  final String aiSummary;
  final String nextImprovement;
  final int metadataScore;
  final int recentUsageScore;
  final int improvementScore;
  final FeatureLifeCapitalResource lifeCapitalResource;
  final int wasteReductionScore;
  final String wasteReductionCsf;
  final String monitoringCadence;
  final FeatureStrategyFocusActionStats focusActionStats;

  const FeatureStrategySignal({
    required this.featureId,
    required this.featureName,
    required this.sectionId,
    required this.sectionName,
    required this.requiresClearDeck,
    required this.monitoredAt,
    required this.status,
    required this.plan,
    required this.aiSummary,
    required this.nextImprovement,
    required this.metadataScore,
    required this.recentUsageScore,
    required this.improvementScore,
    required this.lifeCapitalResource,
    required this.wasteReductionScore,
    required this.wasteReductionCsf,
    required this.monitoringCadence,
    required this.focusActionStats,
  });

  double get progress => plan.displayProgress;
}

class FeatureConsolidationCandidate {
  final String groupKey;
  final String canonicalFeatureName;
  final List<String> featureNames;
  final String sectionName;
  final String sharedAxis;
  final KgiCsfKpiPlan plan;

  const FeatureConsolidationCandidate({
    required this.groupKey,
    required this.canonicalFeatureName,
    required this.featureNames,
    required this.sectionName,
    required this.sharedAxis,
    required this.plan,
  });

  int get duplicateCount => featureNames.length;

  String get summary =>
      '$sharedAxis を軸に ${featureNames.join(' / ')} を $canonicalFeatureName へ統合候補化';
}

class FeatureLifeCapitalSummary {
  final FeatureLifeCapitalResource resource;
  final String label;
  final int featureCount;
  final int highImpactFeatureCount;
  final double averageProgress;
  final String topFeatureName;
  final String bottleneckFeatureName;
  final KgiCsfKpiPlan plan;

  const FeatureLifeCapitalSummary({
    required this.resource,
    required this.label,
    required this.featureCount,
    required this.highImpactFeatureCount,
    required this.averageProgress,
    required this.topFeatureName,
    required this.bottleneckFeatureName,
    required this.plan,
  });

  bool get hasCoverage => featureCount > 0;
}

class FeatureStrategyFocusRecommendation {
  final FeatureLifeCapitalResource resource;
  final String label;
  final String featureId;
  final String featureName;
  final String sectionName;
  final String csf;
  final String kpi;
  final String action;
  final String rationale;
  final String monitoringCadence;
  final double progress;
  final int parkedResourceCount;
  final int parkedFeatureCount;
  final FeatureStrategyFocusActionStats actionStats;
  final KgiCsfKpiPlan plan;

  const FeatureStrategyFocusRecommendation({
    required this.resource,
    required this.label,
    required this.featureId,
    required this.featureName,
    required this.sectionName,
    required this.csf,
    required this.kpi,
    required this.action,
    required this.rationale,
    required this.monitoringCadence,
    required this.progress,
    required this.parkedResourceCount,
    required this.parkedFeatureCount,
    required this.actionStats,
    required this.plan,
  });
}

class FeatureStrategyReport {
  final DateTime monitoredAt;
  final List<FeatureStrategySignal> signals;
  final List<FeatureConsolidationCandidate> consolidationCandidates;
  final List<FeatureLifeCapitalSummary> lifeCapitalSummaries;
  final FeatureStrategyFocusRecommendation? focusRecommendation;
  final KgiCsfKpiPlan portfolioPlan;

  const FeatureStrategyReport({
    required this.monitoredAt,
    required this.signals,
    required this.consolidationCandidates,
    required this.lifeCapitalSummaries,
    required this.focusRecommendation,
    required this.portfolioPlan,
  });

  factory FeatureStrategyReport.empty(DateTime monitoredAt) {
    return FeatureStrategyReport(
      monitoredAt: monitoredAt,
      signals: const <FeatureStrategySignal>[],
      consolidationCandidates: const <FeatureConsolidationCandidate>[],
      lifeCapitalSummaries: const <FeatureLifeCapitalSummary>[],
      focusRecommendation: null,
      portfolioPlan: const KgiCsfKpiPlan(
        domain: '全機能AI戦略',
        kgi: '全機能をAI分析とKGI/CSF/KPI監視に接続する',
        actualLabel: '0件',
        targetLabel: '0件',
        progress: 0,
        metrics: <KgiCsfKpiMetric>[],
      ),
    );
  }

  int get totalFeatures => signals.length;
  int get monitoredFeatures => signals.length;
  int get onTrackCount => _countByStatus(FeatureStrategyStatus.onTrack);
  int get watchCount => _countByStatus(FeatureStrategyStatus.watch);
  int get improveCount => _countByStatus(FeatureStrategyStatus.improve);
  int get consolidationCount => consolidationCandidates.length;
  int get highWasteReductionCount =>
      signals.where((signal) => signal.wasteReductionScore >= 3).length;
  int get focusActionsCompletedLast7 => signals.fold<int>(
        0,
        (sum, signal) => sum + signal.focusActionStats.completedDaysLast7,
      );
  int get focusActionsDeferredLast7 => signals.fold<int>(
        0,
        (sum, signal) => sum + signal.focusActionStats.deferredDaysLast7,
      );
  int get focusActionStreakDays => focusRecommendation == null
      ? 0
      : focusRecommendation!.actionStats.currentStreakDays;
  double get focusActionCompletionRateLast7 => signals.isEmpty
      ? 0
      : (focusActionsCompletedLast7 / 7).clamp(0, 1).toDouble();

  double get aiCoverageRatio =>
      totalFeatures == 0 ? 0 : monitoredFeatures / totalFeatures;
  double get lifeCapitalCoverageRatio => lifeCapitalSummaries.isEmpty
      ? 0
      : lifeCapitalSummaries.where((item) => item.hasCoverage).length /
          FeatureLifeCapitalResource.values.length;

  FeatureLifeCapitalSummary? get weakestLifeCapitalSummary {
    final covered =
        lifeCapitalSummaries.where((summary) => summary.hasCoverage).toList();
    if (covered.isEmpty) return null;
    covered.sort((a, b) => a.averageProgress.compareTo(b.averageProgress));
    return covered.first;
  }

  List<FeatureStrategySignal> get prioritySignals {
    final items = signals.where((signal) {
      return signal.status != FeatureStrategyStatus.onTrack;
    }).toList();
    items.sort((a, b) {
      final statusOrder = b.status.index.compareTo(a.status.index);
      if (statusOrder != 0) return statusOrder;
      return a.progress.compareTo(b.progress);
    });
    return items;
  }

  int _countByStatus(FeatureStrategyStatus status) {
    return signals.where((signal) => signal.status == status).length;
  }
}

class FeatureStrategyAiReview {
  final String summary;
  final String source;
  final DateTime generatedAt;
  final bool isFallback;

  const FeatureStrategyAiReview({
    required this.summary,
    required this.source,
    required this.generatedAt,
    this.isFallback = false,
  });

  factory FeatureStrategyAiReview.fallback({
    required FeatureStrategyReport report,
    required DateTime generatedAt,
    String? reason,
  }) {
    final reasonText =
        reason == null || reason.trim().isEmpty ? '' : ' $reason';
    return FeatureStrategyAiReview(
      generatedAt: generatedAt,
      source: 'local-kpi-engine',
      isFallback: true,
      summary:
          'AIレビュー待機中。${report.totalFeatures}機能をKGI/CSF/KPIで監視し、改善優先${report.improveCount}件、要観察${report.watchCount}件、統合候補${report.consolidationCount}件をローカル分析しています。$reasonText',
    );
  }
}

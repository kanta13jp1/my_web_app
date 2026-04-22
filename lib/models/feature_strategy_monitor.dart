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

class FeatureStrategyReport {
  final DateTime monitoredAt;
  final List<FeatureStrategySignal> signals;
  final List<FeatureConsolidationCandidate> consolidationCandidates;
  final List<FeatureLifeCapitalSummary> lifeCapitalSummaries;
  final KgiCsfKpiPlan portfolioPlan;

  const FeatureStrategyReport({
    required this.monitoredAt,
    required this.signals,
    required this.consolidationCandidates,
    required this.lifeCapitalSummaries,
    required this.portfolioPlan,
  });

  factory FeatureStrategyReport.empty(DateTime monitoredAt) {
    return FeatureStrategyReport(
      monitoredAt: monitoredAt,
      signals: const <FeatureStrategySignal>[],
      consolidationCandidates: const <FeatureConsolidationCandidate>[],
      lifeCapitalSummaries: const <FeatureLifeCapitalSummary>[],
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

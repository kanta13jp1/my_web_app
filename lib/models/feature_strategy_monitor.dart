import 'kgi_csf_kpi.dart';

enum FeatureStrategyStatus { onTrack, watch, improve }

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
  });

  double get progress => plan.displayProgress;
}

class FeatureStrategyReport {
  final DateTime monitoredAt;
  final List<FeatureStrategySignal> signals;
  final KgiCsfKpiPlan portfolioPlan;

  const FeatureStrategyReport({
    required this.monitoredAt,
    required this.signals,
    required this.portfolioPlan,
  });

  factory FeatureStrategyReport.empty(DateTime monitoredAt) {
    return FeatureStrategyReport(
      monitoredAt: monitoredAt,
      signals: const <FeatureStrategySignal>[],
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

  double get aiCoverageRatio =>
      totalFeatures == 0 ? 0 : monitoredFeatures / totalFeatures;

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
          'AIレビュー待機中。${report.totalFeatures}機能をKGI/CSF/KPIで監視し、改善優先${report.improveCount}件、要観察${report.watchCount}件をローカル分析しています。$reasonText',
    );
  }
}

import 'dart:math' as math;

import '../models/feature_strategy_monitor.dart';
import '../models/kgi_csf_kpi.dart';

class FeatureStrategyMonitorService {
  const FeatureStrategyMonitorService();

  FeatureStrategyReport buildReport({
    required List<FeatureStrategyCatalogItem> catalog,
    required List<String> recentToolIds,
    Map<String, String> sectionNamesById = const <String, String>{},
    DateTime? monitoredAt,
  }) {
    final checkedAt = monitoredAt ?? DateTime.now();
    final uniqueCatalog = _dedupeCatalog(catalog);
    final signals = uniqueCatalog.map((entry) {
      return _buildSignal(
        entry: entry,
        sectionName: sectionNamesById[entry.sectionId] ?? entry.sectionId,
        recentToolIds: recentToolIds,
        monitoredAt: checkedAt,
      );
    }).toList();

    return FeatureStrategyReport(
      monitoredAt: checkedAt,
      signals: signals,
      portfolioPlan: _buildPortfolioPlan(signals),
    );
  }

  List<FeatureStrategyCatalogItem> _dedupeCatalog(
    List<FeatureStrategyCatalogItem> catalog,
  ) {
    final seen = <String>{};
    final entries = <FeatureStrategyCatalogItem>[];
    for (final entry in catalog) {
      if (seen.add(entry.id)) {
        entries.add(entry);
      }
    }
    return entries;
  }

  FeatureStrategySignal _buildSignal({
    required FeatureStrategyCatalogItem entry,
    required String sectionName,
    required List<String> recentToolIds,
    required DateTime monitoredAt,
  }) {
    final metadataScore = _metadataScore(entry);
    final recentUsageScore = _recentUsageScore(entry.id, recentToolIds);
    const improvementScore = 1;
    final progress = _averageProgress(
      metadataScore / 3,
      recentUsageScore / 2,
      improvementScore,
    );
    final status = _resolveStatus(
      entry: entry,
      progress: progress,
      recentUsageScore: recentUsageScore,
    );
    final plan = KgiCsfKpiPlan(
      domain: '$sectionName / ${entry.title}',
      kgi: '${entry.title}をAI分析で成果に接続し、定期運用に載せる',
      actualLabel: '${(progress * 100).round()}%',
      targetLabel: '100%',
      progress: progress,
      metrics: <KgiCsfKpiMetric>[
        KgiCsfKpiMetric.number(
          csf: 'AI現状分析',
          kpi: '説明・導線・検索語の整備数',
          actual: metadataScore,
          target: 3,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '定期モニタリング',
          kpi: '直近利用シグナル',
          actual: recentUsageScore,
          target: 2,
          unit: '点',
        ),
        KgiCsfKpiMetric.number(
          csf: '改善サイクル',
          kpi: '次回改善アクション定義',
          actual: improvementScore,
          target: 1,
          unit: '件',
        ),
      ],
    );

    return FeatureStrategySignal(
      featureId: entry.id,
      featureName: entry.title,
      sectionId: entry.sectionId,
      sectionName: sectionName,
      requiresClearDeck: entry.requiresClearDeck,
      monitoredAt: monitoredAt,
      status: status,
      plan: plan,
      aiSummary: _buildAiSummary(
        entry: entry,
        sectionName: sectionName,
        recentUsageScore: recentUsageScore,
      ),
      nextImprovement: _buildNextImprovement(entry, recentUsageScore),
      metadataScore: metadataScore,
      recentUsageScore: recentUsageScore,
      improvementScore: improvementScore,
    );
  }

  int _metadataScore(FeatureStrategyCatalogItem entry) {
    var score = 0;
    if (entry.title.trim().isNotEmpty) score++;
    if (entry.subtitle.trim().isNotEmpty) score++;
    if (entry.keywords.isNotEmpty) score++;
    return score;
  }

  int _recentUsageScore(String featureId, List<String> recentToolIds) {
    final index = recentToolIds.indexOf(featureId);
    if (index == 0) return 2;
    if (index > 0) return 1;
    return 0;
  }

  double _averageProgress(num a, num b, num c) {
    return ((a + b + c) / 3).clamp(0, 1).toDouble();
  }

  FeatureStrategyStatus _resolveStatus({
    required FeatureStrategyCatalogItem entry,
    required double progress,
    required int recentUsageScore,
  }) {
    if (entry.requiresClearDeck && recentUsageScore == 0) {
      return FeatureStrategyStatus.improve;
    }
    if (progress >= 0.78) return FeatureStrategyStatus.onTrack;
    if (progress >= 0.58) return FeatureStrategyStatus.watch;
    return FeatureStrategyStatus.improve;
  }

  String _buildAiSummary({
    required FeatureStrategyCatalogItem entry,
    required String sectionName,
    required int recentUsageScore,
  }) {
    final usage = switch (recentUsageScore) {
      2 => '直近利用が強く、継続運用の候補です',
      1 => '直近利用があり、KPIを維持監視します',
      _ => '利用シグナルが薄く、価値仮説の再確認が必要です',
    };
    final keywords = entry.keywords.take(2).join(' / ');
    final axis = keywords.isEmpty ? sectionName : keywords;
    return 'AI分析: $usage。$axis を軸にKGI、CSF、数値KPIを同期します。';
  }

  String _buildNextImprovement(
    FeatureStrategyCatalogItem entry,
    int recentUsageScore,
  ) {
    if (entry.requiresClearDeck && recentUsageScore == 0) {
      return '固定枠から通常導線へ移す条件を決め、初回利用KPIを設定する';
    }
    if (recentUsageScore == 0) {
      return 'ホーム導線またはAI推薦で再露出し、次回利用を1回発生させる';
    }
    return '直近利用をもとに成果KPIを更新し、週次レビュー対象へ送る';
  }

  KgiCsfKpiPlan _buildPortfolioPlan(List<FeatureStrategySignal> signals) {
    final total = signals.length;
    if (total == 0) {
      return FeatureStrategyReport.empty(DateTime.now()).portfolioPlan;
    }

    final onTrack = signals
        .where((signal) => signal.status == FeatureStrategyStatus.onTrack)
        .length;
    final watch = signals
        .where((signal) => signal.status == FeatureStrategyStatus.watch)
        .length;
    final improve = signals
        .where((signal) => signal.status == FeatureStrategyStatus.improve)
        .length;
    final stable = onTrack + watch;
    final progress = signals
            .map((signal) => signal.progress)
            .fold<double>(0, (sum, value) => sum + value) /
        math.max(1, total);

    return KgiCsfKpiPlan(
      domain: '全機能AI戦略',
      kgi: '全機能をAI分析、KGI/CSF/KPI、定期モニタリング、改善に接続する',
      actualLabel: '$total/$total機能',
      targetLabel: '$total機能',
      progress: progress,
      metrics: <KgiCsfKpiMetric>[
        KgiCsfKpiMetric.number(
          csf: 'AI現状分析',
          kpi: 'KGI/CSF/KPI生成済み機能',
          actual: total,
          target: total,
          unit: '機能',
        ),
        KgiCsfKpiMetric.number(
          csf: '定期モニタリング',
          kpi: '順調または要観察で監視中の機能',
          actual: stable,
          target: total,
          unit: '機能',
        ),
        KgiCsfKpiMetric.number(
          csf: '改善サイクル',
          kpi: '改善優先からの脱出対象',
          actual: total - improve,
          target: total,
          unit: '機能',
        ),
      ],
    );
  }
}

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
    final consolidationCandidates = _buildConsolidationCandidates(
      catalog: uniqueCatalog,
      signals: signals,
      sectionNamesById: sectionNamesById,
    );
    final lifeCapitalSummaries = _buildLifeCapitalSummaries(signals);

    return FeatureStrategyReport(
      monitoredAt: checkedAt,
      signals: signals,
      consolidationCandidates: consolidationCandidates,
      lifeCapitalSummaries: lifeCapitalSummaries,
      portfolioPlan: _buildPortfolioPlan(
        signals,
        consolidationCandidates,
        lifeCapitalSummaries,
      ),
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
    final lifeCapitalResource = _inferLifeCapitalResource(entry);
    final wasteReductionScore = _wasteReductionScore(
      entry: entry,
      resource: lifeCapitalResource,
      recentUsageScore: recentUsageScore,
    );
    const improvementScore = 1;
    final progress = _averageProgress(
      metadataScore / 3,
      recentUsageScore / 2,
      improvementScore,
      wasteReductionScore / 5,
    );
    final status = _resolveStatus(
      entry: entry,
      progress: progress,
      recentUsageScore: recentUsageScore,
    );
    final plan = KgiCsfKpiPlan(
      domain: '$sectionName / ${entry.title}',
      kgi: '${entry.title}をAI分析で成果に接続し、定期運用に乗せる',
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
        KgiCsfKpiMetric.number(
          csf: _lifeCapitalCsf(lifeCapitalResource),
          kpi: '浪費削減スコア',
          actual: wasteReductionScore,
          target: 5,
          unit: '点',
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
      lifeCapitalResource: lifeCapitalResource,
      wasteReductionScore: wasteReductionScore,
      wasteReductionCsf: _lifeCapitalCsf(lifeCapitalResource),
      monitoringCadence: _monitoringCadence(entry, lifeCapitalResource),
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

  double _averageProgress(num a, num b, num c, num d) {
    return ((a + b + c + d) / 4).clamp(0, 1).toDouble();
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
      1 => '直近利用があり、KPIを継続監視します',
      _ => '利用シグナルが弱く、価値仮説の再確認が必要です',
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
      return '固定導線から通常導線へ移す条件を決め、初回利用KPIを設定する';
    }
    if (recentUsageScore == 0) {
      return 'ホーム導線またはAI推薦で再露出し、次回利用を1回発生させる';
    }
    return '直近利用をもとに成果KPIを更新し、週次レビュー対象へ送る';
  }

  FeatureLifeCapitalResource _inferLifeCapitalResource(
    FeatureStrategyCatalogItem entry,
  ) {
    final text = [
      entry.id,
      entry.sectionId,
      entry.title,
      entry.subtitle,
      ...entry.keywords,
    ].join(' ').toLowerCase();

    if (_containsAny(text, const [
      'asset',
      'money',
      'finance',
      'budget',
      'expense',
      'spend',
      'cash',
      '資産',
      'お金',
      '支出',
      '浪費',
      '家計',
      '予算',
    ])) {
      return FeatureLifeCapitalResource.money;
    }
    if (_containsAny(text, const [
      'health',
      'medical',
      'sleep',
      'meal',
      'body',
      '健康',
      '睡眠',
      '食事',
      '体調',
      '医療',
    ])) {
      return FeatureLifeCapitalResource.health;
    }
    if (_containsAny(text, const [
      'stamina',
      'energy',
      'workout',
      'exercise',
      'training',
      '体力',
      '運動',
      '疲労',
      '回復',
      '筋トレ',
    ])) {
      return FeatureLifeCapitalResource.stamina;
    }
    if (_containsAny(text, const [
      'learn',
      'study',
      'knowledge',
      'book',
      'ai',
      'research',
      '学習',
      '知識',
      '知能',
      '読書',
      '研究',
    ])) {
      return FeatureLifeCapitalResource.intelligence;
    }
    if (entry.requiresClearDeck ||
        _containsAny(text, const [
          'focus',
          'deep',
          'clear',
          '集中',
          '注意',
          '先延ばし',
          'タスク',
        ])) {
      return FeatureLifeCapitalResource.focus;
    }
    return FeatureLifeCapitalResource.time;
  }

  int _wasteReductionScore({
    required FeatureStrategyCatalogItem entry,
    required FeatureLifeCapitalResource resource,
    required int recentUsageScore,
  }) {
    var score = 1;
    if (entry.subtitle.trim().length >= 12) score++;
    if (entry.keywords.length >= 2) score++;
    if (recentUsageScore > 0) score++;
    if (entry.requiresClearDeck ||
        resource == FeatureLifeCapitalResource.money ||
        resource == FeatureLifeCapitalResource.focus) {
      score++;
    }
    return score.clamp(1, 5);
  }

  bool _containsAny(String text, List<String> values) {
    return values.any((value) => text.contains(value.toLowerCase()));
  }

  String _lifeCapitalLabel(FeatureLifeCapitalResource resource) {
    return switch (resource) {
      FeatureLifeCapitalResource.time => '時間',
      FeatureLifeCapitalResource.money => 'お金',
      FeatureLifeCapitalResource.health => '健康',
      FeatureLifeCapitalResource.stamina => '体力',
      FeatureLifeCapitalResource.intelligence => '知能',
      FeatureLifeCapitalResource.focus => '集中力',
    };
  }

  String _lifeCapitalCsf(FeatureLifeCapitalResource resource) {
    return switch (resource) {
      FeatureLifeCapitalResource.time => '着手までの摩擦を減らす',
      FeatureLifeCapitalResource.money => '能力を高めない支出を止める',
      FeatureLifeCapitalResource.health => '体調低下を早期に検知する',
      FeatureLifeCapitalResource.stamina => '消耗前に負荷を下げる',
      FeatureLifeCapitalResource.intelligence => '学習を成果物に変換する',
      FeatureLifeCapitalResource.focus => '注意散漫を入口で遮断する',
    };
  }

  String _lifeCapitalKpi(FeatureLifeCapitalResource resource) {
    return switch (resource) {
      FeatureLifeCapitalResource.time => '先延ばしせず開始できた機能数',
      FeatureLifeCapitalResource.money => '浪費を抑えて能力投資へ回した機能数',
      FeatureLifeCapitalResource.health => '体調悪化前に検知できる機能数',
      FeatureLifeCapitalResource.stamina => '消耗を抑えて継続できる機能数',
      FeatureLifeCapitalResource.intelligence => '学習成果を可視化できる機能数',
      FeatureLifeCapitalResource.focus => '集中を守る入口になっている機能数',
    };
  }

  String _monitoringCadence(
    FeatureStrategyCatalogItem entry,
    FeatureLifeCapitalResource resource,
  ) {
    if (entry.requiresClearDeck ||
        resource == FeatureLifeCapitalResource.focus ||
        resource == FeatureLifeCapitalResource.health) {
      return '毎日';
    }
    if (resource == FeatureLifeCapitalResource.money) {
      return '週2回';
    }
    return '週1回';
  }

  List<FeatureConsolidationCandidate> _buildConsolidationCandidates({
    required List<FeatureStrategyCatalogItem> catalog,
    required List<FeatureStrategySignal> signals,
    required Map<String, String> sectionNamesById,
  }) {
    final byId = {for (final signal in signals) signal.featureId: signal};
    final groups = <String, List<FeatureStrategyCatalogItem>>{};
    final axes = <String, String>{};

    for (final entry in catalog) {
      for (final axis in _candidateAxes(entry)) {
        final groupKey = '${entry.sectionId}:$axis';
        groups
            .putIfAbsent(groupKey, () => <FeatureStrategyCatalogItem>[])
            .add(entry);
        axes[groupKey] = axis;
      }
    }

    final candidates = <FeatureConsolidationCandidate>[];
    for (final entry in groups.entries) {
      final items = _uniqueItems(entry.value);
      if (items.length < 2) continue;

      items.sort((a, b) {
        final aSignal = byId[a.id];
        final bSignal = byId[b.id];
        final byProgress =
            (bSignal?.progress ?? 0).compareTo(aSignal?.progress ?? 0);
        if (byProgress != 0) return byProgress;
        return a.title.compareTo(b.title);
      });

      final canonical = items.first;
      final sectionName =
          sectionNamesById[canonical.sectionId] ?? canonical.sectionId;
      final duplicateCount = items.length;
      final plan = KgiCsfKpiPlan(
        domain: '$sectionName / 類似機能統合',
        kgi: '${canonical.title}へ似た機能を束ね、迷わず使える導線にする',
        actualLabel: '1統合案',
        targetLabel: '$duplicateCount機能整理',
        progress: 1 / duplicateCount,
        metrics: <KgiCsfKpiMetric>[
          KgiCsfKpiMetric.number(
            csf: '重複導線の削減',
            kpi: '統合候補に含まれる機能数',
            actual: duplicateCount,
            target: duplicateCount,
            unit: '機能',
          ),
          KgiCsfKpiMetric.number(
            csf: '代表機能の明確化',
            kpi: '代表導線の選定',
            actual: 1,
            target: 1,
            unit: '件',
          ),
          KgiCsfKpiMetric.number(
            csf: 'モニタリング継続',
            kpi: '次回レビューで統合判断する候補',
            actual: 1,
            target: duplicateCount,
            unit: '件',
          ),
        ],
      );

      candidates.add(
        FeatureConsolidationCandidate(
          groupKey: entry.key,
          canonicalFeatureName: canonical.title,
          featureNames: items.map((item) => item.title).toList(),
          sectionName: sectionName,
          sharedAxis: axes[entry.key] ?? '共通目的',
          plan: plan,
        ),
      );
    }

    candidates.sort((a, b) {
      final count = b.duplicateCount.compareTo(a.duplicateCount);
      if (count != 0) return count;
      return a.canonicalFeatureName.compareTo(b.canonicalFeatureName);
    });
    return candidates.take(8).toList(growable: false);
  }

  List<FeatureStrategyCatalogItem> _uniqueItems(
    List<FeatureStrategyCatalogItem> items,
  ) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.id)) item,
    ];
  }

  List<String> _candidateAxes(FeatureStrategyCatalogItem entry) {
    final axes = <String>{};
    for (final keyword in entry.keywords) {
      final normalized = _normalizeAxis(keyword);
      if (_isUsefulAxis(normalized)) {
        axes.add(normalized);
      }
    }
    return axes.take(3).toList(growable: false);
  }

  String _normalizeAxis(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s　_\-・/]+'), '').trim();
  }

  bool _isUsefulAxis(String axis) {
    if (axis.length < 2) return false;
    const stopwords = {
      'ai',
      'kpi',
      '管理',
      '分析',
      '自動',
      '機能',
      'ツール',
      'ダッシュボード',
      '検索',
      '共有',
      '提案',
      '生成',
      '作成',
      'メモ',
      'ノート',
      'タスク',
      '戦略',
      'dashboard',
      'tool',
    };
    return !stopwords.contains(axis);
  }

  List<FeatureLifeCapitalSummary> _buildLifeCapitalSummaries(
    List<FeatureStrategySignal> signals,
  ) {
    final targetPerResource = math.max(
      1,
      (signals.length / FeatureLifeCapitalResource.values.length).ceil(),
    );

    return [
      for (final resource in FeatureLifeCapitalResource.values)
        _buildLifeCapitalSummary(
          resource: resource,
          signals: signals
              .where((signal) => signal.lifeCapitalResource == resource)
              .toList(),
          targetPerResource: targetPerResource,
        ),
    ];
  }

  FeatureLifeCapitalSummary _buildLifeCapitalSummary({
    required FeatureLifeCapitalResource resource,
    required List<FeatureStrategySignal> signals,
    required int targetPerResource,
  }) {
    final label = _lifeCapitalLabel(resource);
    if (signals.isEmpty) {
      return FeatureLifeCapitalSummary(
        resource: resource,
        label: label,
        featureCount: 0,
        highImpactFeatureCount: 0,
        averageProgress: 0,
        topFeatureName: '未接続',
        bottleneckFeatureName: '未接続',
        plan: KgiCsfKpiPlan(
          domain: '$label / 浪費ゼロ',
          kgi: '$labelを浪費しない機能を少なくとも1つ接続する',
          actualLabel: '0機能',
          targetLabel: '1機能',
          progress: 0,
          metrics: <KgiCsfKpiMetric>[
            KgiCsfKpiMetric.number(
              csf: _lifeCapitalCsf(resource),
              kpi: _lifeCapitalKpi(resource),
              actual: 0,
              target: 1,
              unit: '機能',
            ),
          ],
        ),
      );
    }

    final sortedByProgress = [...signals]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final averageProgress = signals
            .map((signal) => signal.progress)
            .fold<double>(0, (sum, value) => sum + value) /
        signals.length;
    final highImpactCount =
        signals.where((signal) => signal.wasteReductionScore >= 3).length;
    final dailyCadenceCount =
        signals.where((signal) => signal.monitoringCadence == '毎日').length;

    return FeatureLifeCapitalSummary(
      resource: resource,
      label: label,
      featureCount: signals.length,
      highImpactFeatureCount: highImpactCount,
      averageProgress: averageProgress,
      topFeatureName: sortedByProgress.first.featureName,
      bottleneckFeatureName: sortedByProgress.last.featureName,
      plan: KgiCsfKpiPlan(
        domain: '$label / 浪費ゼロ',
        kgi: '$labelを浪費しない状態をAI分析とKGI/CSF/KPIで維持する',
        actualLabel: '$highImpactCount/${signals.length}機能',
        targetLabel: '${math.max(1, signals.length)}機能',
        progress: averageProgress,
        metrics: <KgiCsfKpiMetric>[
          KgiCsfKpiMetric.number(
            csf: _lifeCapitalCsf(resource),
            kpi: _lifeCapitalKpi(resource),
            actual: highImpactCount,
            target: math.max(1, signals.length),
            unit: '機能',
          ),
          KgiCsfKpiMetric.number(
            csf: '定期モニタリング',
            kpi: '毎日または週次で見直す機能数',
            actual: signals.length,
            target: targetPerResource,
            unit: '機能',
          ),
          KgiCsfKpiMetric.number(
            csf: '初期ハードルを下げる',
            kpi: '毎日モニタリング対象',
            actual: dailyCadenceCount,
            target: math.max(1, dailyCadenceCount),
            unit: '機能',
          ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildPortfolioPlan(
    List<FeatureStrategySignal> signals,
    List<FeatureConsolidationCandidate> consolidationCandidates,
    List<FeatureLifeCapitalSummary> lifeCapitalSummaries,
  ) {
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
    final consolidationTarget = math.max(1, consolidationCandidates.length);
    final coveredLifeCapitalCount =
        lifeCapitalSummaries.where((summary) => summary.hasCoverage).length;
    final highWasteReductionCount =
        signals.where((signal) => signal.wasteReductionScore >= 3).length;

    return KgiCsfKpiPlan(
      domain: '全機能AI戦略',
      kgi: '全機能をAI分析、KGI/CSF/KPI、定期モニタリング、改善に接続し、時間・お金・健康・体力・知能・集中力の浪費を減らす',
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
        KgiCsfKpiMetric.number(
          csf: 'ライフ資本の浪費削減',
          kpi: '時間・お金・健康・体力・知能・集中力の接続数',
          actual: coveredLifeCapitalCount,
          target: FeatureLifeCapitalResource.values.length,
          unit: '資本',
        ),
        KgiCsfKpiMetric.number(
          csf: '低ハードルから習慣化する',
          kpi: '浪費削減スコア3点以上の機能',
          actual: highWasteReductionCount,
          target: total,
          unit: '機能',
        ),
        KgiCsfKpiMetric.number(
          csf: '類似機能の抽象化',
          kpi: '統合候補をレビュー対象として可視化',
          actual: consolidationCandidates.length,
          target: consolidationTarget,
          unit: '候補',
        ),
      ],
    );
  }
}

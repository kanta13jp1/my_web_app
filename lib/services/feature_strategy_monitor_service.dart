import 'dart:math' as math;

import '../models/feature_strategy_monitor.dart';
import '../models/kgi_csf_kpi.dart';

class FeatureStrategyMonitorService {
  const FeatureStrategyMonitorService();

  FeatureStrategyReport buildReport({
    required List<FeatureStrategyCatalogItem> catalog,
    required List<String> recentToolIds,
    Map<String, String> sectionNamesById = const <String, String>{},
    Map<String, FeatureStrategyFocusActionStats> focusActionStatsByFeatureId =
        const <String, FeatureStrategyFocusActionStats>{},
    DateTime? monitoredAt,
  }) {
    final checkedAt = monitoredAt ?? DateTime.now();
    final uniqueCatalog = _dedupeCatalog(catalog);
    final signals = uniqueCatalog.map((entry) {
      return _buildSignal(
        entry: entry,
        sectionName: sectionNamesById[entry.sectionId] ?? entry.sectionId,
        recentToolIds: recentToolIds,
        focusActionStats: focusActionStatsByFeatureId[entry.id] ??
            FeatureStrategyFocusActionStats.empty(entry.id),
        monitoredAt: checkedAt,
      );
    }).toList();
    final consolidationCandidates = _buildConsolidationCandidates(
      catalog: uniqueCatalog,
      signals: signals,
      sectionNamesById: sectionNamesById,
    );
    final lifeCapitalSummaries = _buildLifeCapitalSummaries(signals);
    final lifeCapitalConsolidationLanes = _buildLifeCapitalConsolidationLanes(
      signals: signals,
      consolidationCandidates: consolidationCandidates,
    );
    final focusRecommendation = _buildFocusRecommendation(
      signals: signals,
      lifeCapitalSummaries: lifeCapitalSummaries,
    );
    final queuedFocusRecommendation = _buildQueuedFocusRecommendation(
      signals: signals,
      lifeCapitalSummaries: lifeCapitalSummaries,
      focusRecommendation: focusRecommendation,
    );

    return FeatureStrategyReport(
      monitoredAt: checkedAt,
      signals: signals,
      consolidationCandidates: consolidationCandidates,
      lifeCapitalSummaries: lifeCapitalSummaries,
      lifeCapitalConsolidationLanes: lifeCapitalConsolidationLanes,
      focusRecommendation: focusRecommendation,
      queuedFocusRecommendation: queuedFocusRecommendation,
      portfolioPlan: _buildPortfolioPlan(
        signals,
        consolidationCandidates,
        lifeCapitalSummaries,
        lifeCapitalConsolidationLanes,
        focusRecommendation,
        queuedFocusRecommendation,
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
    required FeatureStrategyFocusActionStats focusActionStats,
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
    final monitoringCadence = _monitoringCadence(entry, lifeCapitalResource);
    final monitoringIntervalDays = _monitoringIntervalDays(monitoringCadence);
    final lastReviewedAt = _lastReviewedAt(
      recentUsageScore: recentUsageScore,
      focusActionStats: focusActionStats,
      monitoredAt: monitoredAt,
    );
    final nextReviewAt = lastReviewedAt == null
        ? monitoredAt
        : lastReviewedAt.add(Duration(days: monitoringIntervalDays));
    final reviewDue = !nextReviewAt.isAfter(monitoredAt);
    final reviewOverdueDays = reviewDue
        ? math.max(0, monitoredAt.difference(nextReviewAt).inDays)
        : 0;
    final improvementScore = focusActionStats.hasHistory ? 2 : 1;
    final habitProgress = math.max(
      focusActionStats.closeRateLast7,
      math.min(1, focusActionStats.currentStreakDays / 3),
    );
    final progress = _averageProgress(
      metadataScore / 3,
      recentUsageScore / 2,
      improvementScore / 2,
      wasteReductionScore / 5,
      habitProgress,
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
          csf: '低ハードルから習慣化する',
          kpi: '7日内の1手完了',
          actual: focusActionStats.completedDaysLast7,
          target: 3,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '広げすぎを防ぐ',
          kpi: '7日内の完了または観察',
          actual: focusActionStats.closedDaysLast7,
          target: 5,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: _lifeCapitalCsf(lifeCapitalResource),
          kpi: '浪費削減スコア',
          actual: wasteReductionScore,
          target: 5,
          unit: '点',
        ),
        KgiCsfKpiMetric.number(
          csf: '定期的なモニタリングと改善',
          kpi: '$monitoringCadenceレビュー期限の遵守',
          actual: reviewDue ? 0 : 1,
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
      lifeCapitalResource: lifeCapitalResource,
      wasteReductionScore: wasteReductionScore,
      wasteReductionCsf: _lifeCapitalCsf(lifeCapitalResource),
      monitoringCadence: monitoringCadence,
      monitoringIntervalDays: monitoringIntervalDays,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: nextReviewAt,
      reviewDue: reviewDue,
      reviewOverdueDays: reviewOverdueDays,
      focusActionStats: focusActionStats,
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

  double _averageProgress(num a, num b, num c, num d, num e) {
    return ((a + b + c + d + e) / 5).clamp(0, 1).toDouble();
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

  int _monitoringIntervalDays(String cadence) {
    return switch (cadence) {
      '毎日' => 1,
      '週2回' => 3,
      _ => 7,
    };
  }

  DateTime? _lastReviewedAt({
    required int recentUsageScore,
    required FeatureStrategyFocusActionStats focusActionStats,
    required DateTime monitoredAt,
  }) {
    final completedAt = focusActionStats.lastCompletedAt;
    if (completedAt != null) {
      return completedAt;
    }
    if (recentUsageScore > 0) {
      return monitoredAt;
    }
    return null;
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
        final groupKey = 'axis:$axis';
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
      final sectionNames = _sectionNamesFor(items, sectionNamesById);
      final duplicateCount = items.length;
      final estimatedWasteMinutesSaved =
          _estimatedConsolidationWasteMinutesSaved(items);
      final sharedAxis = axes[entry.key] ?? '共通目的';
      final consolidationAction = _buildConsolidationAction(
        canonical: canonical,
        items: items,
        sharedAxis: sharedAxis,
      );
      final plan = KgiCsfKpiPlan(
        domain: '${sectionNames.join(' / ')} / 類似機能統合',
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
          KgiCsfKpiMetric.number(
            csf: '時間と集中力の浪費削減',
            kpi: '導線迷い削減の見込み時間',
            actual: estimatedWasteMinutesSaved,
            target: math.max(15, estimatedWasteMinutesSaved),
            unit: '分',
          ),
        ],
      );

      candidates.add(
        FeatureConsolidationCandidate(
          groupKey: entry.key,
          canonicalFeatureId: canonical.id,
          canonicalFeatureName: canonical.title,
          featureIds: items.map((item) => item.id).toList(),
          featureNames: items.map((item) => item.title).toList(),
          sectionNames: sectionNames,
          sectionName: sectionName,
          sharedAxis: sharedAxis,
          consolidationAction: consolidationAction,
          estimatedWasteMinutesSaved: estimatedWasteMinutesSaved,
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

  List<String> _sectionNamesFor(
    List<FeatureStrategyCatalogItem> items,
    Map<String, String> sectionNamesById,
  ) {
    final names = <String>{};
    for (final item in items) {
      names.add(sectionNamesById[item.sectionId] ?? item.sectionId);
    }
    return names.toList(growable: false)..sort();
  }

  int _estimatedConsolidationWasteMinutesSaved(
    List<FeatureStrategyCatalogItem> items,
  ) {
    final duplicateCount = math.max(0, items.length - 1);
    final clearDeckCount = items.where((item) => item.requiresClearDeck).length;
    final keywordSpread = items
        .expand((item) => item.keywords)
        .map(_normalizeAxis)
        .where(_isUsefulAxis)
        .toSet()
        .length;
    return duplicateCount * 8 + clearDeckCount * 4 + math.min(8, keywordSpread);
  }

  String _buildConsolidationAction({
    required FeatureStrategyCatalogItem canonical,
    required List<FeatureStrategyCatalogItem> items,
    required String sharedAxis,
  }) {
    final secondaryNames = items
        .where((item) => item.id != canonical.id)
        .map((item) => item.title)
        .toList(growable: false);
    final secondaryLabel =
        secondaryNames.isEmpty ? '類似導線' : secondaryNames.join(' / ');
    return '$sharedAxis を代表軸に、$secondaryLabel は ${canonical.title} のサブ導線・別名として扱い、KGI/CSF/KPIとAIレビューは1機能へ集約する';
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

  List<FeatureLifeCapitalConsolidationLane>
      _buildLifeCapitalConsolidationLanes({
    required List<FeatureStrategySignal> signals,
    required List<FeatureConsolidationCandidate> consolidationCandidates,
  }) {
    final signalsById = {
      for (final signal in signals) signal.featureId: signal,
    };
    return [
      for (final resource in FeatureLifeCapitalResource.values)
        _buildLifeCapitalConsolidationLane(
          resource: resource,
          signals: signals,
          signalsById: signalsById,
          consolidationCandidates: consolidationCandidates,
        ),
    ];
  }

  FeatureLifeCapitalConsolidationLane _buildLifeCapitalConsolidationLane({
    required FeatureLifeCapitalResource resource,
    required List<FeatureStrategySignal> signals,
    required Map<String, FeatureStrategySignal> signalsById,
    required List<FeatureConsolidationCandidate> consolidationCandidates,
  }) {
    final label = _lifeCapitalLabel(resource);
    final resourceSignals = signals
        .where((signal) => signal.lifeCapitalResource == resource)
        .toList();
    if (resourceSignals.isEmpty) {
      return FeatureLifeCapitalConsolidationLane(
        resource: resource,
        label: label,
        canonicalFeatureId: '',
        canonicalFeatureName: '未接続',
        featureIds: const <String>[],
        featureNames: const <String>[],
        consolidationCandidateCount: 0,
        estimatedWasteMinutesSaved: 0,
        nextAction: '$labelを守る既存機能を1つ選び、KGI/CSF/KPIへ接続する',
        plan: KgiCsfKpiPlan(
          domain: '$label / 代表導線レーン',
          kgi: '$labelを浪費しない入口を1つに束ねる',
          actualLabel: '0機能',
          targetLabel: '1代表導線',
          progress: 0,
          metrics: <KgiCsfKpiMetric>[
            KgiCsfKpiMetric.number(
              csf: '代表導線を作る',
              kpi: '接続済み機能',
              actual: 0,
              target: 1,
              unit: '機能',
            ),
          ],
        ),
      );
    }

    final resourceIds =
        resourceSignals.map((signal) => signal.featureId).toSet();
    final resourceCandidates = consolidationCandidates
        .where((candidate) => candidate.featureIds.any(resourceIds.contains))
        .toList();
    final laneFeatureIds = <String>{};
    for (final candidate in resourceCandidates) {
      for (final featureId in candidate.featureIds) {
        if (resourceIds.contains(featureId)) {
          laneFeatureIds.add(featureId);
        }
      }
    }
    final rankedSignals = [...resourceSignals]..sort((a, b) {
        final byProgress = b.progress.compareTo(a.progress);
        if (byProgress != 0) return byProgress;
        final byUsage = b.recentUsageScore.compareTo(a.recentUsageScore);
        if (byUsage != 0) return byUsage;
        return a.featureName.compareTo(b.featureName);
      });
    final canonicalSignal = _canonicalSignalForLane(
      rankedSignals: rankedSignals,
      laneFeatureIds: laneFeatureIds,
      resourceIds: resourceIds,
      resourceCandidates: resourceCandidates,
      signalsById: signalsById,
    );
    laneFeatureIds.add(canonicalSignal.featureId);

    final featureIds = laneFeatureIds.toList(growable: false)..sort();
    final featureNames = featureIds
        .map((featureId) => signalsById[featureId]?.featureName ?? featureId)
        .toList(growable: false);
    final estimatedWasteMinutesSaved = resourceCandidates.fold<int>(
      0,
      (sum, candidate) => sum + candidate.estimatedWasteMinutesSaved,
    );
    final improvementCount = resourceSignals
        .where((signal) => signal.status != FeatureStrategyStatus.onTrack)
        .length;
    final laneCoverageProgress =
        (featureIds.length / resourceSignals.length).clamp(0, 1).toDouble();
    final savedProgress =
        (estimatedWasteMinutesSaved / 15).clamp(0, 1).toDouble();
    final stableProgress =
        ((resourceSignals.length - improvementCount) / resourceSignals.length)
            .clamp(0, 1)
            .toDouble();
    final progress = _averageProgress(
      canonicalSignal.progress,
      laneCoverageProgress,
      resourceCandidates.isEmpty ? 0.5 : 1,
      savedProgress,
      stableProgress,
    );
    final candidateCount = resourceCandidates.length;
    final nextAction = candidateCount == 0
        ? '$labelは${canonicalSignal.featureName}を代表入口として固定し、他機能はこのKGI/CSF/KPIのサブ導線として扱う'
        : '$labelは${canonicalSignal.featureName}へ${featureNames.join(' / ')}を束ね、導線迷いを$estimatedWasteMinutesSaved分削減する';

    return FeatureLifeCapitalConsolidationLane(
      resource: resource,
      label: label,
      canonicalFeatureId: canonicalSignal.featureId,
      canonicalFeatureName: canonicalSignal.featureName,
      featureIds: featureIds,
      featureNames: featureNames,
      consolidationCandidateCount: candidateCount,
      estimatedWasteMinutesSaved: estimatedWasteMinutesSaved,
      nextAction: nextAction,
      plan: KgiCsfKpiPlan(
        domain: '$label / 代表導線レーン',
        kgi: '$labelを浪費しない入口を${canonicalSignal.featureName}へ集約する',
        actualLabel: '${featureIds.length}/${resourceSignals.length}機能',
        targetLabel: '1代表導線',
        progress: progress,
        metrics: <KgiCsfKpiMetric>[
          KgiCsfKpiMetric.number(
            csf: '代表導線の固定',
            kpi: '代表機能の選定',
            actual: 1,
            target: 1,
            unit: '件',
          ),
          KgiCsfKpiMetric.number(
            csf: '重複導線の圧縮',
            kpi: '代表レーンに束ねた機能',
            actual: featureIds.length,
            target: resourceSignals.length,
            unit: '機能',
          ),
          KgiCsfKpiMetric.number(
            csf: '生命資本の浪費削減',
            kpi: '導線迷い削減の見込み時間',
            actual: estimatedWasteMinutesSaved,
            target: math.max(15, estimatedWasteMinutesSaved),
            unit: '分',
          ),
          KgiCsfKpiMetric.number(
            csf: '低ハードル改善',
            kpi: '改善優先を残さない機能',
            actual: resourceSignals.length - improvementCount,
            target: resourceSignals.length,
            unit: '機能',
          ),
        ],
      ),
    );
  }

  FeatureStrategySignal _canonicalSignalForLane({
    required List<FeatureStrategySignal> rankedSignals,
    required Set<String> laneFeatureIds,
    required Set<String> resourceIds,
    required List<FeatureConsolidationCandidate> resourceCandidates,
    required Map<String, FeatureStrategySignal> signalsById,
  }) {
    for (final candidate in resourceCandidates) {
      final canonical = signalsById[candidate.canonicalFeatureId];
      if (canonical != null && resourceIds.contains(canonical.featureId)) {
        return canonical;
      }
    }
    for (final signal in rankedSignals) {
      if (laneFeatureIds.contains(signal.featureId)) {
        return signal;
      }
    }
    return rankedSignals.first;
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

  FeatureStrategyFocusRecommendation? _buildFocusRecommendation({
    required List<FeatureStrategySignal> signals,
    required List<FeatureLifeCapitalSummary> lifeCapitalSummaries,
  }) {
    final coveredSummaries =
        lifeCapitalSummaries.where((summary) => summary.hasCoverage).toList()
          ..sort((a, b) {
            final byProgress = a.averageProgress.compareTo(b.averageProgress);
            if (byProgress != 0) return byProgress;
            return a.featureCount.compareTo(b.featureCount);
          });
    if (coveredSummaries.isEmpty) return null;

    final activeUnstableSignals = signals
        .where(
          (signal) =>
              signal.focusActionStats.hasHistory &&
              !signal.focusActionStats.isHabitStable,
        )
        .toList()
      ..sort((a, b) {
        final byEvidence = b.focusActionStats.habitEvidenceDays
            .compareTo(a.focusActionStats.habitEvidenceDays);
        if (byEvidence != 0) return byEvidence;
        final byClosed = b.focusActionStats.closedDaysLast7
            .compareTo(a.focusActionStats.closedDaysLast7);
        if (byClosed != 0) return byClosed;
        return a.progress.compareTo(b.progress);
      });
    final signal =
        activeUnstableSignals.isNotEmpty ? activeUnstableSignals.first : null;
    final targetSummary = signal == null
        ? coveredSummaries.first
        : coveredSummaries.firstWhere(
            (summary) => summary.resource == signal.lifeCapitalResource,
            orElse: () => coveredSummaries.first,
          );
    final candidates = signal == null
        ? (signals
            .where(
              (item) => item.lifeCapitalResource == targetSummary.resource,
            )
            .toList()
          ..sort((a, b) {
            final byHurdle =
                _focusHurdleScore(b).compareTo(_focusHurdleScore(a));
            if (byHurdle != 0) return byHurdle;
            return a.progress.compareTo(b.progress);
          }))
        : <FeatureStrategySignal>[signal];
    if (candidates.isEmpty) return null;

    final selectedSignal = candidates.first;
    final parkedResourceCount = math.max(0, coveredSummaries.length - 1);
    final parkedFeatureCount = signals
        .where(
          (item) =>
              item.lifeCapitalResource != selectedSignal.lifeCapitalResource,
        )
        .length;
    final action = _buildFocusAction(selectedSignal);
    final actionStats = selectedSignal.focusActionStats;
    final gateText = actionStats.isHabitStable
        ? '3日分の定着条件を満たしたため、次の資本へ広げられます。'
        : '習慣化の解放条件まであと${actionStats.remainingUnlockDays}日です。新しい継続タスクは追加せず、この1手を固定します。';
    final historyText = actionStats.hasHistory
        ? '直近7日で完了${actionStats.completedDaysLast7}日、観察${actionStats.deferredDaysLast7}日、継続${actionStats.currentStreakDays}日です。'
        : 'まだ完了履歴がないため、今日の1手を最初の習慣化ログにします。';
    final rationale =
        '${targetSummary.label}の平均進捗が最も低いため、${selectedSignal.featureName}だけを先に習慣化します。他の資本は観察に回します。$historyText$gateText';

    return FeatureStrategyFocusRecommendation(
      resource: selectedSignal.lifeCapitalResource,
      label: targetSummary.label,
      featureId: selectedSignal.featureId,
      featureName: selectedSignal.featureName,
      sectionName: selectedSignal.sectionName,
      csf: selectedSignal.wasteReductionCsf,
      kpi: '今日の低ハードル実行 1回',
      action: action,
      rationale: rationale,
      monitoringCadence: selectedSignal.monitoringCadence,
      progress: selectedSignal.progress,
      parkedResourceCount: parkedResourceCount,
      parkedFeatureCount: parkedFeatureCount,
      actionStats: actionStats,
      plan: KgiCsfKpiPlan(
        domain: '${targetSummary.label} / 今日の1手',
        kgi: '${targetSummary.label}の浪費を減らす入口を1つだけ習慣化する',
        actualLabel: '${actionStats.completedDaysLast7}日完了',
        targetLabel: '7日中3日',
        progress: selectedSignal.progress,
        metrics: <KgiCsfKpiMetric>[
          KgiCsfKpiMetric.number(
            csf: selectedSignal.wasteReductionCsf,
            kpi: '今日実行する低ハードル行動',
            actual: 1,
            target: 1,
            unit: '件',
          ),
          KgiCsfKpiMetric.number(
            csf: '習慣化まで広げない',
            kpi: '7日内の1手完了',
            actual: actionStats.completedDaysLast7,
            target: 3,
            unit: '日',
          ),
          KgiCsfKpiMetric.number(
            csf: '定期モニタリング',
            kpi: '現在の継続日数',
            actual: actionStats.currentStreakDays,
            target: 3,
            unit: '日',
          ),
          KgiCsfKpiMetric.number(
            csf: '定着後に次へ進む',
            kpi: '解放条件の達成日数',
            actual: actionStats.habitEvidenceDays,
            target: FeatureStrategyFocusActionStats.habitUnlockDays,
            unit: '日',
          ),
          KgiCsfKpiMetric.number(
            csf: '同時進行を止める',
            kpi: '観察に回した資本',
            actual: parkedResourceCount,
            target: parkedResourceCount,
            unit: '資本',
          ),
          KgiCsfKpiMetric.number(
            csf: '定期モニタリング',
            kpi: '${selectedSignal.monitoringCadence}レビュー対象',
            actual: 1,
            target: 1,
            unit: '件',
          ),
        ],
      ),
    );
  }

  int _focusHurdleScore(FeatureStrategySignal signal) {
    var score = signal.recentUsageScore * 30 + signal.metadataScore * 10;
    if (!signal.requiresClearDeck) score += 20;
    if (signal.status == FeatureStrategyStatus.watch) score += 8;
    if (signal.status == FeatureStrategyStatus.improve) score += 4;
    score += math.max(0, 5 - signal.wasteReductionScore);
    return score;
  }

  String _buildFocusAction(FeatureStrategySignal signal) {
    if (signal.recentUsageScore == 0) {
      return '${signal.featureName}を今日1回だけ開き、最初の入力または確認を1つ完了する';
    }
    if (signal.status == FeatureStrategyStatus.improve) {
      return '${signal.featureName}の改善KPIを5分だけ見直し、次回の1アクションを保存する';
    }
    return '${signal.featureName}を今日の通常導線で1回使い、成果KPIを更新する';
  }

  FeatureStrategyQueuedRecommendation? _buildQueuedFocusRecommendation({
    required List<FeatureStrategySignal> signals,
    required List<FeatureLifeCapitalSummary> lifeCapitalSummaries,
    required FeatureStrategyFocusRecommendation? focusRecommendation,
  }) {
    if (focusRecommendation == null) return null;

    final coveredSummaries =
        lifeCapitalSummaries.where((summary) => summary.hasCoverage).toList()
          ..sort((a, b) {
            final byProgress = a.averageProgress.compareTo(b.averageProgress);
            if (byProgress != 0) return byProgress;
            return a.featureCount.compareTo(b.featureCount);
          });
    if (coveredSummaries.isEmpty) return null;

    final preferredSummary = coveredSummaries.firstWhere(
      (summary) => summary.resource != focusRecommendation.resource,
      orElse: () => coveredSummaries.first,
    );
    var candidates = signals
        .where((signal) => signal.featureId != focusRecommendation.featureId)
        .where(
          (signal) => signal.lifeCapitalResource == preferredSummary.resource,
        )
        .toList();
    if (candidates.isEmpty) {
      candidates = signals
          .where((signal) => signal.featureId != focusRecommendation.featureId)
          .toList();
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byHurdle = _focusHurdleScore(b).compareTo(_focusHurdleScore(a));
      if (byHurdle != 0) return byHurdle;
      return a.progress.compareTo(b.progress);
    });
    final queuedSignal = candidates.first;
    final targetSummary = coveredSummaries.firstWhere(
      (summary) => summary.resource == queuedSignal.lifeCapitalResource,
      orElse: () => preferredSummary,
    );
    final unlockCondition = focusRecommendation.actionStats.isHabitStable
        ? '現在の1手は解放済みです。次はこの候補へ進めます。'
        : '現在の1手が${FeatureStrategyFocusActionStats.habitUnlockDays}日定着したら、この候補を開放します。';
    final rationale =
        '${targetSummary.label}は次に着手する生命資本候補です。${focusRecommendation.featureName}が定着するまでは待機し、解放後に${queuedSignal.featureName}へ移ります。';

    return FeatureStrategyQueuedRecommendation(
      resource: queuedSignal.lifeCapitalResource,
      label: targetSummary.label,
      featureId: queuedSignal.featureId,
      featureName: queuedSignal.featureName,
      sectionName: queuedSignal.sectionName,
      action: _buildFocusAction(queuedSignal),
      rationale: rationale,
      unlockCondition: unlockCondition,
      plan: KgiCsfKpiPlan(
        domain: '${targetSummary.label} / 解放後の次候補',
        kgi: '現在の1手が定着したら、次の生命資本へ無理なく移行する',
        actualLabel:
            focusRecommendation.actionStats.isHabitStable ? '解放済み' : '待機中',
        targetLabel: queuedSignal.featureName,
        progress: focusRecommendation.actionStats.isHabitStable ? 1 : 0,
        metrics: <KgiCsfKpiMetric>[
          KgiCsfKpiMetric.number(
            csf: '習慣化まで広げない',
            kpi: '解放条件の必要日数',
            actual: focusRecommendation.actionStats.habitEvidenceDays,
            target: FeatureStrategyFocusActionStats.habitUnlockDays,
            unit: '日',
          ),
          KgiCsfKpiMetric.number(
            csf: '定着後に次へ進む',
            kpi: '待機中の次候補',
            actual: 1,
            target: 1,
            unit: '件',
          ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildPortfolioPlan(
    List<FeatureStrategySignal> signals,
    List<FeatureConsolidationCandidate> consolidationCandidates,
    List<FeatureLifeCapitalSummary> lifeCapitalSummaries,
    List<FeatureLifeCapitalConsolidationLane> lifeCapitalConsolidationLanes,
    FeatureStrategyFocusRecommendation? focusRecommendation,
    FeatureStrategyQueuedRecommendation? queuedFocusRecommendation,
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
    final consolidationSavedMinutes = consolidationCandidates.fold<int>(
      0,
      (sum, candidate) => sum + candidate.estimatedWasteMinutesSaved,
    );
    final lifeCapitalLaneCount =
        lifeCapitalConsolidationLanes.where((lane) => lane.hasFeatures).length;
    final lifeCapitalLaneWasteSavedMinutes =
        lifeCapitalConsolidationLanes.fold<int>(
      0,
      (sum, lane) => sum + lane.estimatedWasteMinutesSaved,
    );
    final coveredLifeCapitalCount =
        lifeCapitalSummaries.where((summary) => summary.hasCoverage).length;
    final highWasteReductionCount =
        signals.where((signal) => signal.wasteReductionScore >= 3).length;
    final focusSelected = focusRecommendation == null ? 0 : 1;
    final completedFocusActionsLast7 = signals.fold<int>(
      0,
      (sum, signal) => sum + signal.focusActionStats.completedDaysLast7,
    );
    final closedFocusActionsLast7 = signals.fold<int>(
      0,
      (sum, signal) => sum + signal.focusActionStats.closedDaysLast7,
    );
    final selectedFocusStreak =
        focusRecommendation?.actionStats.currentStreakDays ?? 0;
    final selectedFocusEvidence =
        focusRecommendation?.actionStats.habitEvidenceDays ?? 0;
    final queuedFocusReady = queuedFocusRecommendation == null
        ? 0
        : (focusRecommendation?.actionStats.isHabitStable ?? false)
            ? 1
            : 0;
    final reviewDueCount = signals.where((signal) => signal.reviewDue).length;
    final reviewOverdueCount =
        signals.where((signal) => signal.reviewOverdueDays > 0).length;
    final reviewCompliantCount = math.max(0, total - reviewDueCount);

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
          csf: '定期的なモニタリングと改善',
          kpi: 'レビュー期限を守れている機能',
          actual: reviewCompliantCount,
          target: total,
          unit: '機能',
        ),
        KgiCsfKpiMetric.number(
          csf: '定期的なモニタリングと改善',
          kpi: '期限超過レビューの解消',
          actual: total - reviewOverdueCount,
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
          csf: '生命資本別に抽象化する',
          kpi: '生命資本別の代表導線レーン',
          actual: lifeCapitalLaneCount,
          target: FeatureLifeCapitalResource.values.length,
          unit: '資本',
        ),
        KgiCsfKpiMetric.number(
          csf: '生命資本別に抽象化する',
          kpi: '代表レーンで減らせる導線迷い時間',
          actual: lifeCapitalLaneWasteSavedMinutes,
          target: math.max(15, lifeCapitalLaneWasteSavedMinutes),
          unit: '分',
        ),
        KgiCsfKpiMetric.number(
          csf: '低ハードルから習慣化する',
          kpi: '浪費削減スコア3点以上の機能',
          actual: highWasteReductionCount,
          target: total,
          unit: '機能',
        ),
        KgiCsfKpiMetric.number(
          csf: '同時進行を止める',
          kpi: '今日の低ハードル1手の選定',
          actual: focusSelected,
          target: 1,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '習慣化まで広げない',
          kpi: '7日内の低ハードル完了',
          actual: completedFocusActionsLast7,
          target: 3,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '定期的なモニタリングと改善',
          kpi: '7日内の完了または観察',
          actual: closedFocusActionsLast7,
          target: 5,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '定着後に次へ進む',
          kpi: '選定中1手の継続日数',
          actual: selectedFocusStreak,
          target: 3,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '解放条件を満たすまで固定',
          kpi: '次へ進むための習慣化証跡',
          actual: selectedFocusEvidence,
          target: FeatureStrategyFocusActionStats.habitUnlockDays,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '定着後に次へ進む',
          kpi: '解放後の次候補キュー',
          actual: queuedFocusRecommendation == null ? 0 : 1,
          target: 1,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '定着後に次へ進む',
          kpi: '次候補の解放準備',
          actual: queuedFocusReady,
          target: queuedFocusRecommendation == null ? 0 : 1,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '類似機能の抽象化',
          kpi: '統合候補をレビュー対象として可視化',
          actual: consolidationCandidates.length,
          target: consolidationTarget,
          unit: '候補',
        ),
        KgiCsfKpiMetric.number(
          csf: '類似機能の抽象化',
          kpi: '統合で減らせる導線迷い時間',
          actual: consolidationSavedMinutes,
          target: math.max(15, consolidationSavedMinutes),
          unit: '分',
        ),
      ],
    );
  }
}

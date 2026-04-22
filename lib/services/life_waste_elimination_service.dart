import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kgi_csf_kpi.dart';
import 'ai_hub_chat_service.dart';

enum LifeWasteResource {
  time,
  money,
  health,
  stamina,
  intelligence,
  focus,
}

String _dateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse('$value') ?? 0;
}

LifeWasteResource? _resourceByName(String name) {
  for (final resource in LifeWasteResource.values) {
    if (resource.name == name) {
      return resource;
    }
  }
  return null;
}

String _resourceLabel(LifeWasteResource resource) {
  return switch (resource) {
    LifeWasteResource.time => '時間',
    LifeWasteResource.money => 'お金',
    LifeWasteResource.health => '健康',
    LifeWasteResource.stamina => '体力',
    LifeWasteResource.intelligence => '知能',
    LifeWasteResource.focus => '集中力',
  };
}

class LifeWasteResourceSignal {
  final LifeWasteResource resource;
  final String label;
  final String csf;
  final String kpi;
  final num actual;
  final num target;
  final String unit;
  final String currentLabel;
  final String nextAction;

  const LifeWasteResourceSignal({
    required this.resource,
    required this.label,
    required this.csf,
    required this.kpi,
    required this.actual,
    required this.target,
    required this.unit,
    required this.currentLabel,
    required this.nextAction,
  });

  double get progress {
    if (target <= 0) return 0;
    return (actual / target).clamp(0, 1).toDouble();
  }

  bool get needsIntervention => progress < 0.8;
}

class LifeWasteEliminationReport {
  final DateTime monitoredAt;
  final List<LifeWasteResourceSignal> signals;
  final KgiCsfKpiPlan plan;

  const LifeWasteEliminationReport({
    required this.monitoredAt,
    required this.signals,
    required this.plan,
  });

  int get wasteFreeScore => (plan.displayProgress * 100).round();

  List<LifeWasteResourceSignal> get prioritySignals {
    final items = List<LifeWasteResourceSignal>.from(signals);
    items.sort((a, b) => a.progress.compareTo(b.progress));
    return items;
  }

  String get nextAction => prioritySignals.first.nextAction;

  String get cacheKey => [
        monitoredAt.year,
        monitoredAt.month,
        monitoredAt.day,
        for (final signal in signals)
          '${signal.resource.name}:${signal.actual}/${signal.target}',
      ].join('|');
}

class LifeWasteAiReview {
  final String summary;
  final String source;
  final DateTime generatedAt;
  final bool isFallback;

  const LifeWasteAiReview({
    required this.summary,
    required this.source,
    required this.generatedAt,
    this.isFallback = false,
  });

  factory LifeWasteAiReview.fallback({
    required LifeWasteEliminationReport report,
    required DateTime generatedAt,
    String? reason,
  }) {
    final reasonText =
        reason == null || reason.trim().isEmpty ? '' : ' $reason';
    final top = report.prioritySignals.first;
    return LifeWasteAiReview(
      summary:
          'AIレビュー待機中$reasonText。生命資本スコアは${report.wasteFreeScore}点、最優先CSFは「${top.csf}」です。次は「${top.nextAction}」を実行してください。',
      source: 'local-kpi-engine',
      generatedAt: generatedAt,
      isFallback: true,
    );
  }
}

class LifeWasteDailySnapshot {
  final String dateKey;
  final DateTime monitoredAt;
  final int wasteFreeScore;
  final Map<LifeWasteResource, int> resourceScores;
  final LifeWasteResource priorityResource;
  final String nextAction;

  const LifeWasteDailySnapshot({
    required this.dateKey,
    required this.monitoredAt,
    required this.wasteFreeScore,
    required this.resourceScores,
    required this.priorityResource,
    required this.nextAction,
  });

  factory LifeWasteDailySnapshot.fromReport(LifeWasteEliminationReport report) {
    return LifeWasteDailySnapshot(
      dateKey: _dateKey(report.monitoredAt),
      monitoredAt: report.monitoredAt,
      wasteFreeScore: report.wasteFreeScore,
      resourceScores: {
        for (final signal in report.signals)
          signal.resource: (signal.progress * 100).round(),
      },
      priorityResource: report.prioritySignals.first.resource,
      nextAction: report.nextAction,
    );
  }

  factory LifeWasteDailySnapshot.fromJson(Map<String, dynamic> json) {
    final scores = <LifeWasteResource, int>{};
    final rawScores = json['resourceScores'];
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        final resource = _resourceByName('${entry.key}');
        if (resource != null) {
          scores[resource] = _readInt(entry.value).clamp(0, 100).toInt();
        }
      }
    }

    final monitoredAt =
        DateTime.tryParse('${json['monitoredAt']}') ?? DateTime.now();
    final priorityResource = _resourceByName('${json['priorityResource']}') ??
        LifeWasteResource.focus;
    return LifeWasteDailySnapshot(
      dateKey: '${json['dateKey']}'.trim().isEmpty
          ? _dateKey(monitoredAt)
          : '${json['dateKey']}',
      monitoredAt: monitoredAt,
      wasteFreeScore: _readInt(json['wasteFreeScore']).clamp(0, 100).toInt(),
      resourceScores: scores,
      priorityResource: priorityResource,
      nextAction: '${json['nextAction'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'monitoredAt': monitoredAt.toIso8601String(),
      'wasteFreeScore': wasteFreeScore,
      'resourceScores': {
        for (final entry in resourceScores.entries) entry.key.name: entry.value,
      },
      'priorityResource': priorityResource.name,
      'nextAction': nextAction,
    };
  }
}

class LifeWasteMonitoringAlert {
  final LifeWasteResource? resource;
  final String title;
  final String detail;
  final int consecutiveDays;
  final bool critical;

  const LifeWasteMonitoringAlert({
    required this.title,
    required this.detail,
    this.resource,
    this.consecutiveDays = 0,
    this.critical = false,
  });
}

class LifeWasteMonitoringSummary {
  final List<LifeWasteDailySnapshot> snapshots;
  final List<LifeWasteMonitoringAlert> alerts;

  const LifeWasteMonitoringSummary({
    required this.snapshots,
    required this.alerts,
  });

  factory LifeWasteMonitoringSummary.empty() {
    return const LifeWasteMonitoringSummary(
      snapshots: <LifeWasteDailySnapshot>[],
      alerts: <LifeWasteMonitoringAlert>[],
    );
  }

  LifeWasteDailySnapshot? get latest =>
      snapshots.isEmpty ? null : snapshots.last;

  LifeWasteDailySnapshot? get previous =>
      snapshots.length < 2 ? null : snapshots[snapshots.length - 2];

  int get historyDays => snapshots.length;

  bool get hasAlerts => alerts.isNotEmpty;

  int get scoreDelta {
    final current = latest;
    final before = previous;
    if (current == null || before == null) {
      return 0;
    }
    return current.wasteFreeScore - before.wasteFreeScore;
  }
}

class LifeWasteEliminationService {
  const LifeWasteEliminationService();

  static const _snapshotHistoryKey = 'life_waste_daily_snapshots_v1';
  static const _maxSnapshotHistoryDays = 30;
  static const _alertThresholdScore = 80;
  static const _consecutiveAlertDays = 2;

  LifeWasteEliminationReport buildReport({
    required DateTime monitoredAt,
    required int timeSlipCount,
    required int abstinenceSlipCount,
    required int abstinenceTimeSavedMinutes,
    required int abstinenceMoneySaved,
    required double moneyWaste,
    required int pendingCriticalTaskCount,
    required int coreRitualDoneCount,
    required int coreRitualTarget,
    required int todayCompletedCount,
    required int yesterdayCompletedCount,
    required int featureTotal,
    required int featureImproveCount,
    required double featureProgress,
  }) {
    final totalSlips = timeSlipCount + abstinenceSlipCount;
    final completionTarget = (yesterdayCompletedCount + 1).clamp(1, 99);
    final stableFeatures = (featureTotal - featureImproveCount).clamp(0, 9999);
    final featureTarget = featureTotal <= 0 ? 1 : featureTotal;
    final coreTarget = coreRitualTarget <= 0 ? 1 : coreRitualTarget;

    final signals = <LifeWasteResourceSignal>[
      LifeWasteResourceSignal(
        resource: LifeWasteResource.time,
        label: '時間',
        csf: '惰性アプリを開く前に止める',
        kpi: '時間浪費ブロック率',
        actual: _timeWasteScore(
          totalSlips: totalSlips,
          savedMinutes: abstinenceTimeSavedMinutes,
        ),
        target: 100,
        unit: '点',
        currentLabel: '逸脱 $totalSlips件 / 取り戻した時間 $abstinenceTimeSavedMinutes分',
        nextAction: totalSlips > 0
            ? '今日の逸脱を1件だけ選び、次に開く前の代替行動を決める'
            : '一番惰性が強いアプリを先に閉じ、作業開始から15分だけ守る',
      ),
      LifeWasteResourceSignal(
        resource: LifeWasteResource.money,
        label: 'お金',
        csf: '欲望支出を能力投資へ振り替える',
        kpi: '浪費抑制スコア',
        actual: _moneyWasteScore(
          wasteAmount: moneyWaste,
          savedAmount: abstinenceMoneySaved,
        ),
        target: 100,
        unit: '点',
        currentLabel:
            '記録済み浪費 ${moneyWaste.round()}円 / 防いだ支出 $abstinenceMoneySaved円',
        nextAction: moneyWaste > 0
            ? '最大の浪費カテゴリを1つだけ今週の禁止ルールにする'
            : '次の支出で「能力が上がるか」を確認してから記録する',
      ),
      LifeWasteResourceSignal(
        resource: LifeWasteResource.health,
        label: '健康',
        csf: '体を壊す刺激を日次で遮断する',
        kpi: '健康逸脱ゼロ率',
        actual: _healthWasteScore(
          abstinenceSlipCount: abstinenceSlipCount,
          coreRitualDoneCount: coreRitualDoneCount,
          coreRitualTarget: coreTarget,
        ),
        target: 100,
        unit: '点',
        currentLabel:
            '禁欲逸脱 $abstinenceSlipCount件 / 基本確認 $coreRitualDoneCount/$coreTarget',
        nextAction: abstinenceSlipCount > 0
            ? '睡眠・飲食・刺激のうち、今日崩れた1項目の再発防止策を書く'
            : '次の食事か休憩を先に決め、健康を削る判断を減らす',
      ),
      LifeWasteResourceSignal(
        resource: LifeWasteResource.stamina,
        label: '体力',
        csf: '昨日より一歩だけ実行量を増やす',
        kpi: '実行回復率',
        actual: todayCompletedCount,
        target: completionTarget,
        unit: '件',
        currentLabel: '今日完了 $todayCompletedCount件 / 目標 $completionTarget件',
        nextAction: todayCompletedCount < completionTarget
            ? '最小のタスクを1件だけ完了して、昨日超えのリズムを作る'
            : '体力を削らないよう、次のタスク前に5分休む',
      ),
      LifeWasteResourceSignal(
        resource: LifeWasteResource.intelligence,
        label: '知能',
        csf: '機能をAI分析で学習サイクルへ接続する',
        kpi: 'AI戦略接続率',
        actual: stableFeatures,
        target: featureTarget,
        unit: '機能',
        currentLabel: '安定監視 $stableFeatures/$featureTarget機能',
        nextAction: featureImproveCount > 0
            ? '改善優先機能の先頭1件だけ開き、KGIに直結する使い方へ戻す'
            : '使っていない学習・思考系機能を1つ開き、知能投資に回す',
      ),
      LifeWasteResourceSignal(
        resource: LifeWasteResource.focus,
        label: '集中力',
        csf: '未完了の必須タスクを先に畳む',
        kpi: '集中ブロック率',
        actual: _focusScore(
          pendingCriticalTaskCount: pendingCriticalTaskCount,
          featureProgress: featureProgress,
        ),
        target: 100,
        unit: '点',
        currentLabel: '必須タスク残り $pendingCriticalTaskCount件',
        nextAction: pendingCriticalTaskCount > 0
            ? '必須タスクを1件だけ完了するまで探索メニューを開かない'
            : '次の25分で成果物が残る作業を1つに絞る',
      ),
    ];

    final averageProgress =
        signals.map((s) => s.progress).reduce((a, b) => a + b) / signals.length;
    final plan = KgiCsfKpiPlan(
      domain: 'ライフマネジメント / 浪費ゼロ',
      kgi: '時間・お金・健康・体力・知能・集中力の浪費をなくす',
      actualLabel: '${(averageProgress * 100).round()}点',
      targetLabel: '100点',
      progress: averageProgress,
      metrics: signals
          .map(
            (signal) => KgiCsfKpiMetric.number(
              csf: signal.csf,
              kpi: '${signal.label}: ${signal.kpi}',
              actual: signal.actual,
              target: signal.target,
              unit: signal.unit,
            ),
          )
          .toList(growable: false),
    );

    return LifeWasteEliminationReport(
      monitoredAt: monitoredAt,
      signals: signals,
      plan: plan,
    );
  }

  Future<LifeWasteMonitoringSummary> recordDailySnapshot(
    LifeWasteEliminationReport report, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final snapshots = _readSnapshots(store);
    final today = LifeWasteDailySnapshot.fromReport(report);
    final next = <LifeWasteDailySnapshot>[
      for (final snapshot in snapshots)
        if (snapshot.dateKey != today.dateKey) snapshot,
      today,
    ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    final trimmed = next.length <= _maxSnapshotHistoryDays
        ? next
        : next.sublist(next.length - _maxSnapshotHistoryDays);

    await store.setString(
      _snapshotHistoryKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
    return _buildMonitoringSummary(trimmed);
  }

  Future<LifeWasteMonitoringSummary> loadMonitoringSummary({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _buildMonitoringSummary(_readSnapshots(store));
  }

  List<LifeWasteDailySnapshot> _readSnapshots(SharedPreferences store) {
    final raw = store.getString(_snapshotHistoryKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <LifeWasteDailySnapshot>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LifeWasteDailySnapshot>[];
      }
      final snapshots = decoded
          .whereType<Map>()
          .map(
            (json) => LifeWasteDailySnapshot.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList()
        ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      return snapshots;
    } catch (_) {
      return const <LifeWasteDailySnapshot>[];
    }
  }

  LifeWasteMonitoringSummary _buildMonitoringSummary(
    List<LifeWasteDailySnapshot> snapshots,
  ) {
    if (snapshots.isEmpty) {
      return LifeWasteMonitoringSummary.empty();
    }

    final alerts = <LifeWasteMonitoringAlert>[];
    for (final resource in LifeWasteResource.values) {
      var consecutiveDays = 0;
      for (final snapshot in snapshots.reversed) {
        final score = snapshot.resourceScores[resource] ?? 100;
        if (score < _alertThresholdScore) {
          consecutiveDays++;
        } else {
          break;
        }
      }
      if (consecutiveDays >= _consecutiveAlertDays) {
        final latestScore = snapshots.last.resourceScores[resource] ?? 0;
        alerts.add(
          LifeWasteMonitoringAlert(
            resource: resource,
            title: '${_resourceLabel(resource)}の浪費リスク継続',
            detail:
                '$consecutiveDays日連続で$_alertThresholdScore%未満です。今日の次アクションを先に1つだけ完了してください。',
            consecutiveDays: consecutiveDays,
            critical: consecutiveDays >= 3 || latestScore < 60,
          ),
        );
      }
    }

    if (snapshots.length >= 2) {
      final latest = snapshots.last;
      final previous = snapshots[snapshots.length - 2];
      final delta = latest.wasteFreeScore - previous.wasteFreeScore;
      if (delta <= -10) {
        alerts.add(
          LifeWasteMonitoringAlert(
            title: 'ライフ資本スコア急落',
            detail: '前回から$delta点低下しています。優先資本を1つに絞り、今日中にリカバリー行動を入れてください。',
            critical: true,
          ),
        );
      }
    }

    return LifeWasteMonitoringSummary(
      snapshots: List<LifeWasteDailySnapshot>.unmodifiable(snapshots),
      alerts: List<LifeWasteMonitoringAlert>.unmodifiable(alerts),
    );
  }

  double _timeWasteScore({
    required int totalSlips,
    required int savedMinutes,
  }) {
    final savedScore = (savedMinutes / 60 * 50).clamp(0, 50).toDouble();
    final slipScore = (50 - totalSlips * 15).clamp(0, 50).toDouble();
    return savedScore + slipScore;
  }

  double _moneyWasteScore({
    required double wasteAmount,
    required int savedAmount,
  }) {
    final savedScore = (savedAmount / 5000 * 45).clamp(0, 45).toDouble();
    final wastePenalty = (wasteAmount / 10000 * 15).clamp(0, 55).toDouble();
    return (55 - wastePenalty + savedScore).clamp(0, 100).toDouble();
  }

  double _healthWasteScore({
    required int abstinenceSlipCount,
    required int coreRitualDoneCount,
    required int coreRitualTarget,
  }) {
    final slipScore = (60 - abstinenceSlipCount * 20).clamp(0, 60).toDouble();
    final ritualScore =
        (coreRitualDoneCount / coreRitualTarget * 40).clamp(0, 40).toDouble();
    return slipScore + ritualScore;
  }

  double _focusScore({
    required int pendingCriticalTaskCount,
    required double featureProgress,
  }) {
    final taskScore =
        (70 - pendingCriticalTaskCount * 20).clamp(0, 70).toDouble();
    final monitorScore = (featureProgress * 30).clamp(0, 30).toDouble();
    return taskScore + monitorScore;
  }
}

class LifeWasteAiReviewService {
  final AiHubChatService _chatService;
  final DateTime Function() _now;

  LifeWasteAiReviewService({
    AiHubChatService? chatService,
    AiHubChatInvoker? invoker,
    DateTime Function()? now,
  })  : _chatService = chatService ?? AiHubChatService(invoker: invoker),
        _now = now ?? DateTime.now;

  Future<LifeWasteAiReview> generateReview(
    LifeWasteEliminationReport report,
  ) async {
    try {
      final response = await _chatService.sendProviderChat(
        message: _buildPrompt(report),
      );
      return LifeWasteAiReview(
        summary: _normalize(response.text),
        source: response.source,
        generatedAt: _now(),
      );
    } catch (_) {
      return LifeWasteAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: 'AI連携に失敗しました。',
      );
    }
  }

  String _buildPrompt(LifeWasteEliminationReport report) {
    final lines = report.signals.map((signal) {
      return '- ${signal.label}: progress=${(signal.progress * 100).round()}%, '
          'csf=${signal.csf}, kpi=${signal.kpi}, next=${signal.nextAction}';
    }).join('\n');
    return '''
あなたはライフマネジメントのAI COOです。
最重要課題は、時間・お金・健康・体力・知能・集中力の浪費をなくすことです。
以下のKGI/CSF/KPIから、現状分析、最重要CSF、今すぐの改善アクション、次回モニタリング観点を日本語3行以内で返してください。
生命資本スコア: ${report.wasteFreeScore}/100
KGI: ${report.plan.kgi}
$lines
''';
  }

  String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 260) {
      return collapsed;
    }
    return '${collapsed.substring(0, 260)}...';
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feature_strategy_monitor.dart';

class FeatureStrategyDailySnapshot {
  final String dateKey;
  final DateTime monitoredAt;
  final int totalFeatures;
  final int onTrackCount;
  final int watchCount;
  final int improveCount;
  final int portfolioProgressPercent;
  final int aiCoveragePercent;
  final int lifeCapitalCoveragePercent;
  final int reviewDueCount;
  final int reviewOverdueCount;
  final int reviewCadenceCompliancePercent;
  final int consolidationCount;
  final int consolidationWasteMinutesSaved;
  final int lifeCapitalLaneCount;
  final int lifeCapitalLaneWasteMinutesSaved;
  final int highWasteReductionCount;
  final String focusFeatureId;
  final String focusResource;
  final int focusCompletedDaysLast7;
  final int focusDeferredDaysLast7;
  final int focusStreakDays;
  final bool focusHabitStable;
  final List<String> priorityFeatureIds;
  final List<String> reviewDueFeatureIds;
  final Map<String, int> lifeCapitalScores;
  final String nextAction;
  final bool cloudSynced;

  const FeatureStrategyDailySnapshot({
    required this.dateKey,
    required this.monitoredAt,
    required this.totalFeatures,
    required this.onTrackCount,
    required this.watchCount,
    required this.improveCount,
    required this.portfolioProgressPercent,
    required this.aiCoveragePercent,
    required this.lifeCapitalCoveragePercent,
    required this.reviewDueCount,
    required this.reviewOverdueCount,
    required this.reviewCadenceCompliancePercent,
    required this.consolidationCount,
    required this.consolidationWasteMinutesSaved,
    required this.lifeCapitalLaneCount,
    required this.lifeCapitalLaneWasteMinutesSaved,
    required this.highWasteReductionCount,
    required this.focusFeatureId,
    required this.focusResource,
    required this.focusCompletedDaysLast7,
    required this.focusDeferredDaysLast7,
    required this.focusStreakDays,
    required this.focusHabitStable,
    required this.priorityFeatureIds,
    required this.reviewDueFeatureIds,
    required this.lifeCapitalScores,
    required this.nextAction,
    this.cloudSynced = false,
  });

  factory FeatureStrategyDailySnapshot.fromReport(
    FeatureStrategyReport report,
  ) {
    final focus = report.focusRecommendation;
    final prioritySignals = report.prioritySignals.take(8).toList();
    final reviewDueSignals = report.reviewDueSignals.take(12).toList();
    final nextAction = focus?.action ??
        report.queuedFocusRecommendation?.action ??
        (report.recoveryRoadmap.isNotEmpty
            ? report.recoveryRoadmap.first.action
            : null) ??
        (prioritySignals.isNotEmpty
            ? prioritySignals.first.nextImprovement
            : 'All monitored features are currently stable.');

    return FeatureStrategyDailySnapshot(
      dateKey: _dateKey(report.monitoredAt),
      monitoredAt: report.monitoredAt,
      totalFeatures: report.totalFeatures,
      onTrackCount: report.onTrackCount,
      watchCount: report.watchCount,
      improveCount: report.improveCount,
      portfolioProgressPercent:
          (report.portfolioPlan.displayProgress * 100).round(),
      aiCoveragePercent: (report.aiCoverageRatio * 100).round(),
      lifeCapitalCoveragePercent:
          (report.lifeCapitalCoverageRatio * 100).round(),
      reviewDueCount: report.reviewDueCount,
      reviewOverdueCount: report.reviewOverdueCount,
      reviewCadenceCompliancePercent:
          (report.reviewCadenceComplianceRatio * 100).round(),
      consolidationCount: report.consolidationCount,
      consolidationWasteMinutesSaved: report.consolidationWasteMinutesSaved,
      lifeCapitalLaneCount: report.lifeCapitalLaneCount,
      lifeCapitalLaneWasteMinutesSaved: report.lifeCapitalLaneWasteMinutesSaved,
      highWasteReductionCount: report.highWasteReductionCount,
      focusFeatureId: focus?.featureId ?? '',
      focusResource: focus?.resource.name ?? '',
      focusCompletedDaysLast7: report.focusActionsCompletedLast7,
      focusDeferredDaysLast7: report.focusActionsDeferredLast7,
      focusStreakDays: report.focusActionStreakDays,
      focusHabitStable: focus?.actionStats.isHabitStable ?? false,
      priorityFeatureIds:
          prioritySignals.map((signal) => signal.featureId).toList(),
      reviewDueFeatureIds:
          reviewDueSignals.map((signal) => signal.featureId).toList(),
      lifeCapitalScores: {
        for (final summary in report.lifeCapitalSummaries)
          summary.resource.name: (summary.averageProgress * 100).round(),
      },
      nextAction: nextAction,
    );
  }

  factory FeatureStrategyDailySnapshot.fromJson(Map<String, dynamic> json) {
    return FeatureStrategyDailySnapshot(
      dateKey: _normalizeDateKey('${json['dateKey'] ?? ''}'),
      monitoredAt:
          DateTime.tryParse('${json['monitoredAt'] ?? ''}') ?? DateTime.now(),
      totalFeatures: _readInt(json['totalFeatures']),
      onTrackCount: _readInt(json['onTrackCount']),
      watchCount: _readInt(json['watchCount']),
      improveCount: _readInt(json['improveCount']),
      portfolioProgressPercent: _readInt(
        json['portfolioProgressPercent'],
      ).clamp(0, 100).toInt(),
      aiCoveragePercent:
          _readInt(json['aiCoveragePercent']).clamp(0, 100).toInt(),
      lifeCapitalCoveragePercent: _readInt(
        json['lifeCapitalCoveragePercent'],
      ).clamp(0, 100).toInt(),
      reviewDueCount: _readInt(json['reviewDueCount']),
      reviewOverdueCount: _readInt(json['reviewOverdueCount']),
      reviewCadenceCompliancePercent: _readInt(
        json['reviewCadenceCompliancePercent'],
      ).clamp(0, 100).toInt(),
      consolidationCount: _readInt(json['consolidationCount']),
      consolidationWasteMinutesSaved:
          _readInt(json['consolidationWasteMinutesSaved']),
      lifeCapitalLaneCount: _readInt(json['lifeCapitalLaneCount']),
      lifeCapitalLaneWasteMinutesSaved:
          _readInt(json['lifeCapitalLaneWasteMinutesSaved']),
      highWasteReductionCount: _readInt(json['highWasteReductionCount']),
      focusFeatureId: '${json['focusFeatureId'] ?? ''}',
      focusResource: '${json['focusResource'] ?? ''}',
      focusCompletedDaysLast7: _readInt(json['focusCompletedDaysLast7']),
      focusDeferredDaysLast7: _readInt(json['focusDeferredDaysLast7']),
      focusStreakDays: _readInt(json['focusStreakDays']),
      focusHabitStable: json['focusHabitStable'] == true,
      priorityFeatureIds: _readStringList(json['priorityFeatureIds']),
      reviewDueFeatureIds: _readStringList(json['reviewDueFeatureIds']),
      lifeCapitalScores: _readScoreMap(json['lifeCapitalScores']),
      nextAction: '${json['nextAction'] ?? ''}',
      cloudSynced: json['cloudSynced'] == true,
    );
  }

  factory FeatureStrategyDailySnapshot.fromSupabaseRow(
    Map<String, dynamic> row,
  ) {
    return FeatureStrategyDailySnapshot.fromJson({
      'dateKey': row['snapshot_date'],
      'monitoredAt': row['monitored_at'],
      'totalFeatures': row['total_features'],
      'onTrackCount': row['on_track_count'],
      'watchCount': row['watch_count'],
      'improveCount': row['improve_count'],
      'portfolioProgressPercent': row['portfolio_progress_percent'],
      'aiCoveragePercent': row['ai_coverage_percent'],
      'lifeCapitalCoveragePercent': row['life_capital_coverage_percent'],
      'reviewDueCount': row['review_due_count'],
      'reviewOverdueCount': row['review_overdue_count'],
      'reviewCadenceCompliancePercent':
          row['review_cadence_compliance_percent'],
      'consolidationCount': row['consolidation_count'],
      'consolidationWasteMinutesSaved':
          row['consolidation_waste_minutes_saved'],
      'lifeCapitalLaneCount': row['life_capital_lane_count'],
      'lifeCapitalLaneWasteMinutesSaved':
          row['life_capital_lane_waste_minutes_saved'],
      'highWasteReductionCount': row['high_waste_reduction_count'],
      'focusFeatureId': row['focus_feature_id'],
      'focusResource': row['focus_resource'],
      'focusCompletedDaysLast7': row['focus_completed_days_last7'],
      'focusDeferredDaysLast7': row['focus_deferred_days_last7'],
      'focusStreakDays': row['focus_streak_days'],
      'focusHabitStable': row['focus_habit_stable'],
      'priorityFeatureIds': row['priority_feature_ids'],
      'reviewDueFeatureIds': row['review_due_feature_ids'],
      'lifeCapitalScores': row['life_capital_scores'],
      'nextAction': row['next_action'],
      'cloudSynced': true,
    });
  }

  FeatureStrategyDailySnapshot copyWith({bool? cloudSynced}) {
    return FeatureStrategyDailySnapshot(
      dateKey: dateKey,
      monitoredAt: monitoredAt,
      totalFeatures: totalFeatures,
      onTrackCount: onTrackCount,
      watchCount: watchCount,
      improveCount: improveCount,
      portfolioProgressPercent: portfolioProgressPercent,
      aiCoveragePercent: aiCoveragePercent,
      lifeCapitalCoveragePercent: lifeCapitalCoveragePercent,
      reviewDueCount: reviewDueCount,
      reviewOverdueCount: reviewOverdueCount,
      reviewCadenceCompliancePercent: reviewCadenceCompliancePercent,
      consolidationCount: consolidationCount,
      consolidationWasteMinutesSaved: consolidationWasteMinutesSaved,
      lifeCapitalLaneCount: lifeCapitalLaneCount,
      lifeCapitalLaneWasteMinutesSaved: lifeCapitalLaneWasteMinutesSaved,
      highWasteReductionCount: highWasteReductionCount,
      focusFeatureId: focusFeatureId,
      focusResource: focusResource,
      focusCompletedDaysLast7: focusCompletedDaysLast7,
      focusDeferredDaysLast7: focusDeferredDaysLast7,
      focusStreakDays: focusStreakDays,
      focusHabitStable: focusHabitStable,
      priorityFeatureIds: priorityFeatureIds,
      reviewDueFeatureIds: reviewDueFeatureIds,
      lifeCapitalScores: lifeCapitalScores,
      nextAction: nextAction,
      cloudSynced: cloudSynced ?? this.cloudSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'monitoredAt': monitoredAt.toIso8601String(),
      'totalFeatures': totalFeatures,
      'onTrackCount': onTrackCount,
      'watchCount': watchCount,
      'improveCount': improveCount,
      'portfolioProgressPercent': portfolioProgressPercent,
      'aiCoveragePercent': aiCoveragePercent,
      'lifeCapitalCoveragePercent': lifeCapitalCoveragePercent,
      'reviewDueCount': reviewDueCount,
      'reviewOverdueCount': reviewOverdueCount,
      'reviewCadenceCompliancePercent': reviewCadenceCompliancePercent,
      'consolidationCount': consolidationCount,
      'consolidationWasteMinutesSaved': consolidationWasteMinutesSaved,
      'lifeCapitalLaneCount': lifeCapitalLaneCount,
      'lifeCapitalLaneWasteMinutesSaved': lifeCapitalLaneWasteMinutesSaved,
      'highWasteReductionCount': highWasteReductionCount,
      'focusFeatureId': focusFeatureId,
      'focusResource': focusResource,
      'focusCompletedDaysLast7': focusCompletedDaysLast7,
      'focusDeferredDaysLast7': focusDeferredDaysLast7,
      'focusStreakDays': focusStreakDays,
      'focusHabitStable': focusHabitStable,
      'priorityFeatureIds': priorityFeatureIds,
      'reviewDueFeatureIds': reviewDueFeatureIds,
      'lifeCapitalScores': lifeCapitalScores,
      'nextAction': nextAction,
      'cloudSynced': cloudSynced,
    };
  }
}

class FeatureStrategyMonitoringSummary {
  final List<FeatureStrategyDailySnapshot> snapshots;
  final bool cloudSynced;

  const FeatureStrategyMonitoringSummary({
    required this.snapshots,
    this.cloudSynced = false,
  });

  factory FeatureStrategyMonitoringSummary.empty({bool cloudSynced = false}) {
    return FeatureStrategyMonitoringSummary(
      snapshots: const <FeatureStrategyDailySnapshot>[],
      cloudSynced: cloudSynced,
    );
  }

  FeatureStrategyDailySnapshot? get latest =>
      snapshots.isEmpty ? null : snapshots.last;
  FeatureStrategyDailySnapshot? get previous =>
      snapshots.length < 2 ? null : snapshots[snapshots.length - 2];

  int get snapshotCount => snapshots.length;
  int get portfolioProgressDelta => latest == null || previous == null
      ? 0
      : latest!.portfolioProgressPercent - previous!.portfolioProgressPercent;
  int get reviewOverdueDelta => latest == null || previous == null
      ? 0
      : latest!.reviewOverdueCount - previous!.reviewOverdueCount;
  bool get needsReview =>
      latest != null &&
      (latest!.reviewOverdueCount > 0 || latest!.improveCount > 0);
  String get syncLabel => cloudSynced ? 'Cloud sync' : 'Local history';
  String get progressDeltaLabel {
    if (previous == null) return 'first snapshot';
    final sign = portfolioProgressDelta >= 0 ? '+' : '';
    return '$sign$portfolioProgressDelta pt';
  }
}

abstract class FeatureStrategyReportSnapshotRepository {
  Future<void> upsertDailySnapshot(FeatureStrategyDailySnapshot snapshot);

  Future<List<FeatureStrategyDailySnapshot>> loadRecentSnapshots({
    int limit = 30,
  });
}

class SupabaseFeatureStrategyReportSnapshotRepository
    implements FeatureStrategyReportSnapshotRepository {
  final SupabaseClient? client;

  const SupabaseFeatureStrategyReportSnapshotRepository({this.client});

  SupabaseClient get _client => client ?? Supabase.instance.client;

  @override
  Future<void> upsertDailySnapshot(
    FeatureStrategyDailySnapshot snapshot,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Feature strategy snapshot sync requires sign-in.');
    }

    await _client.from('feature_strategy_daily_snapshots').upsert(
      {
        'user_id': userId,
        'snapshot_date': snapshot.dateKey,
        'monitored_at': snapshot.monitoredAt.toUtc().toIso8601String(),
        'total_features': snapshot.totalFeatures,
        'on_track_count': snapshot.onTrackCount,
        'watch_count': snapshot.watchCount,
        'improve_count': snapshot.improveCount,
        'portfolio_progress_percent': snapshot.portfolioProgressPercent,
        'ai_coverage_percent': snapshot.aiCoveragePercent,
        'life_capital_coverage_percent': snapshot.lifeCapitalCoveragePercent,
        'review_due_count': snapshot.reviewDueCount,
        'review_overdue_count': snapshot.reviewOverdueCount,
        'review_cadence_compliance_percent':
            snapshot.reviewCadenceCompliancePercent,
        'consolidation_count': snapshot.consolidationCount,
        'consolidation_waste_minutes_saved':
            snapshot.consolidationWasteMinutesSaved,
        'life_capital_lane_count': snapshot.lifeCapitalLaneCount,
        'life_capital_lane_waste_minutes_saved':
            snapshot.lifeCapitalLaneWasteMinutesSaved,
        'high_waste_reduction_count': snapshot.highWasteReductionCount,
        'focus_feature_id': snapshot.focusFeatureId,
        'focus_resource': snapshot.focusResource,
        'focus_completed_days_last7': snapshot.focusCompletedDaysLast7,
        'focus_deferred_days_last7': snapshot.focusDeferredDaysLast7,
        'focus_streak_days': snapshot.focusStreakDays,
        'focus_habit_stable': snapshot.focusHabitStable,
        'priority_feature_ids': snapshot.priorityFeatureIds,
        'review_due_feature_ids': snapshot.reviewDueFeatureIds,
        'life_capital_scores': snapshot.lifeCapitalScores,
        'next_action': snapshot.nextAction,
      },
      onConflict: 'user_id,snapshot_date',
    );
  }

  @override
  Future<List<FeatureStrategyDailySnapshot>> loadRecentSnapshots({
    int limit = 30,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const <FeatureStrategyDailySnapshot>[];
    }

    final rows = await _client
        .from('feature_strategy_daily_snapshots')
        .select(
          'snapshot_date, monitored_at, total_features, on_track_count, '
          'watch_count, improve_count, portfolio_progress_percent, '
          'ai_coverage_percent, life_capital_coverage_percent, '
          'review_due_count, review_overdue_count, '
          'review_cadence_compliance_percent, consolidation_count, '
          'consolidation_waste_minutes_saved, life_capital_lane_count, '
          'life_capital_lane_waste_minutes_saved, '
          'high_waste_reduction_count, '
          'focus_feature_id, focus_resource, focus_completed_days_last7, '
          'focus_deferred_days_last7, focus_streak_days, focus_habit_stable, '
          'priority_feature_ids, review_due_feature_ids, life_capital_scores, '
          'next_action',
        )
        .eq('user_id', userId)
        .order('snapshot_date', ascending: false)
        .limit(limit);

    final snapshots = rows
        .whereType<Map>()
        .map(
          (row) => FeatureStrategyDailySnapshot.fromSupabaseRow(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return snapshots;
  }
}

class FeatureStrategyReportSnapshotService {
  final FeatureStrategyReportSnapshotRepository? snapshotRepository;

  const FeatureStrategyReportSnapshotService({this.snapshotRepository});

  static const _historyKey = 'feature_strategy_daily_snapshots_v1';
  static const _maxHistoryDays = 30;

  Future<FeatureStrategyMonitoringSummary> recordReport(
    FeatureStrategyReport report, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final local = _readSnapshots(store);
    final today = FeatureStrategyDailySnapshot.fromReport(report);
    final localMerged = _mergeSnapshots(local, <FeatureStrategyDailySnapshot>[
      today,
    ]);
    await _writeSnapshots(store, localMerged);

    final repository = snapshotRepository;
    if (repository == null) {
      return FeatureStrategyMonitoringSummary(snapshots: localMerged);
    }

    try {
      await repository.upsertDailySnapshot(today);
      final remote = await repository.loadRecentSnapshots(
        limit: _maxHistoryDays,
      );
      final merged = _mergeSnapshots(localMerged, remote);
      await _writeSnapshots(store, merged);
      return FeatureStrategyMonitoringSummary(
        snapshots: merged,
        cloudSynced: true,
      );
    } catch (_) {
      return FeatureStrategyMonitoringSummary(snapshots: localMerged);
    }
  }

  Future<FeatureStrategyMonitoringSummary> loadSummary({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final local = _readSnapshots(store);
    final repository = snapshotRepository;
    if (repository == null) {
      return FeatureStrategyMonitoringSummary(snapshots: local);
    }

    try {
      final remote = await repository.loadRecentSnapshots(
        limit: _maxHistoryDays,
      );
      final merged = _mergeSnapshots(local, remote);
      await _writeSnapshots(store, merged);
      return FeatureStrategyMonitoringSummary(
        snapshots: merged,
        cloudSynced: remote.isNotEmpty,
      );
    } catch (_) {
      return FeatureStrategyMonitoringSummary(snapshots: local);
    }
  }

  List<FeatureStrategyDailySnapshot> _readSnapshots(SharedPreferences store) {
    final raw = store.getString(_historyKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <FeatureStrategyDailySnapshot>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <FeatureStrategyDailySnapshot>[];
      }
      final snapshots = decoded
          .whereType<Map>()
          .map(
            (item) => FeatureStrategyDailySnapshot.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList()
        ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      return _trimSnapshots(snapshots);
    } catch (_) {
      return const <FeatureStrategyDailySnapshot>[];
    }
  }

  Future<void> _writeSnapshots(
    SharedPreferences store,
    List<FeatureStrategyDailySnapshot> snapshots,
  ) async {
    await store.setString(
      _historyKey,
      jsonEncode(snapshots.map((item) => item.toJson()).toList()),
    );
  }

  List<FeatureStrategyDailySnapshot> _mergeSnapshots(
    List<FeatureStrategyDailySnapshot> local,
    List<FeatureStrategyDailySnapshot> remote,
  ) {
    final byDate = <String, FeatureStrategyDailySnapshot>{};
    void put(FeatureStrategyDailySnapshot snapshot) {
      final existing = byDate[snapshot.dateKey];
      if (existing == null ||
          snapshot.monitoredAt.isAfter(existing.monitoredAt) ||
          (snapshot.cloudSynced && !existing.cloudSynced)) {
        byDate[snapshot.dateKey] = snapshot;
      }
    }

    for (final snapshot in local) {
      put(snapshot);
    }
    for (final snapshot in remote) {
      put(snapshot.copyWith(cloudSynced: true));
    }
    return _trimSnapshots(byDate.values.toList());
  }

  List<FeatureStrategyDailySnapshot> _trimSnapshots(
    List<FeatureStrategyDailySnapshot> snapshots,
  ) {
    final sorted = List<FeatureStrategyDailySnapshot>.from(snapshots)
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    if (sorted.length <= _maxHistoryDays) {
      return sorted;
    }
    return sorted.sublist(sorted.length - _maxHistoryDays);
  }
}

String _dateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _normalizeDateKey(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 10) {
    return trimmed.substring(0, 10);
  }
  return trimmed;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('${value ?? ''}') ?? 0;
}

List<String> _readStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

Map<String, int> _readScoreMap(Object? value) {
  if (value is! Map) {
    return const <String, int>{};
  }
  return {
    for (final entry in value.entries)
      '${entry.key}': _readInt(entry.value).clamp(0, 100).toInt(),
  };
}

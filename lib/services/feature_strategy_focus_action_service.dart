import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feature_strategy_monitor.dart';

class FeatureStrategyFocusActionState {
  final String featureId;
  final String dateKey;
  final bool completed;
  final bool deferred;
  final DateTime? completedAt;
  final DateTime? deferredAt;
  final int completionStreakDays;
  final bool cloudSynced;

  const FeatureStrategyFocusActionState({
    required this.featureId,
    required this.dateKey,
    required this.completed,
    required this.deferred,
    required this.completedAt,
    required this.deferredAt,
    required this.completionStreakDays,
    this.cloudSynced = false,
  });

  bool get isClosedForToday => completed || deferred;

  factory FeatureStrategyFocusActionState.pending({
    required String featureId,
    required String dateKey,
    required int completionStreakDays,
  }) {
    return FeatureStrategyFocusActionState(
      featureId: featureId,
      dateKey: dateKey,
      completed: false,
      deferred: false,
      completedAt: null,
      deferredAt: null,
      completionStreakDays: completionStreakDays,
    );
  }

  factory FeatureStrategyFocusActionState.fromSupabaseRow(
    Map<String, dynamic> row,
  ) {
    final status = '${row['status'] ?? ''}';
    return FeatureStrategyFocusActionState(
      featureId: '${row['feature_id'] ?? ''}',
      dateKey: _normalizeDateKey('${row['action_date'] ?? ''}'),
      completed: status == 'completed',
      deferred: status == 'deferred',
      completedAt: _parseDateValue(row['completed_at']),
      deferredAt: _parseDateValue(row['deferred_at']),
      completionStreakDays:
          _readInt(row['completion_streak_days']).clamp(0, 365).toInt(),
      cloudSynced: true,
    );
  }

  FeatureStrategyFocusActionState copyWith({
    bool? completed,
    bool? deferred,
    DateTime? completedAt,
    DateTime? deferredAt,
    int? completionStreakDays,
    bool? cloudSynced,
  }) {
    return FeatureStrategyFocusActionState(
      featureId: featureId,
      dateKey: dateKey,
      completed: completed ?? this.completed,
      deferred: deferred ?? this.deferred,
      completedAt: completedAt ?? this.completedAt,
      deferredAt: deferredAt ?? this.deferredAt,
      completionStreakDays: completionStreakDays ?? this.completionStreakDays,
      cloudSynced: cloudSynced ?? this.cloudSynced,
    );
  }
}

abstract class FeatureStrategyFocusActionRepository {
  Future<void> upsertActionState({
    required FeatureStrategyFocusRecommendation recommendation,
    required FeatureStrategyFocusActionState state,
  });

  Future<List<FeatureStrategyFocusActionState>> loadRecentActionStates({
    required Iterable<String> featureIds,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
  });
}

class SupabaseFeatureStrategyFocusActionRepository
    implements FeatureStrategyFocusActionRepository {
  final SupabaseClient? client;

  const SupabaseFeatureStrategyFocusActionRepository({this.client});

  SupabaseClient get _client => client ?? Supabase.instance.client;

  @override
  Future<void> upsertActionState({
    required FeatureStrategyFocusRecommendation recommendation,
    required FeatureStrategyFocusActionState state,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Feature focus action sync requires a signed-in user.');
    }

    final status = state.completed
        ? 'completed'
        : state.deferred
            ? 'deferred'
            : 'pending';
    await _client.from('feature_strategy_focus_actions').upsert(
      {
        'user_id': userId,
        'feature_id': state.featureId,
        'action_date': state.dateKey,
        'status': status,
        'completed_at': state.completedAt?.toUtc().toIso8601String(),
        'deferred_at': state.deferredAt?.toUtc().toIso8601String(),
        'completion_streak_days': state.completionStreakDays,
        'life_capital_resource': recommendation.resource.name,
        'feature_name': recommendation.featureName,
        'section_name': recommendation.sectionName,
        'csf': recommendation.csf,
        'kpi': recommendation.kpi,
        'action': recommendation.action,
        'monitoring_cadence': recommendation.monitoringCadence,
        'metadata': {
          'parkedResourceCount': recommendation.parkedResourceCount,
          'parkedFeatureCount': recommendation.parkedFeatureCount,
          'progress': recommendation.progress,
        },
      },
      onConflict: 'user_id,feature_id,action_date',
    );
  }

  @override
  Future<List<FeatureStrategyFocusActionState>> loadRecentActionStates({
    required Iterable<String> featureIds,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final ids = featureIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (userId == null || ids.isEmpty) {
      return const <FeatureStrategyFocusActionState>[];
    }

    final startKey = const FeatureStrategyFocusActionService().formatDateKey(
      startDate,
    );
    final endKey =
        const FeatureStrategyFocusActionService().formatDateKey(endDate);
    final rows = ids.length == 1
        ? await _client
            .from('feature_strategy_focus_actions')
            .select(
              'feature_id, action_date, status, completed_at, deferred_at, '
              'completion_streak_days',
            )
            .eq('user_id', userId)
            .eq('feature_id', ids.single)
            .gte('action_date', startKey)
            .lte('action_date', endKey)
            .order('action_date')
            .limit(limit)
        : await _client
            .from('feature_strategy_focus_actions')
            .select(
              'feature_id, action_date, status, completed_at, deferred_at, '
              'completion_streak_days',
            )
            .eq('user_id', userId)
            .inFilter('feature_id', ids)
            .gte('action_date', startKey)
            .lte('action_date', endKey)
            .order('action_date')
            .limit(limit);

    return rows
        .whereType<Map>()
        .map(
          (row) => FeatureStrategyFocusActionState.fromSupabaseRow(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((state) => state.featureId.trim().isNotEmpty)
        .toList(growable: false);
  }
}

class FeatureStrategyFocusActionService {
  static const _statePrefix = 'feature_strategy_focus_action_state_v1';
  static const _historyPrefix = 'feature_strategy_focus_completion_history_v1';
  static const _deferHistoryPrefix = 'feature_strategy_focus_defer_history_v1';
  final FeatureStrategyFocusActionRepository? actionRepository;

  const FeatureStrategyFocusActionService({this.actionRepository});

  Future<FeatureStrategyFocusActionState> loadState(
    FeatureStrategyFocusRecommendation recommendation, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final today = _dateOnly(now ?? DateTime.now());
    final dateKey = formatDateKey(today);
    await _syncRemoteStates(
      store: store,
      featureIds: <String>[recommendation.featureId],
      startDate: today.subtract(const Duration(days: 6)),
      endDate: today,
    );
    final saved = _readState(
      store.getString(_stateKey(recommendation.featureId, dateKey)),
    );
    final completed = saved?.completed ?? false;
    final deferred = saved?.deferred ?? false;
    final streak = _completionStreak(
      store,
      recommendation.featureId,
      anchorDate: completed ? today : today.subtract(const Duration(days: 1)),
    );

    if (saved == null) {
      return FeatureStrategyFocusActionState.pending(
        featureId: recommendation.featureId,
        dateKey: dateKey,
        completionStreakDays: streak,
      );
    }

    return FeatureStrategyFocusActionState(
      featureId: recommendation.featureId,
      dateKey: dateKey,
      completed: completed,
      deferred: deferred,
      completedAt: saved.completedAt,
      deferredAt: saved.deferredAt,
      completionStreakDays: streak,
      cloudSynced: saved.cloudSynced,
    );
  }

  Future<FeatureStrategyFocusActionState> markCompleted(
    FeatureStrategyFocusRecommendation recommendation, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final timestamp = now ?? DateTime.now();
    final today = _dateOnly(timestamp);
    final dateKey = formatDateKey(today);
    await _addCompletionDate(store, recommendation.featureId, dateKey);
    await _removeHistoryDate(
      store,
      _deferHistoryKey(recommendation.featureId),
      dateKey,
    );
    final state = FeatureStrategyFocusActionState(
      featureId: recommendation.featureId,
      dateKey: dateKey,
      completed: true,
      deferred: false,
      completedAt: timestamp,
      deferredAt: null,
      completionStreakDays: _completionStreak(
        store,
        recommendation.featureId,
        anchorDate: today,
      ),
    );
    await store.setString(
      _stateKey(recommendation.featureId, dateKey),
      _encodeState(state),
    );
    return _syncActionState(
      recommendation: recommendation,
      state: state,
      store: store,
    );
  }

  Future<FeatureStrategyFocusActionState> deferToday(
    FeatureStrategyFocusRecommendation recommendation, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final timestamp = now ?? DateTime.now();
    final today = _dateOnly(timestamp);
    final dateKey = formatDateKey(today);
    await _addHistoryDate(
      store,
      _deferHistoryKey(recommendation.featureId),
      dateKey,
    );
    final state = FeatureStrategyFocusActionState(
      featureId: recommendation.featureId,
      dateKey: dateKey,
      completed: false,
      deferred: true,
      completedAt: null,
      deferredAt: timestamp,
      completionStreakDays: _completionStreak(
        store,
        recommendation.featureId,
        anchorDate: today.subtract(const Duration(days: 1)),
      ),
    );
    await store.setString(
      _stateKey(recommendation.featureId, dateKey),
      _encodeState(state),
    );
    return _syncActionState(
      recommendation: recommendation,
      state: state,
      store: store,
    );
  }

  Future<void> clearToday(
    FeatureStrategyFocusRecommendation recommendation, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final today = _dateOnly(now ?? DateTime.now());
    final dateKey = formatDateKey(today);
    await store.remove(_stateKey(recommendation.featureId, dateKey));
    final historyKey = _historyKey(recommendation.featureId);
    final dates = store.getStringList(historyKey) ?? <String>[];
    dates.remove(dateKey);
    await store.setStringList(historyKey, dates);
    await _removeHistoryDate(
      store,
      _deferHistoryKey(recommendation.featureId),
      dateKey,
    );
  }

  Future<Map<String, FeatureStrategyFocusActionStats>> loadStatsByFeatureIds(
    Iterable<String> featureIds, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final today = _dateOnly(now ?? DateTime.now());
    final ids = featureIds.where((id) => id.trim().isNotEmpty).toSet();
    await _syncRemoteStates(
      store: store,
      featureIds: ids,
      startDate: today.subtract(const Duration(days: 6)),
      endDate: today,
    );
    return <String, FeatureStrategyFocusActionStats>{
      for (final id in ids) id: _buildStats(store, id, today),
    };
  }

  String formatDateKey(DateTime date) {
    final local = _dateOnly(date);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _stateKey(String featureId, String dateKey) {
    return '$_statePrefix:$featureId:$dateKey';
  }

  String _historyKey(String featureId) {
    return '$_historyPrefix:$featureId';
  }

  String _deferHistoryKey(String featureId) {
    return '$_deferHistoryPrefix:$featureId';
  }

  Future<void> _addCompletionDate(
    SharedPreferences store,
    String featureId,
    String dateKey,
  ) async {
    await _addHistoryDate(store, _historyKey(featureId), dateKey);
  }

  Future<FeatureStrategyFocusActionState> _syncActionState({
    required FeatureStrategyFocusRecommendation recommendation,
    required FeatureStrategyFocusActionState state,
    required SharedPreferences store,
  }) async {
    final repository = actionRepository;
    if (repository == null) {
      return state;
    }
    try {
      await repository.upsertActionState(
        recommendation: recommendation,
        state: state,
      );
      final synced = state.copyWith(cloudSynced: true);
      await store.setString(
        _stateKey(synced.featureId, synced.dateKey),
        _encodeState(synced),
      );
      return synced;
    } catch (_) {
      return state;
    }
  }

  Future<void> _syncRemoteStates({
    required SharedPreferences store,
    required Iterable<String> featureIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final repository = actionRepository;
    if (repository == null) {
      return;
    }
    try {
      final states = await repository.loadRecentActionStates(
        featureIds: featureIds,
        startDate: startDate,
        endDate: endDate,
      );
      await _cacheRemoteStates(store, states);
    } catch (_) {
      // Local feedback must remain available when cloud sync is unavailable.
    }
  }

  Future<void> _cacheRemoteStates(
    SharedPreferences store,
    Iterable<FeatureStrategyFocusActionState> states,
  ) async {
    for (final state in states) {
      if (state.completed) {
        await _addHistoryDate(
          store,
          _historyKey(state.featureId),
          state.dateKey,
        );
        await _removeHistoryDate(
          store,
          _deferHistoryKey(state.featureId),
          state.dateKey,
        );
      } else if (state.deferred) {
        await _addHistoryDate(
          store,
          _deferHistoryKey(state.featureId),
          state.dateKey,
        );
        await _removeHistoryDate(
          store,
          _historyKey(state.featureId),
          state.dateKey,
        );
      }
      await store.setString(
        _stateKey(state.featureId, state.dateKey),
        _encodeState(state.copyWith(cloudSynced: true)),
      );
    }
  }

  Future<void> _addHistoryDate(
    SharedPreferences store,
    String historyKey,
    String dateKey,
  ) async {
    final dates = store.getStringList(historyKey) ?? <String>[];
    if (!dates.contains(dateKey)) {
      dates.add(dateKey);
      dates.sort();
      await store.setStringList(historyKey, dates);
    }
  }

  Future<void> _removeHistoryDate(
    SharedPreferences store,
    String historyKey,
    String dateKey,
  ) async {
    final dates = store.getStringList(historyKey) ?? <String>[];
    if (dates.remove(dateKey)) {
      await store.setStringList(historyKey, dates);
    }
  }

  FeatureStrategyFocusActionStats _buildStats(
    SharedPreferences store,
    String featureId,
    DateTime today,
  ) {
    final completedDates =
        (store.getStringList(_historyKey(featureId)) ?? <String>[]).toSet();
    final deferredDates =
        (store.getStringList(_deferHistoryKey(featureId)) ?? <String>[])
            .toSet();
    final window = List<DateTime>.generate(
      7,
      (index) => today.subtract(Duration(days: index)),
    );
    final completedDays = window
        .where((date) => completedDates.contains(formatDateKey(date)))
        .length;
    final deferredDays = window
        .where((date) => deferredDates.contains(formatDateKey(date)))
        .length;
    final currentStreak = _completionStreak(
      store,
      featureId,
      anchorDate: completedDates.contains(formatDateKey(today))
          ? today
          : today.subtract(const Duration(days: 1)),
    );
    final sortedCompletedDates = completedDates.toList()..sort();
    final lastCompletedAt = sortedCompletedDates.isEmpty
        ? null
        : DateTime.tryParse(sortedCompletedDates.last);

    return FeatureStrategyFocusActionStats(
      featureId: featureId,
      completedDaysLast7: completedDays,
      deferredDaysLast7: deferredDays,
      currentStreakDays: currentStreak,
      lastCompletedAt: lastCompletedAt,
    );
  }

  int _completionStreak(
    SharedPreferences store,
    String featureId, {
    required DateTime anchorDate,
  }) {
    final completedDates =
        (store.getStringList(_historyKey(featureId)) ?? <String>[]).toSet();
    var cursor = _dateOnly(anchorDate);
    var streak = 0;
    while (completedDates.contains(formatDateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  FeatureStrategyFocusActionState? _readState(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return FeatureStrategyFocusActionState(
        featureId: decoded['featureId']?.toString() ?? '',
        dateKey: decoded['dateKey']?.toString() ?? '',
        completed: decoded['completed'] == true,
        deferred: decoded['deferred'] == true,
        completedAt: _parseDate(decoded['completedAt']),
        deferredAt: _parseDate(decoded['deferredAt']),
        completionStreakDays: 0,
        cloudSynced: decoded['cloudSynced'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _encodeState(FeatureStrategyFocusActionState state) {
    return jsonEncode(<String, Object?>{
      'featureId': state.featureId,
      'dateKey': state.dateKey,
      'completed': state.completed,
      'deferred': state.deferred,
      'completedAt': state.completedAt?.toIso8601String(),
      'deferredAt': state.deferredAt?.toIso8601String(),
      'cloudSynced': state.cloudSynced,
    });
  }
}

DateTime? _parseDateValue(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _normalizeDateKey(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 10) {
    return trimmed.substring(0, 10);
  }
  return trimmed;
}

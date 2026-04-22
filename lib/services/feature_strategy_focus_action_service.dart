import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feature_strategy_monitor.dart';

class FeatureStrategyFocusActionState {
  final String featureId;
  final String dateKey;
  final bool completed;
  final bool deferred;
  final DateTime? completedAt;
  final DateTime? deferredAt;
  final int completionStreakDays;

  const FeatureStrategyFocusActionState({
    required this.featureId,
    required this.dateKey,
    required this.completed,
    required this.deferred,
    required this.completedAt,
    required this.deferredAt,
    required this.completionStreakDays,
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
}

class FeatureStrategyFocusActionService {
  static const _statePrefix = 'feature_strategy_focus_action_state_v1';
  static const _historyPrefix = 'feature_strategy_focus_completion_history_v1';
  static const _deferHistoryPrefix = 'feature_strategy_focus_defer_history_v1';

  const FeatureStrategyFocusActionService();

  Future<FeatureStrategyFocusActionState> loadState(
    FeatureStrategyFocusRecommendation recommendation, {
    DateTime? now,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final today = _dateOnly(now ?? DateTime.now());
    final dateKey = formatDateKey(today);
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
    return state;
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
    return state;
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
    });
  }
}

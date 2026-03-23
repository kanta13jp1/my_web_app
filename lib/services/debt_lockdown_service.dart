import 'dart:convert';

import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebtLockdownRule {
  const DebtLockdownRule({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class DebtLockdownViolation {
  const DebtLockdownViolation({
    required this.id,
    required this.category,
    required this.note,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String note;
  final double amount;
  final DateTime createdAt;

  factory DebtLockdownViolation.fromJson(Map<String, dynamic> json) {
    return DebtLockdownViolation(
      id: json['id']?.toString() ?? '',
      category:
          json['category']?.toString() ?? DebtLockdownService.otherCategory,
      note: json['note']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'note': note,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class DebtLockdownSnapshot {
  const DebtLockdownSnapshot({
    required this.remainingDebt,
    required this.isEnabled,
    required this.isReleased,
    required this.startedAt,
    required this.rules,
    required this.completedRuleIds,
    required this.todayViolations,
    required this.currentCompliantStreakDays,
    required this.recentViolations,
  });

  final double remainingDebt;
  final bool isEnabled;
  final bool isReleased;
  final DateTime? startedAt;
  final List<DebtLockdownRule> rules;
  final Set<String> completedRuleIds;
  final List<DebtLockdownViolation> todayViolations;
  final int currentCompliantStreakDays;
  final List<DebtLockdownViolation> recentViolations;

  bool get isActive => isEnabled && !isReleased;

  int get completedRuleCount => completedRuleIds.length;

  bool get allRulesCompletedToday => completedRuleIds.length >= rules.length;
}

class DebtLockdownService {
  const DebtLockdownService({
    this.nowProvider,
  });

  static const String otherCategory = 'その他';

  static const List<DebtLockdownRule> builtinRules = <DebtLockdownRule>[
    DebtLockdownRule(
      id: 'essentials_only',
      label: '必需品以外に金を使わない',
      description: '生活維持と返済に関係しない支出を増やさない。',
    ),
    DebtLockdownRule(
      id: 'no_waste_spending',
      label: '浪費カテゴリをゼロにする',
      description: '酒、たばこ、夜遊び、ギャンブル、課金を禁止する。',
    ),
    DebtLockdownRule(
      id: 'daily_debt_check',
      label: '残債と家計を毎日1回確認する',
      description: '逃避せず、残債・支出・返済計画を見直す。',
    ),
    DebtLockdownRule(
      id: 'one_repayment_action',
      label: '返済前進アクションを1件やる',
      description: '返済、収入増、固定費削減のどれかを必ず進める。',
    ),
    DebtLockdownRule(
      id: 'no_new_escape',
      label: '新しい逃避を始めない',
      description: '新規サブスク、趣味買い、勉強のつまみ食いを増やさない。',
    ),
  ];

  static const String _enabledKey = 'debt_lockdown_enabled_v1';
  static const String _startedAtKey = 'debt_lockdown_started_at_v1';
  static const String _historyKey = 'debt_lockdown_history_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  static List<String> get violationCategories => <String>[
        ...WasteTrackingService.categoryLabels,
        otherCategory,
      ];

  Future<DebtLockdownSnapshot> loadSnapshot({
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final now = _now();
    final history = _readHistory(store.getString(_historyKey));
    final isReleased = remainingDebt <= 0;
    final storedEnabled = store.getBool(_enabledKey) ?? false;

    if (isReleased && storedEnabled) {
      await store.setBool(_enabledKey, false);
    }

    final todayRecord = history[_dateKey(now)] ?? _emptyDayRecord();

    return DebtLockdownSnapshot(
      remainingDebt: remainingDebt,
      isEnabled: !isReleased && storedEnabled,
      isReleased: isReleased,
      startedAt: _parseDate(store.getString(_startedAtKey)),
      rules: builtinRules,
      completedRuleIds: _readCompletedRuleIds(todayRecord),
      todayViolations: _sortViolations(_readViolations(todayRecord)),
      currentCompliantStreakDays: _calculateCompliantStreak(history, now: now),
      recentViolations: _recentViolations(history),
    );
  }

  Future<DebtLockdownSnapshot> setEnabled(
    bool enabled, {
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (enabled && remainingDebt <= 0) {
      await store.setBool(_enabledKey, false);
      return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
    }

    await store.setBool(_enabledKey, enabled);
    if (enabled && (store.getString(_startedAtKey) ?? '').isEmpty) {
      await store.setString(_startedAtKey, _now().toUtc().toIso8601String());
    }
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<DebtLockdownSnapshot> toggleRule(
    String ruleId,
    bool completed, {
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    if (!builtinRules.any((rule) => rule.id == ruleId)) {
      throw ArgumentError.value(ruleId, 'ruleId', 'unknown rule');
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(_now());
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final completedRuleIds = _readCompletedRuleIds(todayRecord);

    if (completed) {
      completedRuleIds.add(ruleId);
    } else {
      completedRuleIds.remove(ruleId);
    }

    todayRecord['completed_rule_ids'] = completedRuleIds.toList()..sort();
    todayRecord['updated_at'] = _now().toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<DebtLockdownSnapshot> recordViolation({
    required String category,
    required String note,
    required double amount,
    required double remainingDebt,
    SharedPreferences? prefs,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('note must not be empty');
    }

    final normalizedCategory =
        WasteTrackingService.normalizeCategory(category) ??
            (category.trim().isEmpty ? otherCategory : category.trim());
    final store = prefs ?? await SharedPreferences.getInstance();
    final now = _now();
    final history = _readHistory(store.getString(_historyKey));
    final todayKey = _dateKey(now);
    final todayRecord = Map<String, dynamic>.from(
      history[todayKey] ?? _emptyDayRecord(),
    );
    final violations = _readViolations(todayRecord);

    violations.add(
      DebtLockdownViolation(
        id: 'debt_lockdown_${now.microsecondsSinceEpoch}_${violations.length}',
        category: normalizedCategory,
        note: trimmedNote,
        amount: amount,
        createdAt: now,
      ),
    );

    todayRecord['violations'] =
        violations.map((entry) => entry.toJson()).toList();
    todayRecord['updated_at'] = now.toUtc().toIso8601String();
    history[todayKey] = todayRecord;

    await _saveHistory(store, history);
    return loadSnapshot(remainingDebt: remainingDebt, prefs: store);
  }

  Future<void> _saveHistory(
    SharedPreferences store,
    Map<String, Map<String, dynamic>> history,
  ) async {
    await store.setString(_historyKey, jsonEncode(history));
  }

  Map<String, Map<String, dynamic>> _readHistory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Map<String, dynamic>>{};
      }

      final history = <String, Map<String, dynamic>>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! Map) {
          return;
        }
        history[key] = Map<String, dynamic>.from(value);
      });
      return history;
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  Map<String, dynamic> _emptyDayRecord() {
    return <String, dynamic>{
      'completed_rule_ids': <String>[],
      'violations': <Map<String, dynamic>>[],
    };
  }

  Set<String> _readCompletedRuleIds(Map<String, dynamic> record) {
    return ((record['completed_rule_ids'] as List<dynamic>?) ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  List<DebtLockdownViolation> _readViolations(Map<String, dynamic> record) {
    return ((record['violations'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map(
          (entry) =>
              DebtLockdownViolation.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  List<DebtLockdownViolation> _sortViolations(
    List<DebtLockdownViolation> values,
  ) {
    final sorted = List<DebtLockdownViolation>.from(values);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<DebtLockdownViolation> _recentViolations(
    Map<String, Map<String, dynamic>> history,
  ) {
    final values =
        history.values.expand(_readViolations).toList(growable: false);
    final sorted = _sortViolations(values);
    if (sorted.length <= 5) {
      return sorted;
    }
    return sorted.take(5).toList(growable: false);
  }

  int _calculateCompliantStreak(
    Map<String, Map<String, dynamic>> history, {
    required DateTime now,
  }) {
    var streak = 0;
    var current = DateTime(now.year, now.month, now.day);

    while (true) {
      final record = history[_dateKey(current)];
      if (record == null) {
        break;
      }

      final hasViolations = _readViolations(record).isNotEmpty;
      final completedRuleIds = _readCompletedRuleIds(record);
      final isCompliant =
          !hasViolations && completedRuleIds.length >= builtinRules.length;
      if (!isCompliant) {
        break;
      }

      streak += 1;
      current = current.subtract(const Duration(days: 1));
    }

    return streak;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

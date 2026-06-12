import 'dart:convert';

import 'package:my_web_app/services/asset_payment_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 入金予定(給料・振込など)。カレンダーの見込み残高に加算され、
/// 残高ショート警告の精度を上げる。端末ローカル保存のみ。
class AssetExpectedInflow {
  const AssetExpectedInflow({
    required this.id,
    required this.date,
    required this.amount,
    required this.label,
    this.sourceRuleId,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String label;

  /// 繰り返しルール由来の場合、その元ルールID(実体は保存しない)。
  final String? sourceRuleId;

  factory AssetExpectedInflow.fromJson(Map<String, dynamic> json) {
    return AssetExpectedInflow(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date.toUtc().toIso8601String(),
      'amount': amount,
      'label': label,
    };
  }
}

/// 毎月の繰り返し入金ルール(給料・固定振込など)。
class AssetExpectedInflowRule {
  const AssetExpectedInflowRule({
    required this.id,
    required this.dayOfMonth,
    required this.amount,
    required this.label,
  });

  final String id;
  final int dayOfMonth;
  final double amount;
  final String label;

  factory AssetExpectedInflowRule.fromJson(Map<String, dynamic> json) {
    return AssetExpectedInflowRule(
      id: json['id']?.toString() ?? '',
      dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'day_of_month': dayOfMonth,
      'amount': amount,
      'label': label,
    };
  }
}

/// 入金予定の永続化ストア。
class AssetExpectedInflowStore {
  const AssetExpectedInflowStore({this.nowProvider});

  static const String _key = 'asset_expected_inflows_v1';
  static const String _rulesKey = 'asset_expected_inflow_rules_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  static List<AssetExpectedInflow> monthInflows(
    List<AssetExpectedInflow> inflows,
    DateTime month,
  ) {
    return inflows
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .toList(growable: false);
  }

  /// 単発の入金予定と繰り返しルールを、指定月の実体リストへ展開する。
  /// 31日ルールは短い月では月末へ丸める。
  static List<AssetExpectedInflow> materializeMonth({
    required List<AssetExpectedInflow> oneTime,
    required List<AssetExpectedInflowRule> rules,
    required DateTime month,
  }) {
    final monthKey = '${month.year}${month.month.toString().padLeft(2, '0')}';
    final entries = <AssetExpectedInflow>[
      ...monthInflows(oneTime, month),
      for (final rule in rules)
        if (rule.dayOfMonth > 0 && rule.amount > 0)
          AssetExpectedInflow(
            id: 'rule_${rule.id}_$monthKey',
            date: DateTime(
              month.year,
              month.month,
              AssetPaymentCalendarService.clampDayToMonth(
                rule.dayOfMonth,
                month,
              ),
            ),
            amount: rule.amount,
            label: rule.label,
            sourceRuleId: rule.id,
          ),
    ];
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  Future<List<AssetExpectedInflowRule>> loadRules({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _decodeRules(store.getString(_rulesKey));
  }

  Future<List<AssetExpectedInflowRule>> addRule({
    required int dayOfMonth,
    required double amount,
    required String label,
    SharedPreferences? prefs,
  }) async {
    if (dayOfMonth < 1 || dayOfMonth > 31) {
      throw ArgumentError('dayOfMonth must be 1-31');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final trimmedLabel = label.trim();
    final store = prefs ?? await SharedPreferences.getInstance();
    final rules = _decodeRules(store.getString(_rulesKey));
    rules.add(
      AssetExpectedInflowRule(
        id: 'inflow_rule_${_now().microsecondsSinceEpoch}_${rules.length}',
        dayOfMonth: dayOfMonth,
        amount: amount,
        label: trimmedLabel.isEmpty ? '毎月の入金' : trimmedLabel,
      ),
    );
    rules.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
    await _saveRules(store, rules);
    return rules;
  }

  Future<List<AssetExpectedInflowRule>> removeRule(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final rules = _decodeRules(store.getString(_rulesKey))
      ..removeWhere((rule) => rule.id == id);
    await _saveRules(store, rules);
    return rules;
  }

  Future<void> _saveRules(
    SharedPreferences store,
    List<AssetExpectedInflowRule> rules,
  ) async {
    await store.setString(
      _rulesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  List<AssetExpectedInflowRule> _decodeRules(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <AssetExpectedInflowRule>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <AssetExpectedInflowRule>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (entry) => AssetExpectedInflowRule.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((rule) => rule.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <AssetExpectedInflowRule>[];
    }
  }

  Future<List<AssetExpectedInflow>> loadAll({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _decode(store.getString(_key));
  }

  Future<List<AssetExpectedInflow>> add({
    required DateTime date,
    required double amount,
    required String label,
    SharedPreferences? prefs,
  }) async {
    final trimmedLabel = label.trim();
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final store = prefs ?? await SharedPreferences.getInstance();
    final entries = _decode(store.getString(_key));
    entries.add(
      AssetExpectedInflow(
        id: 'inflow_${_now().microsecondsSinceEpoch}_${entries.length}',
        date: DateTime(date.year, date.month, date.day),
        amount: amount,
        label: trimmedLabel.isEmpty ? '入金予定' : trimmedLabel,
      ),
    );
    entries.sort((a, b) => a.date.compareTo(b.date));
    await _save(store, entries);
    return entries;
  }

  Future<List<AssetExpectedInflow>> remove(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final entries = _decode(store.getString(_key))
      ..removeWhere((entry) => entry.id == id);
    await _save(store, entries);
    return entries;
  }

  Future<void> _save(
    SharedPreferences store,
    List<AssetExpectedInflow> entries,
  ) async {
    await store.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  List<AssetExpectedInflow> _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <AssetExpectedInflow>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <AssetExpectedInflow>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                AssetExpectedInflow.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <AssetExpectedInflow>[];
    }
  }
}

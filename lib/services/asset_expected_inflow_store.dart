import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 入金予定(給料・振込など)。カレンダーの見込み残高に加算され、
/// 残高ショート警告の精度を上げる。端末ローカル保存のみ。
class AssetExpectedInflow {
  const AssetExpectedInflow({
    required this.id,
    required this.date,
    required this.amount,
    required this.label,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String label;

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

/// 入金予定の永続化ストア。
class AssetExpectedInflowStore {
  const AssetExpectedInflowStore({this.nowProvider});

  static const String _key = 'asset_expected_inflows_v1';

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

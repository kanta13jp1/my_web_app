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

/// トゥームストーン GC の上限/期限。既定はローカル定数だが、サーバ
/// (asset_pref_mirror) から取得した値で上書きできる (#part287 リモート調整)。
class AssetTombstoneGcConfig {
  const AssetTombstoneGcConfig({
    this.maxCount = 1000,
    this.maxAgeDays = 365,
  });

  final int maxCount;
  final int maxAgeDays;

  /// ミラー値 (`{'max_count': N, 'max_age_days': M}`) から構築する。
  /// 欠落/不正値は既定を維持し、正の範囲にクランプする。
  factory AssetTombstoneGcConfig.fromMirrorValue(Object? value) {
    const fallback = AssetTombstoneGcConfig();
    if (value is! Map) {
      return fallback;
    }
    int pick(String key, int fallbackValue, int min, int max) {
      final raw = (value[key] as num?)?.toInt();
      if (raw == null) {
        return fallbackValue;
      }
      return raw.clamp(min, max);
    }

    return AssetTombstoneGcConfig(
      maxCount: pick('max_count', fallback.maxCount, 1, 100000),
      maxAgeDays: pick('max_age_days', fallback.maxAgeDays, 1, 36500),
    );
  }
}

/// 入金予定の永続化ストア。
class AssetExpectedInflowStore {
  const AssetExpectedInflowStore({
    this.nowProvider,
    this.gcConfig = const AssetTombstoneGcConfig(),
  });

  static const String _key = 'asset_expected_inflows_v1';
  static const String _rulesKey = 'asset_expected_inflow_rules_v1';

  /// 削除済み ID のトゥームストーン。和集合マージやサーバ復元で
  /// 「一度消した項目」がサーバ残存分から復活するのを抑止する (#part285)。
  static const String _deletedIdsKey = 'asset_expected_inflow_deleted_ids_v1';

  /// トゥームストーンの保持上限/期限 (#part286 GC / #part287 リモート調整可)。
  final AssetTombstoneGcConfig gcConfig;

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
    await _addDeletedId(store, id);
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

  /// 削除済み ID の集合を読み出す (期限切れ・上限超過は除外)。
  Future<Set<String>> loadDeletedIds({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _decodeActiveIds(store.getString(_deletedIdsKey));
  }

  /// トゥームストーン ID 集合をミラー upsert 用の値へ変換する
  /// (`{'ids': [...]}`)。ページと統合テストで同一の形を共有する (#part287)。
  static Map<String, dynamic> encodeDeletedIdsMirror(Iterable<String> ids) {
    return <String, dynamic>{
      'ids': [
        for (final id in ids)
          if (id.isNotEmpty) id,
      ],
    };
  }

  /// ミラー値 (`{'ids': [...]}`) から ID リストを取り出す。形が不正なら空。
  static List<String> decodeDeletedIdsMirror(Object? value) {
    if (value is! Map) {
      return const <String>[];
    }
    final rawIds = value['ids'];
    if (rawIds is! List) {
      return const <String>[];
    }
    return <String>[
      for (final id in rawIds)
        if ((id?.toString() ?? '').isNotEmpty) id.toString(),
    ];
  }

  Future<void> _addDeletedId(SharedPreferences store, String id) async {
    if (id.isEmpty) {
      return;
    }
    final entries = _gcEntries(
      _readDeletedEntries(store.getString(_deletedIdsKey)),
    )..removeWhere((entry) => entry['id'] == id);
    entries.add(<String, String>{
      'id': id,
      'at': _now().toUtc().toIso8601String(),
    });
    await _writeDeletedEntries(store, entries);
  }

  /// 後方互換読み込み: 旧形式 (["id",...]) と新形式 ([{"id","at"},...]) の
  /// 双方を受け付ける。旧形式やタイムスタンプ欠落は現時刻を付与する
  /// (= 既存トゥームストーンを即時に期限切れさせない)。
  List<Map<String, String>> _readDeletedEntries(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, String>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, String>>[];
      }
      final nowIso = _now().toUtc().toIso8601String();
      final entries = <Map<String, String>>[];
      for (final entry in decoded) {
        if (entry is String) {
          if (entry.isNotEmpty) {
            entries.add(<String, String>{'id': entry, 'at': nowIso});
          }
        } else if (entry is Map) {
          final id = entry['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            entries.add(<String, String>{
              'id': id,
              'at': entry['at']?.toString() ?? nowIso,
            });
          }
        }
      }
      return entries;
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  /// 期限切れ (>gcConfig.maxAgeDays) を捨て、件数超過分は新しい順に残す。
  List<Map<String, String>> _gcEntries(List<Map<String, String>> entries) {
    final now = _now();
    final maxAgeDays = gcConfig.maxAgeDays;
    final kept = <Map<String, String>>[];
    for (final entry in entries) {
      final at = DateTime.tryParse(entry['at'] ?? '');
      if (at == null || now.difference(at).inDays <= maxAgeDays) {
        kept.add(entry);
      }
    }
    if (kept.length > gcConfig.maxCount) {
      return kept.sublist(kept.length - gcConfig.maxCount);
    }
    return kept;
  }

  Future<void> _writeDeletedEntries(
    SharedPreferences store,
    List<Map<String, String>> entries,
  ) async {
    await store.setString(_deletedIdsKey, jsonEncode(entries));
  }

  Set<String> _decodeActiveIds(String? raw) {
    return <String>{
      for (final entry in _gcEntries(_readDeletedEntries(raw))) entry['id']!,
    };
  }

  /// 他端末由来のトゥームストーンを取り込み、該当するローカル項目を削除する。
  /// 端末Bでの削除を端末Aへ伝播させる用途。削除した件数を返す。
  Future<int> applyRemoteDeletedIds(
    Iterable<String> remoteIds, {
    SharedPreferences? prefs,
  }) async {
    final incoming = remoteIds.where((id) => id.isNotEmpty).toSet();
    if (incoming.isEmpty) {
      return 0;
    }
    final store = prefs ?? await SharedPreferences.getInstance();
    final entries = _gcEntries(
      _readDeletedEntries(store.getString(_deletedIdsKey)),
    );
    final existingIds = <String>{for (final entry in entries) entry['id']!};
    final nowIso = _now().toUtc().toIso8601String();
    for (final id in incoming) {
      if (existingIds.add(id)) {
        entries.add(<String, String>{'id': id, 'at': nowIso});
      }
    }
    await _writeDeletedEntries(store, _gcEntries(entries));

    final items = _decode(store.getString(_key));
    final rules = _decodeRules(store.getString(_rulesKey));
    final beforeItems = items.length;
    final beforeRules = rules.length;
    items.removeWhere((item) => incoming.contains(item.id));
    rules.removeWhere((rule) => incoming.contains(rule.id));
    final removed = (beforeItems - items.length) + (beforeRules - rules.length);
    if (removed > 0) {
      await _save(store, items);
      await _saveRules(store, rules);
    }
    return removed;
  }

  /// サーバミラー行からの復元 (#3246 v1)。安全側に倒し、ローカルが
  /// 完全に空の場合のみ全置換する(既存ローカルがあれば何もしない)。
  /// トゥームストーン済み ID は復元対象から除外する。
  Future<bool> restoreFromMirrorRows(
    List<Map<String, dynamic>> rows, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final localItems = _decode(store.getString(_key));
    final localRules = _decodeRules(store.getString(_rulesKey));
    if (localItems.isNotEmpty || localRules.isNotEmpty || rows.isEmpty) {
      return false;
    }
    final deletedIds = _decodeActiveIds(store.getString(_deletedIdsKey));
    final items = <AssetExpectedInflow>[];
    final rules = <AssetExpectedInflowRule>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final label = row['label']?.toString() ?? '';
      if (id.isEmpty || amount <= 0 || deletedIds.contains(id)) {
        continue;
      }
      if (row['kind']?.toString() == 'rule') {
        final day = (row['day_of_month'] as num?)?.toInt() ?? 0;
        if (day >= 1 && day <= 31) {
          rules.add(
            AssetExpectedInflowRule(
              id: id,
              dayOfMonth: day,
              amount: amount,
              label: label,
            ),
          );
        }
      } else {
        final date =
            DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
        if (date != null) {
          items.add(
            AssetExpectedInflow(
              id: id,
              date: DateTime(date.year, date.month, date.day),
              amount: amount,
              label: label,
            ),
          );
        }
      }
    }
    if (items.isEmpty && rules.isEmpty) {
      return false;
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    rules.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
    await _save(store, items);
    await _saveRules(store, rules);
    return true;
  }

  /// ミラーとの手動統合: ローカルに無い ID のみ追加する和集合マージ。
  /// トゥームストーン済み (ローカルで明示削除した) ID はスキップするため、
  /// サーバに残っていても復活しない (#part285 本対策)。
  Future<int> mergeFromMirrorRows(
    List<Map<String, dynamic>> rows, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final items = _decode(store.getString(_key));
    final rules = _decodeRules(store.getString(_rulesKey));
    final deletedIds = _decodeActiveIds(store.getString(_deletedIdsKey));
    final knownIds = <String>{
      for (final item in items) item.id,
      for (final rule in rules) rule.id,
    };
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final label = row['label']?.toString() ?? '';
      if (id.isEmpty ||
          amount <= 0 ||
          knownIds.contains(id) ||
          deletedIds.contains(id)) {
        continue;
      }
      if (row['kind']?.toString() == 'rule') {
        final day = (row['day_of_month'] as num?)?.toInt() ?? 0;
        if (day < 1 || day > 31) {
          continue;
        }
        rules.add(
          AssetExpectedInflowRule(
            id: id,
            dayOfMonth: day,
            amount: amount,
            label: label,
          ),
        );
      } else {
        final date =
            DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
        if (date == null) {
          continue;
        }
        items.add(
          AssetExpectedInflow(
            id: id,
            date: DateTime(date.year, date.month, date.day),
            amount: amount,
            label: label,
          ),
        );
      }
      added += 1;
    }
    if (added == 0) {
      return 0;
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    rules.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
    await _save(store, items);
    await _saveRules(store, rules);
    return added;
  }

  /// 取り込み前プレビュー用: [mergeFromMirrorRows] と同じガード
  /// (既知 ID / トゥームストーン / 不正値の除外) を通過して「実際に追加される」
  /// 行だけを返す。保存はしない。件数は merge の戻り値と一致する。
  Future<List<Map<String, dynamic>>> previewMergeAdditions(
    List<Map<String, dynamic>> rows, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final items = _decode(store.getString(_key));
    final rules = _decodeRules(store.getString(_rulesKey));
    final deletedIds = _decodeActiveIds(store.getString(_deletedIdsKey));
    final knownIds = <String>{
      for (final item in items) item.id,
      for (final rule in rules) rule.id,
    };
    final additions = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (id.isEmpty ||
          amount <= 0 ||
          knownIds.contains(id) ||
          deletedIds.contains(id)) {
        continue;
      }
      if (row['kind']?.toString() == 'rule') {
        final day = (row['day_of_month'] as num?)?.toInt() ?? 0;
        if (day < 1 || day > 31) {
          continue;
        }
      } else if (DateTime.tryParse(row['date']?.toString() ?? '') == null) {
        continue;
      }
      additions.add(row);
    }
    return additions;
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
    await _addDeletedId(store, id);
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

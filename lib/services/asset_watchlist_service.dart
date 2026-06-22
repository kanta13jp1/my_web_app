import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AssetWatchlistEntry {
  final String assetType;
  final String group;
  final String memo;
  final DateTime addedAt;

  const AssetWatchlistEntry({
    required this.assetType,
    required this.group,
    required this.memo,
    required this.addedAt,
  });

  factory AssetWatchlistEntry.fromJson(Map<String, dynamic> json) {
    return AssetWatchlistEntry(
      assetType: (json['assetType'] as String? ?? '').trim(),
      group: (json['group'] as String? ?? '').trim(),
      memo: (json['memo'] as String? ?? '').trim(),
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'assetType': assetType,
      'group': group,
      'memo': memo,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  AssetWatchlistEntry copyWith({
    String? assetType,
    String? group,
    String? memo,
    DateTime? addedAt,
  }) {
    return AssetWatchlistEntry(
      assetType: assetType ?? this.assetType,
      group: group ?? this.group,
      memo: memo ?? this.memo,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

/// ウォッチリスト項目を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `watchlist_entries`) へ 1 行 jsonb でミラーする
/// (リボ設定と同じ集約方針 / MIRROR_PREF_SCHEMA.md)。
/// [encodeMirrorValue] / [decodeMirrorValue] がその往復、[replaceAll] が
/// ミラー復元時の一括ローカル書き戻しを担う。
class AssetWatchlistService {
  static const String _storageKey = 'asset_watchlist_entries_v1';

  const AssetWatchlistService();

  Future<List<AssetWatchlistEntry>> loadEntries({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final encoded = store.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <AssetWatchlistEntry>[];
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      return const <AssetWatchlistEntry>[];
    }

    final entries = <AssetWatchlistEntry>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final entry = AssetWatchlistEntry.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (entry.assetType.isEmpty) {
        continue;
      }
      entries.add(entry);
    }

    return _sortEntries(entries);
  }

  Future<List<AssetWatchlistEntry>> saveEntry(
    AssetWatchlistEntry entry, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadEntries(prefs: prefs);
    final normalized = entry.copyWith(
      assetType: entry.assetType.trim(),
      group: entry.group.trim(),
      memo: entry.memo.trim(),
    );

    if (normalized.assetType.isEmpty) {
      return current;
    }

    final next = <AssetWatchlistEntry>[
      for (final item in current)
        if (item.assetType != normalized.assetType) item,
      normalized,
    ];

    return _persistEntries(next, prefs: prefs);
  }

  Future<List<AssetWatchlistEntry>> removeEntry(
    String assetType, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadEntries(prefs: prefs);
    final next = current.where((item) => item.assetType != assetType).toList();
    return _persistEntries(next, prefs: prefs);
  }

  /// 全件を一括で置き換えて永続化する (ミラー復元時のローカル書き戻し用)。
  Future<List<AssetWatchlistEntry>> replaceAll(
    List<AssetWatchlistEntry> entries, {
    SharedPreferences? prefs,
  }) async {
    return _persistEntries(entries, prefs: prefs);
  }

  Future<List<AssetWatchlistEntry>> _persistEntries(
    List<AssetWatchlistEntry> entries, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final sorted = _sortEntries(entries);
    final encoded = jsonEncode(
      sorted.map((entry) => entry.toJson()).toList(),
    );
    await store.setString(_storageKey, encoded);
    return sorted;
  }

  /// ウォッチリストを `asset_pref_mirror.value` (jsonb) 形へ変換する
  /// (`{entries: [...]}`)。
  static Map<String, dynamic> encodeMirrorValue(
    List<AssetWatchlistEntry> entries,
  ) {
    return <String, dynamic>{
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }

  /// `asset_pref_mirror.value` (jsonb) からウォッチリストを復元する。
  /// 不正な要素・assetType 空は捨てる寛容なパース (前方/後方互換)。
  static List<AssetWatchlistEntry> decodeMirrorValue(dynamic value) {
    if (value is! Map) {
      return const <AssetWatchlistEntry>[];
    }
    final rawEntries = value['entries'];
    if (rawEntries is! List) {
      return const <AssetWatchlistEntry>[];
    }
    final entries = <AssetWatchlistEntry>[];
    for (final item in rawEntries) {
      if (item is! Map) {
        continue;
      }
      final entry = AssetWatchlistEntry.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (entry.assetType.isEmpty) {
        continue;
      }
      entries.add(entry);
    }
    return entries;
  }

  List<AssetWatchlistEntry> _sortEntries(List<AssetWatchlistEntry> entries) {
    final sorted = List<AssetWatchlistEntry>.from(entries);
    sorted.sort((a, b) {
      final groupA = a.group.trim();
      final groupB = b.group.trim();
      if (groupA.isEmpty && groupB.isNotEmpty) {
        return 1;
      }
      if (groupA.isNotEmpty && groupB.isEmpty) {
        return -1;
      }

      final groupCompare = groupA.toLowerCase().compareTo(groupB.toLowerCase());
      if (groupCompare != 0) {
        return groupCompare;
      }

      final typeCompare =
          a.assetType.toLowerCase().compareTo(b.assetType.toLowerCase());
      if (typeCompare != 0) {
        return typeCompare;
      }

      return a.addedAt.compareTo(b.addedAt);
    });
    return sorted;
  }
}

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

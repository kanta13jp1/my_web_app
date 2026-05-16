import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'one_in_two_out_assist_service.dart';

class HomeToolUsageService {
  static const String _recentToolsKey = 'home_recent_tool_ids_v1';
  static const String _usageCountsKey = 'home_tool_usage_counts_v1';
  static const String _lastUsedAtKey = 'home_tool_last_used_at_v1';
  static const int _maxRecentTools = 6;

  static Future<List<String>> loadRecentToolIds({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return List<String>.from(store.getStringList(_recentToolsKey) ?? const []);
  }

  static Future<void> recordToolUse(
    String toolId, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final existing = List<String>.from(
      store.getStringList(_recentToolsKey) ?? const [],
    );
    final next = <String>[
      toolId,
      ...existing.where((entry) => entry != toolId),
    ].take(_maxRecentTools).toList();
    await store.setStringList(_recentToolsKey, next);

    final counts = _decodeIntMap(store.getString(_usageCountsKey));
    counts[toolId] = (counts[toolId] ?? 0) + 1;
    await store.setString(_usageCountsKey, jsonEncode(counts));

    final lastUsedAt = _decodeStringMap(store.getString(_lastUsedAtKey));
    lastUsedAt[toolId] = (now ?? DateTime.now()).toUtc().toIso8601String();
    await store.setString(_lastUsedAtKey, jsonEncode(lastUsedAt));
  }

  static Future<List<WidgetUsageSignal>> loadUsageSignals({
    required Iterable<HomeToolUsageCandidate> candidates,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final counts = _decodeIntMap(store.getString(_usageCountsKey));
    final lastUsedAt = _decodeStringMap(store.getString(_lastUsedAtKey));

    return candidates
        .map(
          (candidate) => WidgetUsageSignal(
            id: candidate.id,
            title: candidate.title,
            sectionId: candidate.sectionId,
            routePath: candidate.routePath,
            openCount: counts[candidate.id] ?? 0,
            lastUsedAt: _tryParseDateTime(lastUsedAt[candidate.id]),
            isPinned: candidate.isPinned,
            isVisible: candidate.isVisible,
          ),
        )
        .toList(growable: false);
  }

  static Future<void> clear({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.remove(_recentToolsKey);
    await store.remove(_usageCountsKey);
    await store.remove(_lastUsedAtKey);
  }

  static Map<String, int> _decodeIntMap(String? value) {
    if (value == null || value.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (key, rawValue) => MapEntry(
          key.toString(),
          rawValue is num ? rawValue.toInt() : int.tryParse('$rawValue') ?? 0,
        ),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  static Map<String, String> _decodeStringMap(String? value) {
    if (value == null || value.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return <String, String>{};
      return decoded
          .map((key, rawValue) => MapEntry(key.toString(), '$rawValue'));
    } catch (_) {
      return <String, String>{};
    }
  }

  static DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

class HomeToolUsageCandidate {
  const HomeToolUsageCandidate({
    required this.id,
    required this.title,
    required this.sectionId,
    this.routePath,
    this.isPinned = false,
    this.isVisible = true,
  });

  final String id;
  final String title;
  final String sectionId;
  final String? routePath;
  final bool isPinned;
  final bool isVisible;
}

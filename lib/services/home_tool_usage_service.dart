import 'package:shared_preferences/shared_preferences.dart';

class HomeToolUsageService {
  static const String _recentToolsKey = 'home_recent_tool_ids_v1';
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
  }

  static Future<void> clear({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.remove(_recentToolsKey);
  }
}

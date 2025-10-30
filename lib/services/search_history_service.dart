import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_history.dart';

class SearchHistoryService {
  static const String _key = 'search_history';
  static const int _maxHistoryCount = 10;

  // 検索履歴を保存
  static Future<void> saveSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    // 同じクエリがあれば削除（重複を避ける）
    history.removeWhere((item) => item.query == query);

    // 新しい検索を先頭に追加
    history.insert(
      0,
      SearchHistory(
        query: query,
        timestamp: DateTime.now(),
      ),
    );

    // 最大件数を超えたら古いものを削除
    if (history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    // 保存
    final jsonList = history.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  // 検索履歴を取得
  static Future<List<SearchHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList
        .map((json) => SearchHistory.fromJson(json))
        .toList();
  }

  // 検索履歴を削除
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // 特定の検索履歴を削除
  static Future<void> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    history.removeWhere((item) => item.query == query);

    final jsonList = history.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
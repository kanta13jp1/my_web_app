import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 定期取引の自動検出で「この候補を無視」したラベル(正規化済み)を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `recurring_suggestion_ignored`) へ 1 行 jsonb
/// 配列でミラーする。無視集合は単調増加(union)前提のため tombstone は不要
/// (再表示はローカル操作で対応)。保存形は文字列の JSON 配列。
class AssetRecurringSuggestionIgnoreStore {
  static const String prefsKey = 'asset_recurring_ignored_v1';

  const AssetRecurringSuggestionIgnoreStore();

  Future<Set<String>> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> save(Set<String> labels, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final encoded = encodeMirrorValue(labels);
    if (encoded.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    await store.setString(prefsKey, jsonEncode(encoded));
  }

  /// 集合を `asset_pref_mirror.value` (jsonb) 用の安定ソート済み配列へ変換する。
  /// 空白のみのラベルは捨てる。
  static List<String> encodeMirrorValue(Set<String> labels) {
    final cleaned = <String>{
      for (final label in labels)
        if (label.trim().isNotEmpty) label.trim(),
    }.toList()
      ..sort();
    return cleaned;
  }

  /// `asset_pref_mirror.value` (jsonb 配列) または保存済み JSON から集合へ復元する。
  /// 配列でなければ空集合(寛容なパース)。
  static Set<String> decodeMirrorValue(dynamic value) {
    if (value is! List) {
      return <String>{};
    }
    final result = <String>{};
    for (final item in value) {
      final label = item?.toString().trim() ?? '';
      if (label.isNotEmpty) {
        result.add(label);
      }
    }
    return result;
  }
}

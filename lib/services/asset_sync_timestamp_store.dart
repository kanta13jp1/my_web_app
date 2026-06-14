import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 集約 pref ドメインのローカル最終変更時刻 (`updated_at`) を pref_key ごとに
/// 1 つの SharedPreferences キーへ集約保存する。
///
/// Supabase 正本化 Phase B の last-write-wins 判定で、ローカル変更とサーバ
/// `asset_pref_mirror.updated_at` を比較するために使う
/// ([AssetMirrorReadPolicy] / resolveMirrorRead)。
class AssetSyncTimestampStore {
  static const String prefsKey = 'asset_sync_timestamps_v1';

  const AssetSyncTimestampStore();

  Future<Map<String, DateTime>> loadAll({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, DateTime>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, DateTime>{};
      }
      final result = <String, DateTime>{};
      decoded.forEach((key, value) {
        if (key is String && value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) {
            result[key] = parsed;
          }
        }
      });
      return result;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  Future<DateTime?> loadTimestamp(
    String prefKey, {
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all[prefKey];
  }

  /// [prefKey] のローカル変更時刻を [at] (既定は現在時刻) で記録する。
  Future<void> markChanged(
    String prefKey, {
    DateTime? at,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: store);
    all[prefKey] = (at ?? DateTime.now()).toUtc();
    final encoded = jsonEncode(<String, String>{
      for (final entry in all.entries)
        entry.key: entry.value.toUtc().toIso8601String(),
    });
    await store.setString(prefsKey, encoded);
  }
}

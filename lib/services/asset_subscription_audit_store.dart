import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// サブスク棚卸しの「支払い元ごとの最終確認日時」を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、資産管理ページが `asset_pref_mirror`
/// (pref_key: `subscription_audit_state`) へ 1 行 jsonb でミラーする (定期固定費と同方針)。
/// 保存形は `{sourceId: iso8601(UTC)}`。
///
/// 「確認した」は単調 (巻き戻らない) なので、端末間マージは **各 sourceId で最新時刻を
/// 採用する MAX マージ** ([mergeMax]) で十分。tombstone / dirty-key / LWW は不要。
class AssetSubscriptionAuditStore {
  static const String prefsKey = 'asset_subscription_audit_state_v1';

  const AssetSubscriptionAuditStore();

  Future<Map<String, DateTime>> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, DateTime>{};
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  Future<void> save(
    Map<String, DateTime> state, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    await store.setString(prefsKey, jsonEncode(encodeMirrorValue(state)));
  }

  /// `{sourceId: iso8601(UTC)}` へ変換する (ローカル保存とサーバミラー共通形)。
  static Map<String, dynamic> encodeMirrorValue(Map<String, DateTime> state) {
    return <String, dynamic>{
      for (final entry in state.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key: entry.value.toUtc().toIso8601String(),
    };
  }

  /// `asset_pref_mirror.value` または保存済み JSON から復元する。
  /// 非 String キー / パース不能な日時は黙って捨てる寛容なパース。時刻は UTC へ正規化。
  static Map<String, DateTime> decodeMirrorValue(dynamic value) {
    final result = <String, DateTime>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((dynamic key, dynamic raw) {
      if (key is! String || key.trim().isEmpty) {
        return;
      }
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      if (parsed != null) {
        result[key] = parsed.toUtc();
      }
    });
    return result;
  }

  /// 端末間マージ: キー和集合を取り、各 sourceId で **新しい方** の確認時刻を採用する。
  /// 単調なので順序非依存・冪等 (確認を取り消さない限り情報を失わない)。
  static Map<String, DateTime> mergeMax(
    Map<String, DateTime> a,
    Map<String, DateTime> b,
  ) {
    final result = <String, DateTime>{...a};
    b.forEach((key, value) {
      final existing = result[key];
      if (existing == null || value.isAfter(existing)) {
        result[key] = value;
      }
    });
    return result;
  }
}

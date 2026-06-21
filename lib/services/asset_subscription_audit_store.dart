import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// サブスク棚卸しの「支払い元ごとの最終確認日時」と「取り消し日時」を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、資産管理ページが `asset_pref_mirror`
/// (pref_key: `subscription_audit_state`) へ 1 行 jsonb でミラーする (定期固定費と同方針)。
///
/// 「確認した」は単調だが、誤クリックの取り消し / 確認解除を端末間で正しく伝播させるため、
/// 確認時刻 (checked) と並行して **取り消し時刻 (unconfirmed = tombstone)** も保持する。
/// 各マップを独立に [mergeMax] し、sourceId ごとに **新しい方の操作が勝つ**
/// ([effectiveCheckedAt]: checked > unconfirmed のときだけ確認済み)。これにより
/// confirm / unconfirm の双方が単調・順序非依存・冪等になり、キー削除で起きる誤復活
/// (他端末の古い確認時刻が MAX マージで蘇る) を避けられる。
///
/// ミラー保存形は v2 ネスト `{'v': 2, 'checked': {id: iso}, 'unconfirmed': {id: iso}}`。
/// 旧フラット形 `{id: iso}` (本番既存データ) は checked のみとして後方互換 decode する
/// ([decodeMirrorPayload])。ローカルは checked / unconfirmed を 2 キーに分けて保存する。
class AssetSubscriptionAuditStore {
  /// 確認時刻 (checked) のローカル保存キー。旧来からのキーで後方互換。
  static const String prefsKey = 'asset_subscription_audit_state_v1';

  /// 取り消し時刻 (unconfirmed = tombstone) のローカル保存キー。
  static const String unconfirmedPrefsKey =
      'asset_subscription_audit_unconfirmed_v1';

  const AssetSubscriptionAuditStore();

  Future<Map<String, DateTime>> load({SharedPreferences? prefs}) =>
      _loadKey(prefsKey, prefs: prefs);

  /// 取り消し時刻 (tombstone) をローカルから読み出す。
  Future<Map<String, DateTime>> loadUnconfirmed({SharedPreferences? prefs}) =>
      _loadKey(unconfirmedPrefsKey, prefs: prefs);

  Future<void> save(
    Map<String, DateTime> state, {
    SharedPreferences? prefs,
  }) =>
      _saveKey(prefsKey, state, prefs: prefs);

  /// 取り消し時刻 (tombstone) をローカルへ保存する。
  Future<void> saveUnconfirmed(
    Map<String, DateTime> state, {
    SharedPreferences? prefs,
  }) =>
      _saveKey(unconfirmedPrefsKey, state, prefs: prefs);

  Future<Map<String, DateTime>> _loadKey(
    String key, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(key);
    if (raw == null || raw.isEmpty) {
      return <String, DateTime>{};
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  Future<void> _saveKey(
    String key,
    Map<String, DateTime> state, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await store.remove(key);
      return;
    }
    await store.setString(key, jsonEncode(encodeMirrorValue(state)));
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

  /// 端末間マージ: キー和集合を取り、各 sourceId で **新しい方** の時刻を採用する。
  /// 単調なので順序非依存・冪等。checked / unconfirmed の両マップに同じく使う。
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

  /// confirm / unconfirm を突き合わせ、いま **確認済み** と判定できる sourceId だけを
  /// 残した確認時刻マップを返す (カードへ渡す `lastCheckedAt`)。
  /// 判定 = checked が存在し、かつ取り消し時刻より後 (= 最後の操作が確認)。
  static Map<String, DateTime> effectiveCheckedAt(
    Map<String, DateTime> checked,
    Map<String, DateTime> unconfirmed,
  ) {
    final result = <String, DateTime>{};
    checked.forEach((key, value) {
      final undone = unconfirmed[key];
      if (undone == null || value.isAfter(undone)) {
        result[key] = value;
      }
    });
    return result;
  }

  /// サーバミラー (`asset_pref_mirror.value`) 用に checked / unconfirmed をまとめた
  /// v2 ネスト形へ変換する。
  static Map<String, dynamic> encodeMirrorPayload(
    Map<String, DateTime> checked,
    Map<String, DateTime> unconfirmed,
  ) {
    return <String, dynamic>{
      'v': 2,
      'checked': encodeMirrorValue(checked),
      'unconfirmed': encodeMirrorValue(unconfirmed),
    };
  }

  /// サーバミラー / 保存値から checked / unconfirmed を復元する。
  /// v2 ネスト形 (`{'checked': {...}, 'unconfirmed': {...}}`) と、旧フラット形
  /// `{id: iso}` (= checked のみ) の両方を受ける後方互換 decode。
  static ({Map<String, DateTime> checked, Map<String, DateTime> unconfirmed})
      decodeMirrorPayload(dynamic value) {
    if (value is Map && value['checked'] is Map) {
      return (
        checked: decodeMirrorValue(value['checked']),
        unconfirmed: decodeMirrorValue(value['unconfirmed']),
      );
    }
    // 旧フラット形: 全て確認時刻として扱い、取り消しは無し。
    return (
      checked: decodeMirrorValue(value),
      unconfirmed: <String, DateTime>{},
    );
  }
}

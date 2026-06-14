import 'package:shared_preferences/shared_preferences.dart';

/// 使用可能額の基準となる「メインバンク」口座IDを永続化する。
/// 未設定なら null を返し、計算側で既定(残高最大の預金口座)を使う。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `main_account_id`) へ 1 行 jsonb でミラーする
/// (リボ設定と同じ集約方針 / MIRROR_PREF_SCHEMA.md)。
/// [encodeMirrorValue] / [decodeMirrorValue] がその往復を担う。
class AssetManagementMainAccountStore {
  static const String prefsKey = 'asset_management_main_account_id_v1';

  const AssetManagementMainAccountStore();

  Future<String?> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey)?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  Future<void> save(String? accountId, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final value = accountId?.trim();
    if (value == null || value.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    await store.setString(prefsKey, value);
  }

  /// メイン口座IDを `asset_pref_mirror.value` (jsonb) 形へ変換する。
  /// 未設定は空文字 (= 全端末へ「未設定」を伝播)。
  static Map<String, dynamic> encodeMirrorValue(String? accountId) {
    return <String, dynamic>{'id': accountId?.trim() ?? ''};
  }

  /// `asset_pref_mirror.value` (jsonb) からメイン口座IDを復元する。
  /// 空文字・不正値は null (未設定) とみなす。
  static String? decodeMirrorValue(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final raw = value['id'];
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

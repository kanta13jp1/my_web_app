import 'package:shared_preferences/shared_preferences.dart';

/// 使用可能額の基準となる「メインバンク」口座IDを永続化する。
/// 未設定なら null を返し、計算側で既定(残高最大の預金口座)を使う。
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
}

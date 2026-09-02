import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_liability_workbook.dart';

/// カードごとの「今後は一括（1回）払い」実行記録を永続化する。
///
/// ローカルを常に利用可能な一次ストアとし、資産管理ページが
/// `asset_pref_mirror` の `card_usage_policies` へ同じ JSON 形でミラーする。
class AssetCardUsagePolicyStore {
  static const String prefsKey = 'asset_card_usage_policies_v1';

  const AssetCardUsagePolicyStore();

  Future<Map<String, AssetCardUsagePolicy>> load({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, AssetCardUsagePolicy>{};
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <String, AssetCardUsagePolicy>{};
    }
  }

  Future<void> save(
    Map<String, AssetCardUsagePolicy> policies, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (policies.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    await store.setString(prefsKey, jsonEncode(encodeMirrorValue(policies)));
  }

  static Map<String, dynamic> encodeMirrorValue(
    Map<String, AssetCardUsagePolicy> policies,
  ) {
    return <String, dynamic>{
      for (final entry in policies.entries)
        if (entry.key.trim().isNotEmpty) entry.key: entry.value.toJson(),
    };
  }

  /// 不正なキー・値は捨て、残りのカード記録だけを復元する。
  static Map<String, AssetCardUsagePolicy> decodeMirrorValue(dynamic value) {
    final result = <String, AssetCardUsagePolicy>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((dynamic key, dynamic raw) {
      if (key is! String || key.trim().isEmpty || raw is! Map) {
        return;
      }
      result[key] = AssetCardUsagePolicy.fromJson(
        Map<String, dynamic>.from(raw),
      );
    });
    return result;
  }
}

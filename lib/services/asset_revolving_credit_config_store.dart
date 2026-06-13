import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_liability_workbook.dart';

/// リボ払いカードの設定 (リボ設定額・利用限度額) を負債IDごとに永続化する。
///
/// v1 はローカル (SharedPreferences) のみ。複数端末同期は支払日上書きと同じく
/// 段階的に進めるため、Supabase ミラー化は将来の別 Issue で扱う。
class AssetRevolvingCreditConfigStore {
  static const String prefsKey = 'asset_revolving_credit_configs_v1';

  const AssetRevolvingCreditConfigStore();

  Future<Map<String, AssetLiabilityRevolvingCreditConfig>> load({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, AssetLiabilityRevolvingCreditConfig>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, AssetLiabilityRevolvingCreditConfig>{};
      }
      final result = <String, AssetLiabilityRevolvingCreditConfig>{};
      decoded.forEach((key, value) {
        if (key is String && value is Map) {
          result[key] = AssetLiabilityRevolvingCreditConfig.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
      return result;
    } catch (_) {
      return <String, AssetLiabilityRevolvingCreditConfig>{};
    }
  }

  Future<void> save(
    Map<String, AssetLiabilityRevolvingCreditConfig> configs, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (configs.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    final encoded = jsonEncode(<String, dynamic>{
      for (final entry in configs.entries) entry.key: entry.value.toJson(),
    });
    await store.setString(prefsKey, encoded);
  }
}

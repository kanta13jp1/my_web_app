import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_liability_workbook.dart';

/// リボ払いカードの返済ルールを負債IDごとに永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `revolving_credit_configs`) へ 1 行 jsonb で
/// ミラーする (支払日上書きと同じ集約方針 / MIRROR_PREF_SCHEMA.md)。
/// [encodeMirrorValue] / [decodeMirrorValue] がローカルとミラー双方で使う
/// 共通の往復ロジックで、保存形は
/// `{debtId: {monthlyAmount, newUsageAmount, paymentDay, creditLimit}}`。
/// `creditLimit` は旧保存データとの互換用で、現行の返済計算には使わない。
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
      return decodeMirrorValue(jsonDecode(raw));
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
    await store.setString(prefsKey, jsonEncode(encodeMirrorValue(configs)));
  }

  /// 設定マップを `asset_pref_mirror.value` (jsonb) 形へ変換する。
  /// ローカル永続化とサーバミラーで同一の `{debtId: {...}}` 形を使う。
  static Map<String, dynamic> encodeMirrorValue(
    Map<String, AssetLiabilityRevolvingCreditConfig> configs,
  ) {
    return <String, dynamic>{
      for (final entry in configs.entries) entry.key: entry.value.toJson(),
    };
  }

  /// `asset_pref_mirror.value` (jsonb) または保存済み JSON から設定マップへ
  /// 復元する。不正なキー/値は黙って捨てる寛容なパース (前方/後方互換)。
  static Map<String, AssetLiabilityRevolvingCreditConfig> decodeMirrorValue(
    dynamic value,
  ) {
    final result = <String, AssetLiabilityRevolvingCreditConfig>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((dynamic key, dynamic raw) {
      if (key is String && raw is Map) {
        result[key] = AssetLiabilityRevolvingCreditConfig.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }
    });
    return result;
  }
}

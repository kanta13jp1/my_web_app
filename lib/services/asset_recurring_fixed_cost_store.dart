import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_liability_workbook.dart';

/// UI から登録した定期固定費 (家賃・光熱費・通信費など) を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `recurring_fixed_costs`) へ 1 行 jsonb で
/// ミラーする (リボ払い設定と同じ集約方針 / MIRROR_PREF_SCHEMA.md)。
/// [encodeMirrorValue] / [decodeMirrorValue] がローカルとミラー双方で使う
/// 共通の往復ロジックで、保存形は `{id: {name, amount, paymentDay, cadence,
/// sourceAccountId}}`。読み出しは振替日昇順 (同日は名前順) に整える。
class AssetRecurringFixedCostStore {
  static const String prefsKey = 'asset_recurring_fixed_costs_v1';

  const AssetRecurringFixedCostStore();

  Future<List<AssetRecurringFixedCost>> load({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return const <AssetRecurringFixedCost>[];
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return const <AssetRecurringFixedCost>[];
    }
  }

  Future<void> save(
    List<AssetRecurringFixedCost> costs, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (costs.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    await store.setString(prefsKey, jsonEncode(encodeMirrorValue(costs)));
  }

  /// リストを `asset_pref_mirror.value` (jsonb) 形 `{id: {...}}` へ変換する。
  /// ローカル永続化とサーバミラーで同一形を使う。
  static Map<String, dynamic> encodeMirrorValue(
    List<AssetRecurringFixedCost> costs,
  ) {
    return <String, dynamic>{
      for (final cost in costs) cost.id: cost.toJson(),
    };
  }

  /// `asset_pref_mirror.value` (jsonb) または保存済み JSON からリストへ復元する。
  /// 不正なキー/値は黙って捨てる寛容なパース (前方/後方互換)。
  /// 並びは振替日昇順 → 名前順で安定化する。
  static List<AssetRecurringFixedCost> decodeMirrorValue(dynamic value) {
    final result = <AssetRecurringFixedCost>[];
    if (value is! Map) {
      return result;
    }
    value.forEach((dynamic key, dynamic raw) {
      if (key is String && raw is Map) {
        final cost = AssetRecurringFixedCost.fromJson(
          key,
          Map<String, dynamic>.from(raw),
        );
        if (cost != null) {
          result.add(cost);
        }
      }
    });
    result.sort((a, b) {
      final byDay = a.paymentDay.compareTo(b.paymentDay);
      if (byDay != 0) {
        return byDay;
      }
      return a.name.compareTo(b.name);
    });
    return result;
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// カテゴリ別 月次予算 (category -> 金額) を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `category_budgets`) へ 1 行 jsonb でミラーする
/// (revolving_credit_configs と同じ集約方針 / MIRROR_PREF_SCHEMA.md)。
/// [encodeMirrorValue] / [decodeMirrorValue] がローカルとミラー双方で使う
/// 共通の往復ロジックで、保存形は `{category: amount}` (正の金額のみ)。
class AssetCategoryBudgetStore {
  static const String prefsKey = 'asset_category_budgets_v1';

  const AssetCategoryBudgetStore();

  Future<Map<String, double>> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, double>{};
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <String, double>{};
    }
  }

  Future<void> save(
    Map<String, double> budgets, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final sanitized = encodeMirrorValue(budgets);
    if (sanitized.isEmpty) {
      if (!await store.remove(prefsKey)) {
        throw StateError('Could not remove category budgets');
      }
      return;
    }
    if (!await store.setString(prefsKey, jsonEncode(sanitized))) {
      throw StateError('Could not save category budgets');
    }
  }

  /// 予算マップを `asset_pref_mirror.value` (jsonb) 形へ変換する。正の金額のみ残す。
  static Map<String, dynamic> encodeMirrorValue(Map<String, double> budgets) {
    return <String, dynamic>{
      for (final entry in budgets.entries)
        if (entry.value.isFinite && entry.value > 0) entry.key: entry.value,
    };
  }

  /// `asset_pref_mirror.value` (jsonb) または保存済み JSON から予算マップへ
  /// 復元する。不正キー・非正の金額は黙って捨てる寛容なパース。
  static Map<String, double> decodeMirrorValue(dynamic value) {
    final result = <String, double>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((dynamic key, dynamic raw) {
      if (key is String && raw is num && raw.isFinite && raw > 0) {
        result[key] = raw.toDouble();
      }
    });
    return result;
  }
}

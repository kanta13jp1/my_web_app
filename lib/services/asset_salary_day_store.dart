import 'package:shared_preferences/shared_preferences.dart';

/// 給料日(資産管理の月次サイクル基準日)を永続化する。
///
/// 月次 state(支払済みフラグ等)・給与内訳・予実は給料日サイクル
/// (`salaryDay` 〜 翌 `salaryDay`-1)で集計されるため、この値がサイクルの基準になる。
/// ローカル (SharedPreferences) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (pref_key: `salary_day`) へ 1 行 jsonb (`{day: N}`) でミラーする。
/// 値は [minSalaryDay]〜[maxSalaryDay] にクランプ(月末差異を避けるため 28 が上限)。
class AssetSalaryDayStore {
  static const String prefsKey = 'asset_salary_day_v1';
  static const int defaultSalaryDay = 25;
  static const int minSalaryDay = 1;
  static const int maxSalaryDay = 28;

  const AssetSalaryDayStore();

  static int clampDay(int day) => day.clamp(minSalaryDay, maxSalaryDay);

  Future<int> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getInt(prefsKey);
    if (raw == null) {
      return defaultSalaryDay;
    }
    return clampDay(raw);
  }

  Future<void> save(int day, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setInt(prefsKey, clampDay(day));
  }

  /// `asset_pref_mirror.value` (jsonb) 用に `{day: N}` へ変換する。
  static Map<String, dynamic> encodeMirrorValue(int day) {
    return <String, dynamic>{'day': clampDay(day)};
  }

  /// `asset_pref_mirror.value` (jsonb) から給料日を復元する。
  /// 不正値は既定(25)。
  static int decodeMirrorValue(dynamic value) {
    if (value is Map && value['day'] is num) {
      return clampDay((value['day'] as num).toInt());
    }
    return defaultSalaryDay;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// 想定給料額(メインバンクへ毎サイクル振り込まれる手取りの目安)を永続化する。
///
/// 給料振込の自動検知 ([AssetSalaryDepositDetector]) は、登録給料額があれば入金額
/// または残高増を ±許容で精密に判定できる。登録が無いと汎用の `heuristicFloor`
/// (既定 10 万円) に頼るしかなく、高収入では誤検知・低収入では取りこぼしが起きや
/// すい。この値をユーザーが登録することで検知精度が上がる。
///
/// [AssetSalaryDayStore] と同じ方針で、ローカル (SharedPreferences) を一次ストア
/// とし、端末間同期は資産管理ページが `asset_pref_mirror` (pref_key:
/// `salary_amount`) へ 1 行 jsonb (`{amount: N}`) でミラーする。0・負・非数・上限
/// 超過は「未登録」(null) として正規化する。
class AssetSalaryAmountStore {
  static const String prefsKey = 'asset_salary_amount_v1';

  /// 誤入力ガードの上限 (1 億円)。これを超える値は上限へ丸める。
  static const double maxSalaryAmount = 100000000;

  const AssetSalaryAmountStore();

  /// 0 以下・非数・null は未登録 (null)。上限超過は [maxSalaryAmount] へ丸める。
  static double? normalize(double? amount) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return null;
    }
    return amount > maxSalaryAmount ? maxSalaryAmount : amount;
  }

  Future<double?> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return normalize(store.getDouble(prefsKey));
  }

  Future<void> save(double? amount, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final normalized = normalize(amount);
    if (normalized == null) {
      await store.remove(prefsKey);
    } else {
      await store.setDouble(prefsKey, normalized);
    }
  }

  /// `asset_pref_mirror.value` (jsonb) 用に `{amount: N}` へ変換する。
  static Map<String, dynamic> encodeMirrorValue(double amount) {
    return <String, dynamic>{'amount': amount};
  }

  /// `asset_pref_mirror.value` (jsonb) から想定給料額を復元する。
  /// 不正値・未登録は null。
  static double? decodeMirrorValue(dynamic value) {
    if (value is Map && value['amount'] is num) {
      return normalize((value['amount'] as num).toDouble());
    }
    return null;
  }
}

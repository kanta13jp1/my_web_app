/// 資産管理AIサマリーの自動再生成判定。
///
/// 旧実装は「結果が存在するか (result != null)」を再生成不要の条件に使い、
/// かつ要求キーを生成前に設定していたため、初回生成以降はデータ
/// (支払済みチェック等) が変わっても自動再生成が永久に抑止されていた。
/// ここでは「表示中の結果が現在のレポートキーで生成されたものか」を
/// 唯一の基準にし、キーが変われば必ず再生成が走るようにする。
class AssetManagementAiSummaryRefresh {
  const AssetManagementAiSummaryRefresh._();

  /// 表示中のサマリーが現在のレポートキーに対して古い (= 再生成が必要) か。
  ///
  /// - 結果が無い: 古い (初回生成が必要)。
  /// - 結果はあるが、生成時のキー [resultKey] が現在の [currentKey] と
  ///   異なる: 古い (データが変わったので再生成が必要)。
  /// - 結果があり、生成時のキーが現在のキーと一致: 最新 (再生成不要)。
  static bool isStale({
    required String currentKey,
    required String? resultKey,
    required bool hasResult,
  }) {
    if (!hasResult) {
      return true;
    }
    return resultKey != currentKey;
  }
}

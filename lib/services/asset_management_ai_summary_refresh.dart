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

  /// 保存済み本文を現在データへ再利用できるか。
  ///
  /// 同じ基準日・生成直後でも、支払済み・残高・金利・解約状態のいずれかで
  /// 指紋が変わった本文は現在値として表示してはならない。
  static bool canReusePersisted({
    required String currentKey,
    required String cachedKey,
  }) {
    return currentKey == cachedKey;
  }

  /// 直近の生成「試行」(成功/失敗を問わず) からクールダウン時間内なので、
  /// 再生成を諦めて定型要約でしのぐべきか。
  ///
  /// 成功した分析は保存され `loadLatestForBaseDate` で再利用できるが、ai-hub の
  /// 500 等で失敗した試行は保存されない。そのため成功再利用だけに頼ると、AI が
  /// 落ちている間はロードや編集 (=指紋変化) のたびに 4 プロバイダ直列生成
  /// (1 分超) が毎回走り続ける。試行時刻を端末に記録し、成功再利用が無くても
  /// クールダウン内なら生成を見送ることで、失敗の連続試行を抑える。
  /// [force] (手動更新) は常に生成する。
  static bool shouldThrottleFailedRetry({
    required bool force,
    required Duration? sinceLastAttempt,
    required Duration cooldown,
  }) {
    if (force) {
      return false;
    }
    if (sinceLastAttempt == null) {
      return false;
    }
    return sinceLastAttempt < cooldown;
  }
}

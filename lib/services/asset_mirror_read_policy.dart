/// 集約 pref ミラー (`asset_pref_mirror`) の読み取りポリシー。
///
/// 既定 (フラグ OFF) は従来の「ローカル優先・ミラーはローカルが空のときだけ復元」。
/// フラグ ON で「Supabase 正本化 Phase B」= サーバ行があれば last-write-wins で採用
/// (詳細は docs/LOCAL_PERSISTENCE_RETIREMENT_ROADMAP.md)。
///
/// 本番有効化は dart-define で行い、無効化は即時ロールバック可能
/// (リポジトリの `supabaseWritesEnabled` と同じ feature-flag パターン)。
class AssetMirrorReadPolicy {
  const AssetMirrorReadPolicy._();

  static const String flagName = 'ASSET_MIRROR_READS_AUTHORITATIVE';

  /// ビルド時フラグ。既定 false (= 現行挙動を維持。プロダクションは無変更)。
  static const bool authoritative = bool.fromEnvironment(
    flagName,
    defaultValue: false,
  );

  /// Phase 3: legacy per-key 行の読みフォールバックを撤去するビルド時フラグ。
  ///
  /// 既定 false (= legacy 行も読む現行挙動 / プロダクション無変更)。true で
  /// `asset_pref_mirror` の読みを集約行のみに絞る。本番有効化は dart-define で行い、
  /// 既定 false なので削除するだけで即時ロールバックできる。
  ///
  /// **有効化の前提**: docs/PHASE3_LEGACY_ZERO_DRYRUN.md の dry-run が全 PASS
  /// (legacy 残存ゼロ + 旧クライアント不在) を確認できた後にのみ true にする。
  static const String legacyReadDisabledFlag =
      'ASSET_LEGACY_PREF_READ_DISABLED';

  static const bool legacyReadDisabled = bool.fromEnvironment(
    legacyReadDisabledFlag,
    defaultValue: false,
  );

  /// `asset_pref_mirror` 読みの `inFilter('pref_key', ...)` に渡すキー一覧を返す
  /// 純関数。[legacyReadDisabled] が true なら集約キーのみ(legacy フォールバック
  /// 撤去)、false なら集約 + legacy キー(現行)。
  ///
  /// [legacyDisabled] はテスト用の上書き。省略時はビルド時フラグを使う。
  static List<String> readPrefKeys({
    required String aggregatedKey,
    required List<String> legacyKeys,
    bool? legacyDisabled,
  }) {
    final disabled = legacyDisabled ?? legacyReadDisabled;
    if (disabled) {
      return <String>[aggregatedKey];
    }
    return <String>[aggregatedKey, ...legacyKeys];
  }
}

/// LWW 解決の結果: サーバ行を採用するか、ローカルを維持するか。
enum AssetMirrorAdoption { adoptMirror, keepLocal }

/// 集約 pref ミラーの採否を last-write-wins で判定する純関数。
///
/// - ミラー無し → ローカル維持。
/// - ローカル無し → ミラー採用。
/// - 両方あり → `updated_at` が新しい方を採用 (同時刻はローカル維持で安定)。
///   - ローカルの timestamp が null (= タイムスタンプ導入前の legacy ローカル) の場合は
///     **ミラー採用**。ミラーはその端末自身の write-through 結果であり、サーバ正本化の
///     方針上もサーバを優先するのが妥当なため (本番データ分布を確認したうえで有効化する)。
///   - ミラーの timestamp が null (想定外) の場合は安全側でローカル維持。
AssetMirrorAdoption resolveMirrorRead({
  required bool hasLocal,
  required bool hasMirror,
  required DateTime? localUpdatedAt,
  required DateTime? mirrorUpdatedAt,
}) {
  if (!hasMirror) {
    return AssetMirrorAdoption.keepLocal;
  }
  if (!hasLocal) {
    return AssetMirrorAdoption.adoptMirror;
  }
  if (localUpdatedAt == null) {
    return AssetMirrorAdoption.adoptMirror;
  }
  if (mirrorUpdatedAt == null) {
    return AssetMirrorAdoption.keepLocal;
  }
  return mirrorUpdatedAt.isAfter(localUpdatedAt)
      ? AssetMirrorAdoption.adoptMirror
      : AssetMirrorAdoption.keepLocal;
}

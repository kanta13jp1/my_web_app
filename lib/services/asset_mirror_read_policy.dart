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

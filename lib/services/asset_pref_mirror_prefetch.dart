/// `asset_pref_mirror` の行リストを `pref_key` → 行 の Map へ索引する純関数。
///
/// 資産管理ページは起動時に多数の per-key 読み取り
/// (`.from('asset_pref_mirror').select().eq('pref_key', X)`) を個別に発行しており、
/// 端末跨ぎ同期の REST が同時多発して `ERR_INSUFFICIENT_RESOURCES` を誘発していた。
/// 1 回のバッチ取得 (`.eq('user_id', uid)`) で得た全行をこの関数で `pref_key` 索引し、
/// 各ローダーがネットワークを介さずキャッシュから引けるようにする。
///
/// `(user_id, pref_key)` は一意のため 1 キー 1 行。同一キーが複数あれば後勝ち
/// (個別 `.eq('pref_key', X)` が返す `rows.first` 相当の安定性は upsert の一意制約に
/// 依存する前提)。
library;

Map<String, Map<String, dynamic>> indexPrefMirrorRowsByKey(List<dynamic> rows) {
  final map = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final key = row['pref_key']?.toString();
    if (key == null || key.isEmpty) {
      continue;
    }
    map[key] = Map<String, dynamic>.from(row);
  }
  return map;
}

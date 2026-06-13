# asset_pref_mirror 集約マイグレーション計画

`asset_pref_mirror` の表示設定 pref を **per-key 複数行 → 1 行 jsonb** へ集約する
段階移行の計画書 (part 293〜)。行数削減と upsert 回数削減が目的。

## 対象キー

| 旧 (legacy per-key) | 新 (集約 1 行) | サブキー |
|----|----|----|
| `display_mode` | `asset_display_prefs_v1` | `mode` |
| `section_overrides` | 〃 | `section_overrides` |
| `section_override_deleted` | 〃 | `section_override_deleted` |
| `inflow_deleted_ids` | `asset_inflow_prefs_v1` | `deleted_ids` |
| `inflow_tombstone_gc` | 〃 | `gc` |

## フェーズ

- **Phase 1 — 書き込み集約 (part 293 / 完了)**: 書き込みは集約行のみ。読みは
  **集約優先 + legacy per-key 行フォールバック**で後方互換を維持。
- **Phase 2 — legacy 行クリーンアップ (part 294 / 本変更)**: 集約 upsert と同時に
  legacy per-key 行を best-effort delete。新クライアントで開く度に旧行が消える。
  読みフォールバックは**まだ残す**(全端末が新クライアントになるまでの保険)。
- **Phase 3 — フォールバック撤去 (将来 / 未着手)**: 下記の撤去条件を満たしたら
  読みフォールバック (`_fetchDisplayPrefRows` の legacy 分岐 / inflow 同等) と
  cleanup コードを削除し、集約行のみを読む。

## Phase 3 撤去条件 (すべて満たすこと)

1. Phase 2 リリースから**最低 4 週間**経過 (全アクティブ端末が新クライアントへ更新)。
2. `asset_pref_mirror` で legacy per-key 行 (`display_mode` 等) の残存が
   実質ゼロ (sql で `count(*) where pref_key in (...)` を確認)。
3. 旧クライアント (集約行を書けないバージョン) のアクティブ利用がない。

## ロールバック

- Phase 2 は revert で「legacy delete を止める」だけ。集約行・読みフォールバックは
  そのまま機能するため、データ損失なし。
- 万一 legacy delete が誤って必要な行を消しても、次回の集約 upsert + 読みフォール
  バックで実害なし (集約行が真実)。

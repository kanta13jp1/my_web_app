# asset_pref_mirror pref_key スキーマ俯瞰

資産管理ページが `asset_pref_mirror`(user_id ごと・pref_key ごとに 1 行の jsonb
バックアップ。端末間同期/削除伝播に使用)へ書き込む全 pref_key の現行スキーマ。
集約方針・移行は [`MIRROR_PREF_AGGREGATION_MIGRATION.md`](MIRROR_PREF_AGGREGATION_MIGRATION.md) 参照。

行は `{ user_id, pref_key, value (jsonb), updated_at }`。下表は `value` の形。

## 現行 (書き込み対象)

| pref_key | value | 用途 | 書込 | 読出 |
|----|----|----|----|----|
| `asset_display_prefs_v1` | `{mode, section_overrides:{id:state}, section_override_deleted:[id]}` | 表示モード+セクション上書き+その削除tombstone(集約) | `_mirrorDisplayPrefs` | `_fetchDisplayPrefRows` / `_pullDeletedSectionIds` |
| `asset_inflow_prefs_v1` | `{deleted_ids:{ids:[id]}, gc:{max_count,max_age_days}}` | 入金削除tombstone + GC設定(集約) | `_mirrorInflowPrefs` | `_pullInflowDeletedIds` / `_loadTombstoneGcConfig` |
| `debt_payment_day_overrides` | `{debtId: day(1-31)}` | 負債ごとの支払日手動設定 | `_mirrorDebtPaymentDayOverrides` | `_restoreDebtPaymentDayOverridesFromMirror` |
| `debt_payment_day_override_deleted` | `{ids:[debtId]}` | 支払日上書きの削除tombstone | `_mirrorDebtOverrideDeleted` | `_pullDebtOverrideDeleted` |
| `revolving_credit_configs` | `{debtId: {monthlyAmount, creditLimit}}` | 負債(リボ払いカード)ごとのリボ設定額+利用限度額 | `_mirrorRevolvingConfigs` | `_restoreRevolvingConfigsFromMirror` |
| `main_account_id` | `{id: '<accountId>'}` | 使用可能額の基準となるメインバンク口座ID | `_mirrorMainAccount` | `_restoreMainAccountFromMirror` |
| `watchlist_entries` | `{entries: [{assetType, group, memo, addedAt}]}` | ウォッチリスト項目(注目資産+グループ+メモ) | `_mirrorWatchlist` | `_restoreWatchlistFromMirror` |

> 入金予定の実体は別テーブル `asset_expected_inflow_items`(本表の対象外)。

> `main_account_id` / `watchlist_entries` も削除トゥームストーン不要(スカラ/全件置換)。
> 読みは集約ミラー優先・無ければローカル(`asset_management_main_account_id_v1` /
> `asset_watchlist_entries_v1`)へフォールバックし、ローカルに既存値がある端末は
> ミラーで上書きしない(安全側復元)。メイン口座は `{id:''}`、ウォッチリストは空
> `entries` の upsert で「未設定/全削除」を全端末へ伝播する。
> なお表示モードの実験ログ(`display_mode_events` テーブル)と復元辞退フラグ
> (`asset_management_restore_declined_v1`)は意図的に端末ローカルのまま
> (前者は専用サーバテーブルへ別途記録済 / 後者は端末ごとの UX 状態)。

> `revolving_credit_configs` は支払日上書きと同じく**削除トゥームストーン不要**。
> 設定の有無は map のキー有無で表現し(リボOFF=キー削除)、空 map の upsert で
> 全端末へ「設定なし」が伝播する。読みは集約ミラー優先・無ければローカル
> (`asset_revolving_credit_configs_v1`)へフォールバックし、ローカルに既存設定が
> ある端末はミラーで上書きしない(オフライン編集の握り潰し防止 / 安全側復元)。

## Legacy (読みフォールバックのみ / 書き込み停止済 / 撤去予定)

集約行へ移行済み。新クライアントは書かず、boot 時の集約 upsert と同時に
best-effort delete される(Phase 2)。読みは集約行が無い場合のみ参照。

| pref_key | 集約先 | サブキー |
|----|----|----|
| `display_mode` | `asset_display_prefs_v1` | `mode` |
| `section_overrides` | 〃 | `section_overrides` |
| `section_override_deleted` | 〃 | `section_override_deleted` |
| `inflow_deleted_ids` | `asset_inflow_prefs_v1` | `deleted_ids` |
| `inflow_tombstone_gc` | 〃 | `gc` |

## tombstone (削除伝播) の構成

「一度消したものを他端末/サーバ残存から復活させない」ため、削除 ID 集合を
`MirrorTombstoneStore`(GC 付き)で管理し mirror 往復する。3 ドメイン:

1. 入金予定削除 → `asset_inflow_prefs_v1.deleted_ids`
2. セクション上書き削除 → `asset_display_prefs_v1.section_override_deleted`
3. 支払日上書き削除 → `debt_payment_day_override_deleted`

## 入金予定実体 (`asset_expected_inflow_items` テーブル) の削除伝播 — 整理 (part 296)

入金予定の**実体行**は別テーブル `asset_expected_inflow_items` にあるが、その
**削除伝播は上記 tombstone #1 が既にカバーしている**ため、items 専用の追加
ラウンドトリップは不要(結論)。具体的な流れ:

- 端末A で削除 → `_deleteInflowMirror(id)` がサーバ行を削除 **かつ**
  `_mirrorInflowPrefs` が `deleted_ids` に id を追加 (tombstone をミラー)。
- 端末B の boot → `_pullInflowDeletedIds` が tombstone を取り込み
  `applyRemoteDeletedIds` で**ローカルの該当 item を削除**(復活防止)。
- `mergeFromMirrorRows` / `restoreFromMirrorRows` は tombstone 済み id を除外。

`restoreFromMirrorRows` が「ローカル空のときだけ全復元」なのは安全側の初期復元
専用であり、削除伝播はあくまで tombstone 経路で成立している(= 「復元のみ」では
ない)。よって items に新規の削除ミラーは追加しない。

> 強いて残る差分: items は `_mirrorInflowToSupabase` で**行ごと upsert** する一方、
> tombstone は集約 1 行。行ごと upsert の集約化は別テーマ (実体データのため本 doc の
> pref 集約とはスコープが異なる)。

## 同期ステータス指標 (未同期 = この端末のみ の可視化)

ローカル優先で読む構成のため「サーバ未同期 = 他端末に出ない」状態を画面で可視化する
(`lib/services/asset_sync_status.dart` の `AssetSyncStatusSummary` / page の
`_refreshSyncSources`)。各データ領域の出所 (`AssetSyncSource`: synced / localOnly / empty)
を判定:

- **pref 系** (`main_account_id` / `watchlist_entries` / `revolving_credit_configs` /
  `debt_payment_day_overrides`): boot/保存時に `asset_pref_mirror` を 1 回 select し、
  当該 pref_key 行があれば synced。
- **入金** (`inflow`): `asset_expected_inflow_items` の存在で判定。
- **月次state** (`monthlyState`): `AssetLiabilityRepository.supabaseWritesEnabled` ＋
  `_assetLiabilitySyncStatus` から判定。
- **未ログイン時**: 何も同期されないため、データのある領域はすべて localOnly。

UI = 全体ステータスバナー (`Key('asset_sync_status_chip')`) ＋ 未同期バッジ列
(`Key('asset_unsynced_badge_row')` / 各 `Key('asset_unsynced_badge_<domain>')`)。
将来の正本化計画は [`LOCAL_PERSISTENCE_RETIREMENT_ROADMAP.md`](LOCAL_PERSISTENCE_RETIREMENT_ROADMAP.md)。

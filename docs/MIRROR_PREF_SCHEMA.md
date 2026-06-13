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

> 入金予定の実体は別テーブル `asset_expected_inflow_items`(本表の対象外)。

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

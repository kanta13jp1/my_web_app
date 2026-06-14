# 資産管理: ローカル永続の段階的縮退ロードマップ

資産管理ページの読み取りは現在 **全ドメインがローカル (SharedPreferences) 優先** で、
Supabase はバックアップ/同期先。これを **Supabase 正本・ローカルはオフライン用キャッシュ**
へ段階的に移行する計画 (= 「ローカル永続を参照する処理を将来すべて減らす」要望の正本)。

> 最終形は「ローカル永続の**完全撤去**」ではない。完全撤去するとオフライン/未ログインで
> 資産画面が使えなくなるため、ローカルは **write-through キャッシュ**として残す
> (真実の源 = Supabase、表示の即応性とオフライン耐性 = ローカル)。

## 現状の2系統

| 系統 | 対象 | 同期機構 | 読み |
|----|----|----|----|
| pref 系 | 表示設定 / 入金 / 支払日上書き / リボ / メイン口座 / ウォッチリスト | `asset_pref_mirror` (`_mirror*` / `_restore*FromMirror`) | ローカル優先・空時のみミラー復元 |
| 月次state系 | 支払/カード請求/収入計画など12項目 | `AssetLiabilityRepository` (`syncMonth` / 競合解決 / sync audit log / `supabaseWritesEnabled`) | ローカル優先・リモート補完 |
| 資産残高 | 口座残高スナップショット | `cfo_assets` テーブル直読み (`_loadDataFromSupabase`) | **既に Supabase 正本** |

## フェーズ

- **Phase A — 可視化 (本 PR / 完了)**: provenance を追跡し、未同期 (= この端末のみ) を
  全体バナー＋未同期バッジで可視化。撤去作業の前提となる「どこがローカル由来か」を
  ユーザーと開発者の双方が確認できる状態にする (`lib/services/asset_sync_status.dart` /
  `_refreshSyncSources`)。
- **Phase B — 読み優先度の反転 (pref系4ドメインをフラグ裏で実装済 / 既定 OFF)**:
  pref 系の `main_account_id` / `watchlist_entries` / `revolving_credit_configs` /
  `debt_payment_day_overrides` の `_restore*FromMirror` を「ローカル空時のみ」→
  **last-write-wins** (`resolveMirrorRead` / `lib/services/asset_mirror_read_policy.dart`) へ。
  ローカル最終変更時刻 (`AssetSyncTimestampStore` / `asset_sync_timestamps_v1`) と
  `asset_pref_mirror.updated_at` を比較し、新しい方を採用 (オフライン未同期のローカル編集は
  保持)。フラグ `ASSET_MIRROR_READS_AUTHORITATIVE` (`bool.fromEnvironment` / 既定 false) で
  ゲートし、**本番は無変更**。残り (入金 items / 月次state) と clear 伝播は Phase B.2。
  月次state系は既存 `syncMonth`/競合解決を既定経路化、資産残高 (cfo_assets) は既存パターンに揃える。
- **Phase C — legacy mirror 行の読み撤去**: 既存
  [`MIRROR_PREF_AGGREGATION_MIGRATION.md`](MIRROR_PREF_AGGREGATION_MIGRATION.md) Phase 3
  (per-key legacy 行の読みフォールバック撤去) を、撤去条件 (リリース後4週間＋SQL で残存ゼロ確認)
  達成後に実施。
- **Phase D — ローカルをキャッシュ専用へ降格**: ローカル書き込みは write-through に限定し、
  クロス端末の真実源にしない。未ログイン/オフライン時はキャッシュ表示＋「未同期」明示
  (Phase A の指標がそのまま機能)。

## Phase B 有効化手順 (本番)

1. **データ分布を確認** (Supabase SQL Editor)。集約行とローカルの整合が前提:
   ```sql
   -- pref_key ごとの行数 / ユーザー数 / 最終更新。
   select pref_key, count(*) as rows, count(distinct user_id) as users,
          max(updated_at) as latest
   from asset_pref_mirror
   where pref_key in (
     'main_account_id', 'watchlist_entries',
     'revolving_credit_configs', 'debt_payment_day_overrides'
   )
   group by pref_key
   order by rows desc;

   -- updated_at が NULL の行が無いこと (LWW 比較の前提)。NULL は安全側でローカル維持になる。
   select pref_key, count(*) as null_updated_at
   from asset_pref_mirror
   where updated_at is null
     and pref_key in (
       'main_account_id', 'watchlist_entries',
       'revolving_credit_configs', 'debt_payment_day_overrides'
     )
   group by pref_key;
   ```
2. 問題なければ `deploy-staging.yml` で `--dart-define=ASSET_MIRROR_READS_AUTHORITATIVE=true`
   を有効化し、複数端末で「端末A 変更 → 端末B 起動で反映」を確認。
3. 本番 (`deploy-prod.yml`) も同 dart-define を追加。**ロールバックはフラグを外すだけ** (即時)。

> LWW の安全性: ローカル変更時に `asset_sync_timestamps_v1` へ時刻記録、ミラー upsert も
> `updated_at` 更新。新しい方が勝つため、オフラインの未同期ローカル編集が古いサーバ値に
> 上書きされることはない。タイムスタンプ未記録の legacy ローカルは「サーバ採用」側に倒す
> (= その端末自身の write-through 結果であり正本化方針に沿う)。clear (空化) の伝播は未対応 (Phase B.2)。

## 注記

- 各 Phase は独立 PR。Phase B 以降は本番データ分布 (Supabase SQL) と移行期間が前提のため、
  着手前に分布確認を行う。
- **意図的に端末ローカルのまま** (撤去対象外): 表示モード実験ログ (`display_mode_events`
  テーブルへ別途記録済) / 復元辞退フラグ (端末ごとの UX 状態。同期すると他端末の復元提案を
  誤抑止する)。

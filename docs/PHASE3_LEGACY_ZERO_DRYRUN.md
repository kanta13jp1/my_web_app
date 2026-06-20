# Phase 3 legacy 残存ゼロ Dry-Run Runbook

> `asset_pref_mirror` の **legacy per-key 読みフォールバック撤去 (Phase 3)** に着手してよいかを、
> **厳密に READ-ONLY** で判定するための実行手順書。
> 関連: [`MIRROR_PREF_AGGREGATION_MIGRATION.md`](MIRROR_PREF_AGGREGATION_MIGRATION.md) (移行計画・正本) /
> [`MIRROR_PREF_SCHEMA.md`](MIRROR_PREF_SCHEMA.md) (pref_key スキーマ俯瞰)。
>
> このページは既存 doc の「3 クエリ確認 SQL + ロールバック注記」を **置き換えるより厳格な dry-run**。
> dry-run 自体はデータを **一切変更しない**(変更しないことをエンジンに強制する)。最終 DELETE は dry-run の対象外。
>
> **最短着手日: 2026-07-11 / 実行者: 本番オペレータ(Supabase SQL Editor)。**

---

## 0. なぜ「ただの count」では危険か (この手順書の存在理由)

`asset_pref_mirror` の RLS ポリシーは:

```sql
create policy "asset_pref_mirror_own_all" on public.asset_pref_mirror
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

= **`authenticated` セッションは自分の行しか見えない**。
よって `count(*) where pref_key in (...)` を **通常のアプリ/PostgREST/ユーザー JWT 文脈で実行すると、
オペレータ本人の行だけ**が集計され、ほぼ確実に `0` が返る → **FALSE near-zero**。
これは「他ユーザーに legacy 行が数千行残っていても gate が誤って PASS する」最悪の罠。

したがって本 dry-run は:

1. **必ず Supabase SQL Editor で privileged role (`postgres` / `service_role` = `BYPASSRLS`)** として実行する。
2. **実行時に「本当に RLS をバイパスして全ユーザーを見ているか」を機械的に自己証明** してから count を信用する。
3. **READ-ONLY をエンジンに強制**(`set transaction read only`)し、誤って書いても弾く。
4. legacy 行の単純 count だけでなく、**「撤去してもどのユーザーのデータも失われないか」**(後継集約行・サブキー・tombstone id の網羅)を検証する。

> 既知の最重要欠陥への対処を全て織り込んでいる: ① RLS scoped 誤検知 ② FORCE RLS 下では owner すら row-filter される
> ③ `pg_has_role` 会員資格は bypass の証明にならない ④ READ COMMITTED は文ごとに別スナップショット
> ⑤ legacy-only ユーザー / mid-migration stale ⑥ tombstone id の取りこぼし復活 ⑦ 削除 race による見かけ 0 ⑧ 14 vs 12 key drift。

---

## 1. 既知の用語と「絶対に消してはいけないもの」

### 1.1 撤去対象 = LEGACY 5 キー (これだけ)

| legacy pref_key | 後継 (集約行) | サブキー |
|---|---|---|
| `display_mode` | `asset_display_prefs_v1` | `mode` |
| `section_overrides` | `asset_display_prefs_v1` | `section_overrides` |
| `section_override_deleted` | `asset_display_prefs_v1` | `section_override_deleted` |
| `inflow_deleted_ids` | `asset_inflow_prefs_v1` | `deleted_ids` |
| `inflow_tombstone_gc` | `asset_inflow_prefs_v1` | `gc` |

すべてコード内でハードコード小文字。クライアントは大小・空白の異形を **書かない** →
DB に異形があれば手動 SQL か非現行クライアント由来 = 必ず triage する盲点。

### 1.2 既知ユニバース = **14 キー** (12 ではない / drift 注意)

origin/main の `lib/pages/asset_management_page.dart` を grep して確定した、テーブルに現れうる全 pref_key:

- **集約 (2 / keep)**: `asset_display_prefs_v1`, `asset_inflow_prefs_v1`
- **LEGACY (5 / retire)**: 上表の 5。
- **現行・絶対 keep (7)**: `debt_payment_day_overrides`, `debt_payment_day_override_deleted`,
  `revolving_credit_configs`, **`revolving_credit_configs_deleted`**, `main_account_id`,
  `watchlist_entries`, **`watchlist_entries_deleted`**

> 🔴 **タスク当初の 12-key 一覧は誤り。** `revolving_credit_configs_deleted` (page L8394 で upsert)
> と `watchlist_entries_deleted` (page L5312 で upsert) は **LIVE な現行キー**。12-key で denylist を組むと
> この 2 つを ANOMALY と誤判定し、最終 DELETE で **live data を破壊** しかねない。本 SQL の **14-key ユニバースを必ず使う**。

ユニバース外の pref_key は **すべて ANOMALY** = 忘れられた/改名された legacy・異形・taxonomy drift。
最終 DELETE `IN(5 legacy)` は静かに取りこぼし、撤去後の読みも無視するため、**着手前に triage 必須**。

### 1.3 紛らわしい “似て非なるもの” (消すな)

- `display_mode_events` … **別テーブル**(pref_key ではない)。
- `asset_management_display_mode_v1` 等 `*_v1` … **SharedPreferences のローカルキー**(DB pref_key ではない)。
- `debt_payment_day_override_deleted` … 現行 tombstone。legacy の `section_override_deleted` / `inflow_deleted_ids` と名前が似るが **撤去対象外**。

→ だから **`LIKE` / wildcard 削除は厳禁**。常に **exact `IN (...)` の 5 キー allowlist** を使う。

### 1.4 撤去される読みフォールバックのコード位置 (origin/main / 関数名アンカー)

行番号は 24k 行の page で毎セッション動くため **関数名で特定**(撤去 commit 上で再確認):

- `_fetchDisplayPrefRows()` — `inFilter` に `display_mode` / `section_overrides` を含むフォールバック。
- `_pullDeletedSectionIds()` — `inFilter [asset_display_prefs_v1, section_override_deleted]` + legacy 分岐。
- `_pullInflowDeletedIds()` — `inFilter [asset_inflow_prefs_v1, inflow_deleted_ids]` + legacy 分岐。
- `_loadTombstoneGcConfig()` — `inFilter [asset_inflow_prefs_v1, inflow_tombstone_gc]` + legacy 分岐。

いずれも **「集約行があれば集約 ELSE legacy」**。Phase 1 で legacy への upsert/insert は **ゼロ**(grep 確認: legacy 一致は別テーブル `display_mode_events` の insert のみ)。
Phase 2 の `_cleanupLegacyDisplayPrefRows()` / `_cleanupLegacyInflowPrefRows()` が集約 upsert 後に best-effort delete。

`lib/services/asset_management_display_mode_store.dart` の `evaluateMirrorPrefRows()` の legacy 分岐は
`aggregatedMirrorToRows()` が **メモリ内で合成した** `{pref_key:'display_mode'}` 等で駆動される(**DB writer ではない**)→ 撤去面は上記 4 関数の DB 側 `inFilter` のみ。

---

## 2. Phase 3 撤去ゲート (3 条件すべて満たす)

| # | 条件 | 判定元 |
|---|---|---|
| **Gate 1** | Phase 2 リリースから **>=4 週間**経過、かつ暦日 **>=2026-07-11** | **テーブル外**(deploy 記録 / PR merge 日)。手動照合。 |
| **Gate 2** | legacy per-key 行の **global 残存が実質ゼロ** | 本 dry-run `[D2] legacy_residual_rows = 0` ほか。 |
| **Gate 3** | legacy を **書く旧クライアントが active でない** | 本 dry-run の recency/decay は **必要条件**。**十分条件は app-version テレメトリ**とのクロスチェック。 |

---

## 3. 実行前提 (PRECONDITIONS — 飛ばさない)

- **P1. 日付/経過**: 暦日 **>= 2026-07-11** かつ **Phase 2 リリースから >= 4 週間**。Phase 2 リリース日は本テーブルから導出不能(part 294 の `_cleanupLegacy*` 着地 PR の merge 日)。**両日付を gate ログに記録**。
- **P2. 実行文脈**: **本番**プロジェクトの **Supabase SQL Editor**、接続先は **PRIMARY**(branch/replica ではない)、role は **`postgres` / `service_role`**。
  - **アプリ / PostgREST / ユーザー JWT セッションから実行しない**(RLS scoped → FALSE near-zero → 誤 PASS)。
- **P3. クリーンなタブ**: 本ブロックは **新規 SQL Editor タブで最初に**実行する。先頭の `reset role; reset request.jwt.claims;` が直前文の漏れた session 状態を消す(reset は write ではなく read-only 下でも安全)。
- **P4. コード再確認**: 撤去 commit 上で上記 4 関数を **関数名で再特定**し、各々が「集約優先 → legacy フォールバック」のままであることを確認(行番号は信用しない)。

---

## 4. 検証 SQL (STRICTLY READ-ONLY / 1 回の Run で全文実行)

> **ブロック全体を「1 クリック = 1 Run」で実行する。**
> `begin; set transaction isolation level repeatable read read only; ... rollback;` により
> (a) **REPEATABLE READ = 全文が単一 MVCC スナップショット**(READ COMMITTED の文ごと別スナップショットを回避)、
> (b) **READ ONLY = いかなる書き込みもエンジンが拒否**。
> Supabase は Run 毎に auto-commit するため、**1 Run で実行することがトランザクションを全文に張る条件**。

```sql
-- =============================================================================
-- PHASE 3 DRY-RUN  (asset_pref_mirror legacy fallback retirement)
-- STRICTLY READ-ONLY. Run in Supabase SQL Editor as a PRIVILEGED role
-- (postgres / service_role = BYPASSRLS) on the PRIMARY. Run the WHOLE block as ONE Run.
-- Nothing here mutates data; the engine REJECTS any accidental write.
-- =============================================================================

-- [P3] clear any leaked session state from a prior statement in this tab (reads, not writes).
reset role;
reset request.jwt.claims;

begin;
set transaction isolation level repeatable read read only;  -- ONE snapshot + write-proof.

-- -----------------------------------------------------------------------------
-- [G0] PRIVILEGE / RLS-BYPASS SELF-GUARD  (read FIRST; aborts the block if untrustworthy)
--      Accepted privileged paths (ONLY these):
--        (a) current_user has rolbypassrls = true  (service_role / postgres), OR
--        (b) current_user IS the table owner (string identity) AND force-RLS is OFF.
--      Membership (pg_has_role) is NOT accepted: being a MEMBER of the owner role does
--      NOT bypass RLS. FORCE ROW LEVEL SECURITY makes even the owner row-filtered.
-- -----------------------------------------------------------------------------
do $$
declare
  v_user        text    := current_user;
  v_bypassrls   boolean := (select rolbypassrls from pg_roles where rolname = current_user);
  v_owner_role  text    := (select tableowner from pg_tables
                            where schemaname='public' and tablename='asset_pref_mirror');
  v_is_owner    boolean := (current_user = (select tableowner from pg_tables
                            where schemaname='public' and tablename='asset_pref_mirror'));
  v_force_rls   boolean := (select relforcerowsecurity from pg_class
                            where oid='public.asset_pref_mirror'::regclass);
  v_jwt         text    := current_setting('request.jwt.claims', true);
  v_jwt_norm    text    := nullif(btrim(coalesce(current_setting('request.jwt.claims', true), '')), '');
  v_role_guc    text    := nullif(btrim(coalesce(current_setting('role', true), '')), '');
  v_in_recovery boolean := pg_is_in_recovery();
  v_replay_lsn  pg_lsn  := pg_last_wal_replay_lsn();
  v_auth_uid    text;
begin
  -- G1: privileged path. BYPASSRLS, OR (owner-identity AND not force-RLS). NEVER membership.
  if not (coalesce(v_bypassrls,false)
          or (coalesce(v_is_owner,false) and not coalesce(v_force_rls,false))) then
    if coalesce(v_is_owner,false) and coalesce(v_force_rls,false) then
      raise exception 'GUARD FAIL G1b: current_user=% owns the table but FORCE ROW LEVEL SECURITY is ON -> even the owner is row-filtered -> counts are a FALSE near-zero. Use a BYPASSRLS role (service_role/postgres).', v_user;
    end if;
    raise exception 'GUARD FAIL G1: current_user=% is neither BYPASSRLS nor the table owner with force-RLS off -> counts are RLS-scoped (false near-zero). Open the Supabase SQL Editor as postgres/service_role.', v_user;
  end if;

  -- G2: no request/JWT context bound (parse, do not byte-match). Any non-empty request.* GUC aborts.
  if v_jwt_norm is not null and v_jwt_norm <> '{}' then
    raise exception 'GUARD FAIL G2: request.jwt.claims is bound (%) -> request/JWT context, rows scoped to one user.', v_jwt_norm;
  end if;
  if v_role_guc is not null then
    raise exception 'GUARD FAIL G2-role: request "role" GUC is set (%) -> request context, rows may be scoped.', v_role_guc;
  end if;

  -- G2b: auth.uid() must NOT be bound. FAIL-CLOSED on unexpected errors (do not swallow blindly).
  begin
    v_auth_uid := auth.uid()::text;          -- NULL = no end-user bound (good)
  exception
    when undefined_function or insufficient_privilege or invalid_schema_name then
      raise notice 'GUARD note G2b: auth.uid() not resolvable (%); relying on G1/G2/G5 as binding gates.', sqlstate;
      v_auth_uid := null;
    when others then
      raise exception 'GUARD FAIL G2b: auth.uid() raised unexpected SQLSTATE % -> cannot prove privilege context; abort.', sqlstate;
  end;
  if v_auth_uid is not null then
    raise exception 'GUARD FAIL G2b: auth.uid()=% is bound -> request context, rows scoped to one user.', v_auth_uid;
  end if;

  -- G3: must be on the PRIMARY (a replica can lag and under-report residual right after a write/cleanup).
  if v_in_recovery or v_replay_lsn is not null then
    raise exception 'GUARD FAIL G3: pg_is_in_recovery()=% / last_wal_replay_lsn=% -> reading a REPLICA. Use the primary endpoint.', v_in_recovery, v_replay_lsn;
  end if;

  raise notice 'GUARD G0..G3 PASS: user=% bypassrls=% is_owner=% force_rls=% jwt=NULL auth.uid=NULL primary=true', v_user, v_bypassrls, v_is_owner, v_force_rls;
end $$;

-- [G4] VISIBLE magnitude tripwire + denominator anchor (record in the gate log).
--      A scoped run shows distinct_users=1; a global run shows the full user base.
select 'G4_scope_tripwire'                                                            as section,
       current_user                                                                  as run_as_role,
       (select rolbypassrls from pg_roles where rolname=current_user)                as role_bypasses_rls,
       (select relrowsecurity     from pg_class where oid='public.asset_pref_mirror'::regclass) as rls_enabled,
       (select relforcerowsecurity from pg_class where oid='public.asset_pref_mirror'::regclass) as force_rls,
       pg_is_in_recovery()                                                           as is_replica,
       inet_server_addr()                                                            as server_addr,
       current_setting('TimeZone')                                                   as session_timezone,
       (now() - interval '28 days')                                                  as legacy_window_start,
       count(*)                                                                      as total_rows_all_users,
       count(distinct user_id)                                                       as total_distinct_users  -- MUST be >> 1
from public.asset_pref_mirror;

-- [G5] HARD EMPIRICAL ABORT: if we can only see <=1 user, the session is RLS-scoped despite G1.
--      This catches FORCE-RLS / membership / mis-config cases that the attribute guard can miss.
do $$
declare v_users bigint := (select count(distinct user_id) from public.asset_pref_mirror);
begin
  if v_users <= 1 then
    raise exception 'GUARD FAIL G5: distinct_users=% (<=1) -> session is RLS-scoped to a single identity; counts are a FALSE near-zero. Re-run as a BYPASSRLS role on the primary.', v_users;
  end if;
  -- anchor the global denominator into a session GUC for cross-statement equality checks (read-only safe).
  perform set_config('dryrun.denominator', v_users::text, true);
  raise notice 'GUARD G5 PASS: distinct_users=% anchored as dryrun.denominator', v_users;
end $$;

-- -----------------------------------------------------------------------------
-- [D] DENYLIST / ANOMALY SWEEP  -- classify EVERY pref_key against the 14-key universe.
--     ANY key outside the universe = ANOMALY (forgotten/renamed legacy, case/ws/Unicode variant,
--     or taxonomy drift). It must be triaged: the final DELETE IN(5 legacy) would MISS it.
-- -----------------------------------------------------------------------------
with classified as (
  select pref_key,
         lower(btrim(pref_key))                                  as norm_key,   -- ASCII case/ws fold ONLY
         (pref_key <> lower(btrim(pref_key)))                    as had_case_or_ascii_ws_variant,
         (pref_key ~ '[^ -~]')                                   as has_non_ascii_bytes,  -- NBSP / zero-width / 全角
         count(*)                                                as rows,
         count(distinct user_id)                                 as users,
         min(updated_at)                                         as oldest_write,
         max(updated_at)                                         as latest_write,
         count(*) filter (where updated_at > now())              as future_dated_rows,
         count(*) filter (where value is null)                   as null_value_rows,    -- impossible by DDL; tripwire
         count(*) filter (where value = 'null'::jsonb)           as jsonb_null_rows,
         count(*) filter (where value in ('{}'::jsonb,'[]'::jsonb)) as empty_container_rows
  from public.asset_pref_mirror
  group by pref_key
)
select pref_key, rows, users, oldest_write, latest_write, future_dated_rows,
       null_value_rows, jsonb_null_rows, empty_container_rows,
       had_case_or_ascii_ws_variant, has_non_ascii_bytes,
       case
         when norm_key in ('asset_display_prefs_v1','asset_inflow_prefs_v1')                        then 'AGGREGATED_keep'
         when norm_key in ('display_mode','section_overrides','section_override_deleted',
                           'inflow_deleted_ids','inflow_tombstone_gc')                              then 'LEGACY_retire'
         when norm_key in ('debt_payment_day_overrides','debt_payment_day_override_deleted',
                           'revolving_credit_configs','revolving_credit_configs_deleted',
                           'main_account_id','watchlist_entries','watchlist_entries_deleted')       then 'CURRENT_never_delete'
         else                                                                                            'ANOMALY_triage'
       end                                                                                          as classification,
       case when pref_key <> norm_key
             and norm_key in ('display_mode','section_overrides','section_override_deleted',
                              'inflow_deleted_ids','inflow_tombstone_gc')
            then 'LEGACY_VARIANT_hidden_from_IN_list' else null end                                  as variant_alert
from classified
order by (case
            when norm_key in ('display_mode','section_overrides','section_override_deleted',
                              'inflow_deleted_ids','inflow_tombstone_gc') then 0
            when norm_key not in ('asset_display_prefs_v1','asset_inflow_prefs_v1',
                              'debt_payment_day_overrides','debt_payment_day_override_deleted',
                              'revolving_credit_configs','revolving_credit_configs_deleted',
                              'main_account_id','watchlist_entries','watchlist_entries_deleted',
                              'display_mode','section_overrides','section_override_deleted',
                              'inflow_deleted_ids','inflow_tombstone_gc') then 1
            else 2 end), rows desc, pref_key;

-- [D2] HARD VERDICTS (one row of numbers for the gate record).
with classified as (
  select lower(btrim(pref_key)) as norm_key, pref_key, value, updated_at, user_id
  from public.asset_pref_mirror
)
select
  count(*) filter (where norm_key in ('display_mode','section_overrides','section_override_deleted',
                                      'inflow_deleted_ids','inflow_tombstone_gc'))                   as legacy_residual_rows,        -- MUST be 0 (Gate 2)
  count(*) filter (where norm_key not in (
        'asset_display_prefs_v1','asset_inflow_prefs_v1',
        'display_mode','section_overrides','section_override_deleted','inflow_deleted_ids','inflow_tombstone_gc',
        'debt_payment_day_overrides','debt_payment_day_override_deleted','revolving_credit_configs',
        'revolving_credit_configs_deleted','main_account_id','watchlist_entries','watchlist_entries_deleted'))
                                                                                                    as anomaly_unknown_rows,        -- MUST be 0
  count(*) filter (where pref_key <> norm_key)                                                      as case_or_ws_variant_rows,     -- MUST be 0
  count(*) filter (where pref_key ~ '[^ -~]')                                                       as non_ascii_key_rows,          -- MUST be 0
  count(*) filter (where norm_key in ('display_mode','section_overrides','section_override_deleted',
                                      'inflow_deleted_ids','inflow_tombstone_gc')
                    and updated_at > now() - interval '28 days')                                     as recent_legacy_writes,        -- MUST be 0 (Gate 3 necessary)
  count(distinct user_id) filter (where norm_key in ('display_mode','section_overrides','section_override_deleted',
                                      'inflow_deleted_ids','inflow_tombstone_gc')
                    and updated_at > now() - interval '28 days')                                     as recent_legacy_writers,       -- MUST be 0 (Gate 3 necessary)
  count(*) filter (where norm_key in ('display_mode','section_overrides','section_override_deleted',
                                      'inflow_deleted_ids','inflow_tombstone_gc')
                    and updated_at > now())                                                          as legacy_future_dated_rows,    -- expect 0 (else inspect)
  count(*) filter (where norm_key in (
        'debt_payment_day_overrides','debt_payment_day_override_deleted','revolving_credit_configs',
        'revolving_credit_configs_deleted','main_account_id','watchlist_entries','watchlist_entries_deleted'))
                                                                                                    as current_key_rows_positive_control  -- MUST be > 0
from classified;

-- [B] GATE-3 DECAY BUCKETS  -- legacy writes by age (convergence curve, stronger than a single 28d count).
--     Across weekly soak runs this MUST be monotonically non-increasing toward zero, and
--     writers_last_7d MUST trend to 0. NOTE: survivor selection is biased by new-client cleanup deletes,
--     so this is necessary, NOT sufficient -- cross-check Gate 3 with app-version telemetry.
with leg as (
  select user_id, updated_at from public.asset_pref_mirror
  where lower(btrim(pref_key)) in ('display_mode','section_overrides','section_override_deleted',
                                   'inflow_deleted_ids','inflow_tombstone_gc')
)
select count(*) filter (where updated_at > now() - interval '7 days')                                as w_0_7d,
       count(*) filter (where updated_at <= now() - interval '7 days'
                          and updated_at >  now() - interval '28 days')                              as w_8_28d,
       count(*) filter (where updated_at <= now() - interval '28 days'
                          and updated_at >  now() - interval '90 days')                              as w_29_90d,
       count(*) filter (where updated_at <= now() - interval '90 days')                              as w_over_90d,
       count(distinct user_id) filter (where updated_at > now() - interval '7 days')                 as writers_last_7d,
       count(distinct user_id) filter (where updated_at > now() - interval '28 days')                as writers_last_28d,
       max(updated_at)                                                                               as most_recent_legacy_write
from leg;

-- -----------------------------------------------------------------------------
-- [S] SUCCESSOR ROW-COVERAGE ANTI-JOIN  (legacy-only users = the data-loss case on fallback removal).
--     A legacy-holding user MUST also hold the matching aggregated successor ROW.
--     Also includes the DENOMINATOR-ANCHOR equality check against G5.
-- -----------------------------------------------------------------------------
with m as (select user_id, lower(btrim(pref_key)) as k from public.asset_pref_mirror),
display_legacy as (select distinct user_id from m where k in ('display_mode','section_overrides','section_override_deleted')),
inflow_legacy  as (select distinct user_id from m where k in ('inflow_deleted_ids','inflow_tombstone_gc')),
has_display_agg as (select distinct user_id from m where k = 'asset_display_prefs_v1'),
has_inflow_agg  as (select distinct user_id from m where k = 'asset_inflow_prefs_v1')
select
  (select count(*) from display_legacy d where not exists (select 1 from has_display_agg a where a.user_id=d.user_id))
                                                                                  as display_legacy_without_successor, -- MUST be 0
  (select count(*) from inflow_legacy  i where not exists (select 1 from has_inflow_agg  a where a.user_id=i.user_id))
                                                                                  as inflow_legacy_without_successor,  -- MUST be 0
  (select count(*) from display_legacy) as users_with_display_legacy,
  (select count(*) from inflow_legacy)  as users_with_inflow_legacy,
  (select count(*) from display_legacy d where exists (select 1 from has_display_agg a where a.user_id=d.user_id)) as display_mid_migration_both, -- gated input to [S2]
  (select count(*) from inflow_legacy  i where exists (select 1 from has_inflow_agg  a where a.user_id=i.user_id)) as inflow_mid_migration_both,  -- gated input to [S2]
  (select count(distinct user_id) from public.asset_pref_mirror)                 as snapshot_distinct_users,           -- must equal G5
  ((select count(distinct user_id) from public.asset_pref_mirror)
     = current_setting('dryrun.denominator')::bigint)                            as denominator_consistent;           -- MUST be true

-- [S-assert] DENOMINATOR DRIFT hard abort: same-snapshot user count must equal the G5 anchor.
do $$
declare v_now bigint := (select count(distinct user_id) from public.asset_pref_mirror);
        v_anchor bigint := current_setting('dryrun.denominator')::bigint;
begin
  if v_now <> v_anchor then
    raise exception 'DENOMINATOR DRIFT: cohort distinct_users=% <> G5 anchor=% -> session re-scoped or non-snapshot run; DISCARD this run.', v_now, v_anchor;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- [S2] SUB-KEY + TOMBSTONE-SUBSET COVERAGE  (row-presence is NOT enough).
--      For each user holding a NON-EMPTY legacy row, the aggregated successor's matching
--      sub-key MUST be present/non-empty; for tombstone keys the legacy id-set MUST be a
--      SUBSET of the successor's id-set (else a deleted item RESURRECTS on cleanup).
--      Aggregated shapes (verified on origin/main):
--        asset_display_prefs_v1.value = {mode, section_overrides:{id:state}, section_override_deleted:[id]}
--        asset_inflow_prefs_v1.value  = {deleted_ids:{ids:[id]}, gc:{...}}
-- -----------------------------------------------------------------------------
with leg as (
  select user_id, lower(btrim(pref_key)) as k, value from public.asset_pref_mirror
  where lower(btrim(pref_key)) in ('display_mode','section_overrides','section_override_deleted',
                                   'inflow_deleted_ids','inflow_tombstone_gc')
),
dagg as (select user_id, value as v from public.asset_pref_mirror where lower(btrim(pref_key))='asset_display_prefs_v1'),
iagg as (select user_id, value as v from public.asset_pref_mirror where lower(btrim(pref_key))='asset_inflow_prefs_v1')
select
  -- display_mode -> successor.value->'mode' present when legacy mode is non-empty.
  count(*) filter (where l.k='display_mode'
        and l.value->>'mode' is not null and l.value->>'mode' <> ''
        and coalesce(d.v->>'mode','') = '')                                       as display_mode_subkey_uncovered,        -- MUST be 0
  -- section_overrides -> successor.value->'section_overrides' non-empty when legacy non-empty.
  count(*) filter (where l.k='section_overrides'
        and jsonb_typeof(l.value)='object' and l.value <> '{}'::jsonb
        and coalesce(jsonb_typeof(d.v->'section_overrides'),'null')='null')       as section_overrides_subkey_uncovered,   -- MUST be 0
  -- section_override_deleted tombstone -> legacy id-set MUST be SUBSET of successor's array.
  count(*) filter (where l.k='section_override_deleted'
        and jsonb_typeof(l.value)='array' and jsonb_array_length(l.value) > 0
        and not (l.value <@ coalesce(d.v->'section_override_deleted','[]'::jsonb))) as section_tombstone_ids_lost,           -- MUST be 0
  -- inflow_deleted_ids tombstone -> legacy {ids:[...]} MUST be subset of successor.deleted_ids.ids.
  count(*) filter (where l.k='inflow_deleted_ids'
        and jsonb_typeof(l.value->'ids')='array' and jsonb_array_length(l.value->'ids') > 0
        and not ((l.value->'ids') <@ coalesce(i.v->'deleted_ids'->'ids','[]'::jsonb))) as inflow_tombstone_ids_lost,        -- MUST be 0
  -- inflow_tombstone_gc -> successor.value->'gc' present when legacy gc non-empty.
  count(*) filter (where l.k='inflow_tombstone_gc'
        and jsonb_typeof(l.value)='object' and l.value <> '{}'::jsonb
        and coalesce(jsonb_typeof(i.v->'gc'),'null')='null')                      as inflow_gc_subkey_uncovered            -- MUST be 0
from leg l
left join dagg d on d.user_id = l.user_id
left join iagg i on i.user_id = l.user_id;

-- -----------------------------------------------------------------------------
-- [S3] STALE LEGACY NEWER THAN AGGREGATE  (mid-migration "both" users).
--      If a user's legacy row is STRICTLY NEWER than its aggregated row, then EITHER an old
--      client is still writing legacy AFTER a new client wrote aggregated (Gate-3 proof, survives
--      the delete race), OR a naive "fold legacy forward" remediation would resurrect stale state.
--      These users need per-user manual reconciliation, never a blanket fold.
-- -----------------------------------------------------------------------------
with m as (select user_id, lower(btrim(pref_key)) as k, updated_at from public.asset_pref_mirror),
disp as (
  select l.user_id,
         max(l.updated_at) as leg_latest,
         (select max(updated_at) from m a where a.user_id=l.user_id and a.k='asset_display_prefs_v1') as agg_at
  from m l where l.k in ('display_mode','section_overrides','section_override_deleted') group by l.user_id),
infl as (
  select l.user_id,
         max(l.updated_at) as leg_latest,
         (select max(updated_at) from m a where a.user_id=l.user_id and a.k='asset_inflow_prefs_v1') as agg_at
  from m l where l.k in ('inflow_deleted_ids','inflow_tombstone_gc') group by l.user_id)
select
  count(*) filter (where agg_at is not null and leg_latest > agg_at) from disp         as display_legacy_newer_than_aggregate, -- MUST be 0
  (select count(*) filter (where agg_at is not null and leg_latest > agg_at) from infl) as inflow_legacy_newer_than_aggregate;  -- MUST be 0

-- -----------------------------------------------------------------------------
-- [O] FK INTEGRITY  -- (a) structural: the ON DELETE CASCADE FK still exists; (b) orphan anti-join.
--     NOTE: [O](b)=0 is meaningful ONLY because G1/G5 proved BYPASSRLS; a scoped session also returns 0.
-- -----------------------------------------------------------------------------
select
  (select count(*) from pg_constraint
     where conrelid='public.asset_pref_mirror'::regclass and contype='f' and confdeltype='c')  as cascade_fk_present,   -- MUST be 1
  (select count(*) from public.asset_pref_mirror m
     left join auth.users u on u.id = m.user_id where u.id is null)                              as orphan_rows;          -- MUST be 0

-- -----------------------------------------------------------------------------
-- [V] LEGACY RESIDUAL VALUE-SHAPE  (diagnostic only; informs the Layer-2 cleanup decision).
--     Empty husks are STILL residual and STILL block the gate (see [D2] legacy_residual_rows).
--     Empty detection covers tombstone-shaped husks {'ids':[]} and {'mode':null}, not only {}/[]/null.
-- -----------------------------------------------------------------------------
select lower(btrim(pref_key)) as legacy_key,
       jsonb_typeof(value)    as value_type,
       count(*)               as rows,
       count(*) filter (where value in ('null'::jsonb,'{}'::jsonb,'[]'::jsonb)
                           or (value ? 'ids'  and jsonb_typeof(value->'ids')='array'
                                              and jsonb_array_length(value->'ids')=0)
                           or (value ? 'mode' and value->>'mode' is null)) as empty_like_rows
from public.asset_pref_mirror
where lower(btrim(pref_key)) in ('display_mode','section_overrides','section_override_deleted',
                                 'inflow_deleted_ids','inflow_tombstone_gc')
group by 1,2
order by 1,2;

rollback;   -- ALWAYS rollback. The dry-run persists NOTHING. Never commit this block.
```

### 4.1 PASS / FAIL しきい値 (この一覧で判定する / 全 PASS で着手可)

```
GUARD (前提 — 1 つでも raise したら STOP し文脈を直して再実行):
  G0/G1/G1b  ... no exception           (BYPASSRLS or owner+force-RLS-off; membership は不可)
  G2/G2-role ... no exception           (request.jwt.claims / role GUC 未バインド)
  G2b        ... no exception           (auth.uid() = NULL / 予期せぬ SQLSTATE は fail-closed)
  G3         ... no exception           (primary: in_recovery=false かつ replay_lsn=NULL)
  G4 total_distinct_users ............. >> 1  (全ユーザー基盤 / 1 なら scoped=STOP)
  G5         ... no exception           (distinct_users >= 2 の経験的 abort)
  denominator_consistent (in [S]) ..... true  かつ [S-assert] no exception (snapshot drift 無し)

GATE 2 — legacy 残存ゼロ (binding / 全て 0):
  D2 legacy_residual_rows ............. = 0   ★ Gate 2 の主判定
  D2 anomaly_unknown_rows ............. = 0   (= [D] の ANOMALY_triage を全て解消)
  D2 case_or_ws_variant_rows .......... = 0
  D2 non_ascii_key_rows ............... = 0   (NBSP/ゼロ幅/全角 等の異形)
  D2 legacy_future_dated_rows ......... = 0   (>0 なら corrupt/手動 backfill を調査)
  D2 current_key_rows_positive_control  > 0   (populated global table に当たった証拠 / 0 は STOP)

GATE 3 — 旧クライアント不在 (on-table は必要条件 / 十分条件は app-version telemetry):
  D2 recent_legacy_writes ............. = 0
  D2 recent_legacy_writers ............ = 0
  B  writers_last_7d / w_0_7d ......... 0 へ単調収束(weekly soak で非増加)
  S3 *_legacy_newer_than_aggregate .... = 0  ★ active 旧 writer の直接証拠(delete race に強い)

データ損失ゼロ (binding / 全て 0 / これが「集約行が真実」の検証):
  S  display_legacy_without_successor .. = 0
  S  inflow_legacy_without_successor ... = 0
  S2 display_mode_subkey_uncovered ..... = 0
  S2 section_overrides_subkey_uncovered  = 0
  S2 section_tombstone_ids_lost ........ = 0   ★ tombstone subset 包含
  S2 inflow_tombstone_ids_lost ......... = 0   ★ tombstone subset 包含
  S2 inflow_gc_subkey_uncovered ........ = 0

不変条件:
  O cascade_fk_present ................. = 1
  O orphan_rows ........................ = 0

診断のみ (gate を上書きしない):
  V ... empty/husk 行も「残存」であり gate を block する。V は Layer-2 cleanup の意思決定にのみ用いる。

最終判定: 上記すべて PASS を 24h 以上あけた 2 スナップショットで満たし(下記 §5 Step 8 の固定窓 delta=0)、
           かつ Gate 1(>=4 週 + >=2026-07-11)が手動で確認できれば、撤去 (cutover) へ進む。
```

> 🔴 **[V] は診断のみ。** 「空 `{}` だから無視して進む」は禁止。空 husk も residual であり
> `legacy_residual_rows` を 0 にしない限り gate は PASS しない。値の形に関わらず `legacy_residual_rows = 0` が必須。

---

## 5. オペレータ手順 (RUNBOOK / 2026-07-11 以降・本番オペレータ専用)

1. **Gate 1 確認**: 暦日 >= 2026-07-11 かつ Phase 2 リリースから >= 4 週間。両日付を gate ログに記録。
2. **クリーンなタブ**(P3)で **§4 の SQL ブロック全文を 1 回の Run** で実行。先頭の `reset` と
   `begin; set transaction isolation level repeatable read read only; ... rollback;` が単一スナップショット + write 拒否を保証。
3. **GUARD を最初に読む**。`GUARD FAIL ...` / `DENOMINATOR DRIFT` が 1 つでも出たら **STOP**。文脈(service_role/postgres・primary・クリーンタブ)を直して再実行。
   次に **[G4] `total_distinct_users` が 1 でない(全ユーザー基盤)** ことを目視。`total_rows_all_users` と `total_distinct_users` を gate ログへ(以後の全数値の分母)。
4. **[D] denylist sweep を上から精査**。`ANOMALY_triage` / `variant_alert≠null` / `has_non_ascii_bytes=true` / `had_case_or_ascii_ws_variant=true` の行があれば **STOP し triage**。
   各 anomaly が (a) cleanup に畳む legacy 異形 / (b) コードマップ漏れの現行キー / (c) 要調査の junk のどれかを判断し、**gate ログに全件説明を残すまで進まない**。
   - 🔴 **14-key ユニバースを使うこと**(12-key で組むと `revolving_credit_configs_deleted` / `watchlist_entries_deleted` を誤って anomaly 化し、live data を消す恐れ)。
5. **[D2] verdicts**: §4.1 の Gate 2 行をすべて満たすか確認。`current_key_rows_positive_control = 0` なら populated table に当たっていない → **STOP**。
6. **[B] decay buckets**: `writers_last_7d` / `w_0_7d` が 0 へ収束しているか(weekly soak で非増加)。`most_recent_legacy_write` を記録。
7. **[S] / [S2] / [S3]**: §4.1 の「データ損失ゼロ」「Gate 3」行がすべて 0。
   - `*_without_successor > 0` = legacy-only ユーザー(後継行なし)= **撤去で設定が消える真のデータ損失ケース** → §6.A の dormancy 対応をするまで cutover しない。
   - `*_subkey_uncovered > 0` / `*_tombstone_ids_lost > 0` = 後継行は在るがサブキー/削除 id が未 fold → **撤去/cleanup で消える** → 該当ユーザーを fold するまで進まない。
   - `*_legacy_newer_than_aggregate > 0` = active 旧 writer か stale fold リスク → **per-user 手動照合**(blanket fold 禁止)。
8. **[O]**: `cascade_fk_present = 1`(構造不変)かつ `orphan_rows = 0`。
9. **[V]**: residual の中身が実データか空 husk かを記録(cleanup の lossless 判断材料。gate は上書きしない)。
10. **2 スナップショット delta(active writer 検知)**: **24h 以上あけて(or weekly soak で)全ブロックを再実行**。
    - `legacy_residual_rows` / `recent_legacy_writers` / **`most_recent_legacy_write`(固定窓比較)** を比較。
    - `most_recent_legacy_write` が前回より進む or residual/writers が増加 = **旧クライアントが依然 active** → **Gate 3 FAIL → cutover しない**。app-version/deploy telemetry で旧ビルドの phone-home を確認。
    - 🔴 注: `now()-28d` は窓がスライドするため、cross-run の主信号は **固定タイムスタンプ `most_recent_legacy_write` の前進有無** とする。
11. **全結果をアーカイブ**: 各 run の timestamp / `current_user` / `total_distinct_users` / [D2]/[S]/[S2]/[S3]/[O] の全数値を **Phase 3 PR / migration ログ**へ BASELINE として保存(gate を満たした証跡 + ロールバック基準点)。

> **dry-run はここで完了し、完全に READ-ONLY**。撤去が安全かを判定するだけで、**DELETE は一切行わない**。

---

## 6. CUTOVER (撤去) — 2 層 / この順序で

dry-run が **2 スナップショット(24h 以上間隔)で delta=0** かつ §4.1 全 PASS のときのみ着手。

### 6.A (必要時のみ) dormancy carve-out — gate が永遠に 0 にならない場合の逃げ道

休眠ユーザー(1 度だけ使い legacy 行を残したまま二度と新クライアントを開かない)は
`*_without_successor` を永久に >0 のままにし得る。その場合のみ、**Phase 2 より前から休眠(legacy 行の `max(updated_at)` が
soak 窓より古く、集約行を持たない)と証明できるユーザーに限り**、サーバ側 one-off fold(legacy value → 集約行サブキーへ upsert)を許可する。
これは **データを変更する** ので **dry-run の対象外**。独立した backup-then-write + ロールバックを持つ別 cutover サブステップとして扱う(§7.R2 と同型)。

### 6.B LAYER 1 — フラグ化したコード撤去 (即時ロールバック / データ無変更 / 先にやる)

既存の feature-flag パターン(`AssetMirrorReadPolicy.flagName = 'ASSET_MIRROR_READS_AUTHORITATIVE'`,
`bool.fromEnvironment(name, defaultValue: false)` / `lib/services/asset_mirror_read_policy.dart`)を踏襲。

1. **C1.** 新フラグ `ASSET_LEGACY_PREF_READ_DISABLED`(default **false**)を同ファイルへ追加。
2. **C2.** `lib/pages/asset_management_page.dart` の **4 read-fallback サイトを関数名で再特定**し、フラグが **true のとき legacy `inFilter` エントリと legacy-row 分岐をスキップ**(集約のみ読む)、**false なら現行挙動不変**:
   - `_fetchDisplayPrefRows()`(legacy `display_mode` / `section_overrides`)と restore ループの legacy 分岐。
   - `_pullDeletedSectionIds()`(`section_override_deleted` 分岐)。
   - `_pullInflowDeletedIds()`(`inflow_deleted_ids` 分岐)。
   - `_loadTombstoneGcConfig()`(`inflow_tombstone_gc` 分岐)。
   - `_cleanupLegacyDisplayPrefRows` / `_cleanupLegacyInflowPrefRows` と、`asset_management_display_mode_store.dart` の
     **メモリ内合成 evaluator**(`aggregatedMirrorToRows` / `evaluateMirrorPrefRows` の legacy 分岐)は **変更しない**(DB 読みではない)。
   - 🔴 撤去 commit 上で **行番号でなく関数名**で再特定し、各々が「集約優先 → legacy」のままであることを確認してから gate する(24k 行 page は行番号が毎回ズレる)。
3. **C3. 可観測性**: 4 関数は現状 `debugPrint('... failed: $e')` でエラーを握り潰す → 撤去後の shape/schema 破綻が **本番で不可視**。soak 期間だけ catch を `lib/utils/error_reporter.dart` 経由にして観測可能にする。
4. **C4. 段階展開**: `deploy-staging.yml` に `--dart-define=ASSET_LEGACY_PREF_READ_DISABLED=true` を追加 → staging soak → `deploy-prod.yml`。**>= 1 release cycle** §6.C のテレメトリを監視。
5. **C5.** prod で flag=true が clean soak を通過した後、**死んだ legacy 分岐を後続 PR で削除**(挙動上は no-op)。

> 🔴 **High-risk gate 対策(`deploy-staging.yml` / `deploy-prod.yml` 編集で発火)**: PR **作成時点**で body に
> `High-risk-ultrareview-exception: <12 文字以上の理由>` の 1 行 + `Claude Code #1` の attribution を入れる(後から body 編集しても CI は再走しないので close/reopen が必要)。
> dart-define 追加の 2 行が trigger だと PR 作成者に予告する。gate が散文の単語で誤発火したら言い換えて close/reopen。

### 6.C soak 中に監視するテレメトリ

- **空状態リグレッション**: `AssetSyncStatusSummary`(`lib/services/asset_sync_status.dart`)の
  `asset_sync_status_chip` が display/inflow ドメインで `localOnly`/`empty` を出すスパイク、
  「セクション配置 / 非表示セクション / 削除した入金が復活した」ユーザー報告。
- **クライアントエラー**: C3 で error_reporter 経由にした 4 関数のエラー。
- **サーバ信号**: dry-run を再実行し `recent_legacy_writes` / `most_recent_legacy_write` が **上昇/前進** = 旧クライアント active → **Layer 2 に進まない**。

### 6.D LAYER 2 — (任意) 最終クリーンアップ DELETE (唯一の不可逆操作 / dry-run と分離)

**前提**: `[S]/[S2]/[S3]` の全データ損失行 = 0 **かつ** `[D2] anomaly_unknown_rows = 0` **かつ** Layer-1 flag が prod で **>=1 soak cycle** clean。

**hard-delete しない。同一トランザクションで backup → delete し、rowcount を自己アサート**(同日重複 backup は事前に弾く):

```sql
begin;

-- 同日バックアップが既にあれば中断(部分実行後の上書きで安全網が縮むのを防ぐ)。
do $$ begin
  if to_regclass('public.asset_pref_mirror_legacy_backup_20260711') is not null then
    raise exception 'backup table already exists -> a prior run may have partially executed; inspect before proceeding.';
  end if;
end $$;

create table public.asset_pref_mirror_legacy_backup_20260711 as
  select * from public.asset_pref_mirror
  where lower(btrim(pref_key)) in
    ('display_mode','section_overrides','section_override_deleted','inflow_deleted_ids','inflow_tombstone_gc');

-- ★ 削除は dry-run が分類した EXACT な行に限定するのが最も安全(検査集合 = 削除集合)。
--   正規化 IN は NBSP/ゼロ幅/全角を取りこぼすため、それらは dry-run [D] で個別に主キー指定して消す。
delete from public.asset_pref_mirror m
  using public.asset_pref_mirror_legacy_backup_20260711 b
  where m.user_id = b.user_id and m.pref_key = b.pref_key;

-- backup 件数 = delete 件数 = dry-run residual を自己アサート(<EXPECTED_RESIDUAL> は §5 Step 11 の baseline 値)。
do $$
declare v_backup bigint := (select count(*) from public.asset_pref_mirror_legacy_backup_20260711);
begin
  -- 例: if v_backup <> <EXPECTED_RESIDUAL> then raise exception 'rowcount mismatch ...'; end if;
  raise notice 'legacy backup rows = % (compare to dry-run baseline before commit)', v_backup;
end $$;

commit;   -- 数値が baseline と一致したら commit。意外な値なら rollback。
```

backup 表は **soak 1 サイクル後に drop**。

---

## 7. ロールバック

独立した 2 層。**より新しく・より可逆な層から先に戻す(R1 → R2)**。

- **R1 — コード撤去 (Layer 1) / 即時・データ無変更**:
  `deploy-prod.yml`(と staging)から `--dart-define=ASSET_LEGACY_PREF_READ_DISABLED=true` の 1 行を削除して再デプロイ。
  flag は default false なので **legacy 読みフォールバックが即座に復活**。DB 行は Layer 1 では一切変更していないので他に戻すものはない。
  これは「PR revert」(コード変更 + 再デプロイ + 24k 行 page の stale-branch 衝突リスク)より厳密に優れる。

- **R2 — 最終 DELETE (Layer 2) / backup からの再 insert で可逆化**:
  ```sql
  insert into public.asset_pref_mirror
    select * from public.asset_pref_mirror_legacy_backup_20260711
    on conflict (user_id, pref_key) do nothing;   -- 新しい現行行を絶対に上書きしない
  ```
  必要なら R1 を「legacy を読む」状態に戻してから(でないと復元行がクライアントに反映されない)。backup 表は無回帰確認後に drop。

- **R3 — dry-run 自体**: 変更しようがない。全文が `SELECT` / `WITH...SELECT` / `DO`(introspection + RAISE)で、
  `begin; set transaction isolation level repeatable read read only; ... rollback;` に包まれている。エンジンが書き込みを拒否し、明示 rollback が破棄する。戻すものは無い。

> **順序規則**: 常に R1(legacy 読み復活)を先に安全状態へ。R1 が legacy-reading になっていないまま R2 の再 insert をすると、復元行がクライアントから見えない。

---

## 8. 残存リスク (このゲートでも残るもの)

1. **Gate 3 は本テーブルから証明不能**: `updated_at` は WRITE のみ観測し、READ や「休眠中だが再起動すれば書く」端末は観測できない。さらに新クライアントが boot 毎に legacy 行を best-effort delete するため、active な旧クライアントの書き込みも即削除されて単一スナップショットでは `recent_legacy_writes=0` に見えうる。→ **`[S3]` の legacy-newer-than-aggregate**(delete race に強い直接証拠)と **app-version/deploy telemetry**(Phase 2 より古いビルドが直近 4 週 phone-home していない)を hard precondition とする。
2. **サブキー検証はスキーマ固定前提**: `[S2]` は現行の集約 value shape(`{mode,section_overrides,section_override_deleted}` / `{deleted_ids,gc}`)に依存。将来サブキー名が変わると静かに false-pass。撤去 commit 上で実 value shape を毎回再確認。
3. **正規化の限界**: `lower(btrim())` は ASCII 大小・前後 ASCII 空白のみ。NBSP/ゼロ幅/全角/confusable は畳めないが、`ANOMALY_triage` + `non_ascii_key_rows` で gate を必ず止める(安全)。Layer-2 削除は **正規化 IN ではなく dry-run が列挙した実 (user_id, pref_key) を主キー指定**で消し、検査集合=削除集合を保証する。
4. **単一スナップショット保証は 1 Run 前提**: Supabase は Run 毎に auto-commit。ブロックを分割実行すると denominator drift が起きうるが、`[G5]` anchor と `[S]/[S-assert]` の同一性アサートで自己検知し、不一致なら破棄・再実行。
5. **`[O]` の前提**: orphan/FK チェックは BYPASSRLS 証明後のみ有意。`G1`/`G5` が PASS していない限り `orphan_rows=0` は scoped-self による自明 0 でありうる(信用しない)。
6. **Gate 1 は業務事実依存**: 「>=4 週」「Phase 2 リリース日」は deploy 記録/PR merge 日からの手動照合に依存。記録漏れで誤判定しうる。
7. **Layer-2 DELETE は唯一の不可逆**: backup-then-delete + rowcount 自己アサートで可逆化するが、backup 表 drop 後は復元不能。soak 1 サイクル完了まで drop しない運用規律に依存する。

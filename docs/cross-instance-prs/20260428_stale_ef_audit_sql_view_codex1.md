# Cross-Instance PR: stale-EF audit ロジックを SQL view 化

**作成**: Win版#132 part 54 / 2026-04-28
**依頼先**: **Codex#1** (`.claude/worktrees/instance-codex1` / `codex/codex1-wip`)
**優先度**: LOW (改善 / 機能影響なし)
**推定工数**: 30-60 min / 1 SQL migration

---

## 判定 5 質問の答え

| Q | 答え |
| --- | --- |
| Q1. 設計判断 / trade-off 検討必要? | **NO** (= 既存 Python script の SQL 化) |
| Q2. cross-instance 調整必要? | **NO** (PS#5 既存実装の単純な並列実装) |
| Q3. 軸 docs 更新必要? | **NO** |
| Q4. docs に残す価値ある判断? | **NO** (mechanical 移植) |
| Q5. NotebookLM 連携要? | **NO** |

→ **全 NO = Codex 適合** (docs/CODEX_WORKFLOW.md §6 routing matrix 適用)

---

## 起票背景

PS#5 S75 (commit 10025c1e+53bb3e3f) で `scripts/audit_hub_migration_completeness.py`
+ `.github/workflows/stale-ef-completeness-check.yml` を実装し、stale EF 移行で
**hub 側に action が完全実装されていない** 状況を CI で検出可能化した。

ただし現状は Python script が file 走査で検出する構造のため、**実行時 (runtime) に
Supabase DB から「過去に呼ばれた legacy URL が今 deploy されていない」事実を
検出できない**。Win版 part 50 で発見した「memo-reactions 404」のような
production-only な事象は事後発覚するしかない。

→ 解決策: `pg_stat_statements` (Supabase で有効化) + `mcp_audit_log` (Win版 part 49 で
作成) を組み合わせて、**「直近 24h で呼ばれた function path のうち deploy-prod に
含まれない URL」を 1 view で集計** すれば runtime 検出が可能。

これは **mechanical SQL view 構築** = Codex#1 (SQL/migration 専任) の典型タスク。

## 既存 pattern (= Codex が複製する template)

### 参考 1: scripts/audit_hub_migration_completeness.py の検出ロジック
- Win版 part 50 cross-instance-pr で記載した検出例 (file path + grep pattern)
- 既存 file `.github/workflows/stale-ef-completeness-check.yml` をそのまま読んで
  検出条件を SQL に落とす

### 参考 2: 既存 view migration の pattern
- `supabase/migrations/` から `CREATE OR REPLACE VIEW` を含む migration を 1 件選ぶ
  (例: horse_provider_leaderboard view 等)
- naming 規則: `<timestamp>_create_<view_name>_view.sql`

### 参考 3: deploy-prod.yml の deploy list 抽出
```bash
grep "supabase functions deploy" .github/workflows/deploy-prod.yml \
  | grep -v "^#" | awk '{print $4}' | sort
```
これを SQL の WHERE 節相当として参照する (= GHA cron で先に list を JSON にして
Supabase に INSERT する方式 / または migration に直接 hardcode する方式)

## 期待アウトプット

新 migration: `supabase/migrations/<空 timestamp>_create_stale_ef_runtime_view.sql`

```sql
-- View: stale_ef_runtime_invocations
-- 直近 24h で呼ばれた function path のうち deploy-prod に含まれない URL を抽出
--
-- WARNING: pg_stat_statements / supabase_functions log の参照可否を Codex が判定。
--          直接読めない場合は deploy_prod_function_list table (新規) を併設して
--          GHA cron で deploy list を sync する方式を提案する。
CREATE OR REPLACE VIEW public.stale_ef_runtime_invocations AS
SELECT
  -- function path / 呼出回数 / 最新呼出時刻
FROM
  -- pg_stat_statements OR supabase_functions log table
WHERE
  function_path NOT IN (
    SELECT function_name FROM deploy_prod_function_list  -- ← 新規 table
  )
  AND last_invoked_at > now() - interval '24 hours';

COMMENT ON VIEW public.stale_ef_runtime_invocations IS
  'Stale EF runtime detection — Win版#132 part 54 (codex#1 handoff)';
```

## 完了条件

- [ ] 新 migration 1 件 (`<timestamp>_create_stale_ef_runtime_view.sql`)
  - timestamp は `python scripts/check_migration_timestamps.py` で衝突確認後に決定
  - 当日 (2026-04-28) なら `20260428170000` 以降推奨 (= 直近 timestamp 120000+)
- [ ] 必要なら deploy_prod_function_list table も同 migration で作成
- [ ] `supabase db lint` pass
- [ ] git commit + push origin HEAD:main
- [ ] 起票者 (Win版) が memory に記録 — Codex#1 は memory 触らない

## OPERATIONS_CHARTER 整合

- 改善トリガー #4 (正本ズレ) = runtime ↔ deploy list の正本ズレ検出を強化
- 5 正本層 #5 (worktree/main vs production) = 検出範囲を file 走査 → runtime に拡大

## handoff template 適用 (= part 53 で確立)

本 PR は part 53 で確立した handoff template (5 質問 + 既存 pattern + 期待アウトプット +
完了条件) のフル実例 = Codex routing matrix の dogfood 事例。

---

*Win版#132 part 54 / 2026-04-28 起票 / Codex routing matrix 初回適用*

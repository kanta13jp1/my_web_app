# [Codex CLI 宛] WBS 重複タスク Phase 2 修正 (= dedup v2 + UNIQUE INDEX 強制再作成 + cron audit)

**date**: 2026-05-08
**from**: Win Claude (= Win版#132 part 182)
**to**: Win Codex CLI
**priority**: high (= データ品質 / WBS UI 信頼性 / [WBS-SYNC] 影響)
**deadline**: 2026-05-22 (= 2 週間)
**rule basis**: `[WBS-DEDUP]` (= memory existing rule) + `[INSTANCE-ROLES]` (= SQL 修正 = Codex 担当)
**related issue**: [#2171](https://github.com/kanta13jp1/my_web_app/issues/2171)
**phase 1 reference**: [docs/cross-instance-prs/20260425_wbs_dedup_fix.md](20260425_wbs_dedup_fix.md) (PS#2 S29)

---

## 1. 問題報告 (= 2026-05-08 user 観測)

WBS UI (= <https://my-web-app-b67f4.web.app/project-gantt>) で「法人銀行口座開設」タスクが **14 件** 表示。
他 title でも重複の可能性あり。memory `[WBS-DEDUP]` (PS#2 S29 / 2026-04-25 発見) の Phase 1
修正 (= migration `20260426080000_wbs_deduplicate_tasks.sql` で dedup + UNIQUE INDEX 追加)
**だけでは止まっていない**。

### 観測実例 (= user screenshot)

| # | start_date | end_date | instance | category | task ID |
|---|---|---|---|---|---|
| 1 | 2026/6/15 | 2026/6/18 | codex | business-finance | `0f187477-...` |
| 2 | 2026/6/16 | 2026/6/19 | codex | business-finance | `2a720375-...` |
| 3 | 2026/6/18 | 2026/6/21 | user | business-finance | `3fb7b193-...` |
| 4 | 2026/6/18 | 2026/6/21 | codex | business-finance | `3ef43821-...` |
| ... | ... | ... | ... | ... | ... (= 計 14 件) |

全件 title=「法人銀行口座開設」 / category='business-finance' / progress=0 / status='pending'
/ priority='high' / milestone='legal-setup' / 担当 codex 13 件 + user 1 件。
start_date が 6/15 → 7/3 に分散 (= 日次増殖の痕跡)。

---

## 2. 根本原因 (= 3 段連鎖)

### Stage 1: seed migration の重複 INSERT (= Phase 1 で未対応)

**file**: [supabase/migrations/20260425170000_business_wbs_phase1.sql:142](../../supabase/migrations/20260425170000_business_wbs_phase1.sql#L142)

```sql
INSERT INTO public.wbs_tasks (...)
VALUES
  ('business-finance', '💰', 200, '法人銀行口座開設', '...', 'all', 'pending', 0,
   '2026-09-01', '2026-10-15', 'legal-setup', 'high', 'skip', 168),
  ...
ON CONFLICT DO NOTHING;
```

当時 `wbs_tasks` に `(title, instance)` UNIQUE 制約**なし** → `ON CONFLICT DO NOTHING` 効果なし。
`supabase db push` 再実行のたびに重複 INSERT。

### Stage 2: cartesian fan-out 増幅

**file**: [supabase/migrations/20260425203000_wbs_remove_all_instances_add_codex.sql:104-112](../../supabase/migrations/20260425203000_wbs_remove_all_instances_add_codex.sql#L104)

```sql
INSERT INTO public.wbs_tasks (...)
SELECT src.*, target_instances.instance, ...
FROM public.wbs_tasks src
CROSS JOIN target_instances  -- 13 instance
WHERE src.instance = 'all'
  AND NOT EXISTS (... WHERE existing.title = src.title AND existing.instance = target_instances.instance);
```

`NOT EXISTS` guard あるが、Stage 1 で `instance='all'` が**複数存在**する場合、
CROSS JOIN で各 'all' 行が 13 instance に展開され重複生成。

### Stage 3: Phase 1 dedup + UNIQUE INDEX (= 不完全)

**file**: [supabase/migrations/20260426080000_wbs_deduplicate_tasks.sql](../../supabase/migrations/20260426080000_wbs_deduplicate_tasks.sql)

```sql
DELETE FROM public.wbs_tasks
WHERE id NOT IN (
  SELECT DISTINCT ON (title, instance) id
  FROM public.wbs_tasks
  ORDER BY title, instance, created_at ASC
);

CREATE UNIQUE INDEX IF NOT EXISTS wbs_tasks_title_instance_unique
  ON public.wbs_tasks (title, instance);
```

Phase 1 修正は実行された**はず**だが、画面で codex 13 件存在 = 以下のいずれかが起きている:

- **仮説 A**: prod に UNIQUE INDEX が作成されていない (= migration 部分失敗 / 23505 で `CREATE UNIQUE INDEX` 失敗時に `IF NOT EXISTS` で skip された可能性)
- **仮説 B**: cron job (= `wbs-stale-subdivide` / `auto-subdivide` workflow) が同 title の子 task を増殖
- **仮説 C**: 後続 migration / EF が UNIQUE INDEX 回避経路で INSERT 続行
- **仮説 D**: Phase 1 dedup 実行**前**の重複が prod に存在 → Phase 1 で `CREATE UNIQUE INDEX` 失敗 (`IF NOT EXISTS` でも重複行があれば作成失敗) → 以降 INDEX 不在のまま

---

## 3. Phase 2 修正方針 (= 3 step / Codex 実装依頼)

### Step 1: 診断 SQL (= 本番状態確認 / migration 不要)

実行先: Supabase SQL Editor (prod) または `supabase db remote query`。

```sql
-- (1) UNIQUE INDEX 存在確認
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'wbs_tasks'
  AND indexname = 'wbs_tasks_title_instance_unique';
-- 期待: 1 row / 不在 = 仮説 A 確定

-- (2) 重複 (title, instance) 集計
SELECT title, instance, COUNT(*) AS cnt, array_agg(id) AS ids,
       array_agg(start_date ORDER BY start_date) AS start_dates
FROM public.wbs_tasks
WHERE status != 'completed'
GROUP BY title, instance
HAVING COUNT(*) > 1
ORDER BY cnt DESC, title
LIMIT 50;

-- (3) Issue # ベース二次重複集計 (= title 表現バリエーション検出 / Step 2.5 対象)
SELECT github_issue_number, instance, COUNT(*) AS cnt,
       array_agg(DISTINCT title ORDER BY title) AS title_variations,
       array_agg(id ORDER BY created_at) AS ids
FROM public.wbs_tasks
WHERE github_issue_number IS NOT NULL
GROUP BY github_issue_number, instance
HAVING COUNT(*) > 1
ORDER BY cnt DESC, github_issue_number
LIMIT 30;
-- 期待: ~20 ペア (= 観測例 #1282 / #1275 / #1373 / #1383 / #1316 / #1385 / #1409 等)

-- (4) 「法人銀行口座開設」全行 (= Step 2 対象の典型例 verify 用)
SELECT id, title, instance, owner_instance, status, progress,
       start_date, end_date, created_at, updated_at, parent_task_id
FROM public.wbs_tasks
WHERE title = '法人銀行口座開設'
ORDER BY created_at;

-- (5) auto-subdivided 行検出 (= parent_task_id 経由 / Step 3 audit 用)
SELECT parent_task_id, COUNT(*) AS subdivided
FROM public.wbs_tasks
WHERE parent_task_id IS NOT NULL
GROUP BY parent_task_id
HAVING COUNT(*) > 5
ORDER BY subdivided DESC
LIMIT 20;
```

### Step 2: dedup v2 migration (= idempotent / 仮説 A-D 全対応)

新規 migration: `supabase/migrations/20260522HHMMSS_wbs_dedup_v2_force_index.sql`

```sql
-- WBS dedup v2 (Phase 2): UNIQUE INDEX 強制再作成 + 全カテゴリ重複削除
-- 起票元: docs/cross-instance-prs/20260508_wbs_dedup_v2_phase2_codex.md
-- 仮説 A-D を網羅:
--   A. UNIQUE INDEX 不在 → DROP + 再 CREATE
--   B. cron auto-subdivide → 親リンク確認 + 重複親削除
--   C. 後続 INSERT → UNIQUE INDEX 復活で防止
--   D. Phase 1 失敗 → DELETE 先行で CREATE 成功保証

BEGIN;

-- ============================================================
-- Step 1: 既存 INDEX を一旦 DROP (= idempotent / 失敗時 rollback)
-- ============================================================
DROP INDEX IF EXISTS public.wbs_tasks_title_instance_unique;

-- ============================================================
-- Step 2: 重複削除 — DISTINCT ON (title, instance) の最古 created_at を keep
-- ============================================================
WITH ranked AS (
  SELECT id,
    ROW_NUMBER() OVER (
      PARTITION BY title, instance
      ORDER BY created_at ASC, id ASC
    ) AS rn,
    COUNT(*) OVER (PARTITION BY title, instance) AS dup_cnt
  FROM public.wbs_tasks
)
DELETE FROM public.wbs_tasks
WHERE id IN (
  SELECT id FROM ranked WHERE rn > 1
);

-- ============================================================
-- Step 2.5: Issue # ベース二次 dedup (= title 表現バリエーション吸収)
--   2026-05-08 user 第 3 報で発見 — 同 (github_issue_number, instance) で
--   title 文字列が複数バリエーション存在するパターン (= GitHub Issue → WBS sync が
--   「○○○ 由来の実行チェックリスト生成」「○○○ の運用レビュー・アラート」
--   「○○○ の知見カード化・横断検索導線」等 prefix 違いで複数 row 生成)。
--   Step 2 (= title, instance PARTITION) では title 文字列が違うため両方残る。
--   観測例: Issue #1282 / #1275 / #1373 / #1383 / #1316 / #1385 / #1409 等 計 ~20 ペア。
--
-- 残す優先度:
--   1. progress > 0 (= 進捗ある行を絶対 keep)
--   2. ai_review_status != 'pending' (= AI review 経た行優先)
--   3. LENGTH(title) DESC (= 詳細記述 = 後発で精度高い title 優先)
--   4. created_at ASC (= 同点なら最古 / Step 2 と整合)
-- ============================================================
WITH issue_ranked AS (
  SELECT id,
    ROW_NUMBER() OVER (
      PARTITION BY github_issue_number, instance
      ORDER BY
        CASE WHEN COALESCE(progress, 0) > 0 THEN 0 ELSE 1 END,
        CASE WHEN COALESCE(ai_review_status, 'pending') != 'pending' THEN 0 ELSE 1 END,
        LENGTH(title) DESC,
        created_at ASC,
        id ASC
    ) AS rn
  FROM public.wbs_tasks
  WHERE github_issue_number IS NOT NULL
)
DELETE FROM public.wbs_tasks
WHERE id IN (
  SELECT id FROM issue_ranked WHERE rn > 1
);

-- ============================================================
-- Step 3: UNIQUE INDEX (title, instance) 強制再作成
--   (= Step 1 で DROP 済み / 失敗時 migration 全体 rollback)
-- ============================================================
CREATE UNIQUE INDEX wbs_tasks_title_instance_unique
  ON public.wbs_tasks (title, instance);

-- ============================================================
-- Step 3.5: UNIQUE INDEX (github_issue_number, instance) 新規追加
--   (= Issue # 二次 dedup の再発防止)
--   注意: github_issue_number IS NULL の行 (= business-* 等 Issue 紐付けなし)
--         が複数あるため、partial index で NULL 除外。
-- ============================================================
CREATE UNIQUE INDEX wbs_tasks_issue_instance_unique
  ON public.wbs_tasks (github_issue_number, instance)
  WHERE github_issue_number IS NOT NULL;

-- ============================================================
-- Step 4: 削除件数を development_achievements に記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS dedup v2 (Phase 2 / Win Codex)',
  format(
    'WBS タスク重複 Phase 2 修正。Step 2 (title, instance) + Step 2.5 ' ||
    '(github_issue_number, instance) の二段 dedup。UNIQUE INDEX 2 種を ' ||
    'DROP → 削除 → 再作成 + Issue # 用 partial unique index 新規追加。' ||
    'Phase 1 (20260426080000) の不完全 dedup を補完 + GitHub Issue sync 由来の ' ||
    'title バリエーション重複も吸収。' ||
    '起票元: docs/cross-instance-prs/20260508_wbs_dedup_v2_phase2_codex.md'
  ),
  '2026-05-22'
)
ON CONFLICT DO NOTHING;

COMMIT;
```

**注意点 (= Codex 実装時)**:

- migration 名 timestamp は実投入日 JST に合わせる (= e.g. `20260520120000`)
- `BEGIN/COMMIT` で囲む (= `CREATE UNIQUE INDEX` 2 種いずれか失敗時 rollback)
- prod に並行 `db push` がいないこと確認 (= `supabase migration list --remote` で head 確認)
- 削除件数は migration 後に Step 1 (1) (2) (3) を再実行して 0 件確認 (= `(title, instance)` 重複 0 件 + `(github_issue_number, instance)` 重複 0 件)
- **Step 2.5 で削除されるのは title バリエーション違い行** — Step 2 で `(title, instance)` 完全一致重複削除後の残余に対して Issue # で二次 dedup する順序が重要 (= 入れ替え不可)
- Step 2.5 の `ORDER BY` 優先順 — `progress > 0` 優先で進捗ある行を絶対 keep (= データ消失防止)

### Step 3: cron 増殖元 audit (= 仮説 B 検証 / 別 commit)

`wbs-stale-subdivide` workflow / `wbs.subdivide_task` MCP / `auto_subdivided_at` 列を grep:

```bash
gh workflow list | grep -i wbs
grep -rn "auto_subdivided_at\|subdivide" .github/workflows/ scripts/ supabase/functions/
```

検証ポイント:

1. auto-subdivide が**親と同 title** の子 task を作っていないか (= INSERT 文の title 由来)
2. 子 task に `parent_task_id` が設定されているか (= 設定なし = 重複疑い)
3. UNIQUE INDEX 復活後に subdivide が SQLSTATE 23505 で fail する run があれば、subdivide ロジック修正が必要

issue は audit 結果で別途起票 (= 本 issue scope 外)。

---

## 4. Codex 振分 5-question 検証 (= [INSTANCE-ROLES] 準拠)

| # | 質問 | 答え |
|---|---|---|
| Q1 | 設計 / architect 要素を含むか | NO (= 修正済 spec の実装のみ) |
| Q2 | docs / memory 更新が主か | NO (= 本 cross-instance-pr が spec / 実装は SQL) |
| Q3 | UI design / mockup を含むか | NO |
| Q4 | AI 大学 / 競合 / mobile UAT / 動画 | NO |
| Q5 | triage / 5 質問 score 化 | NO (= 既に triage 済) |

→ **全 NO = Win Codex 担当** (= SQL migration 実装)。

---

## 5. 受け入れ条件 (= Codex DoD)

- [ ] Step 1 診断 SQL **5 種** (= (1) INDEX 存在 / (2) `(title, instance)` 重複 / (3) `(github_issue_number, instance)` 重複 / (4) 法人銀行口座開設 verify / (5) auto-subdivide 親) を Supabase prod で実行 → 結果を本 issue にコメント貼付
- [ ] Step 2 + 2.5 dedup v2 migration を `supabase/migrations/2026MMDDHHMMSS_wbs_dedup_v2_force_index.sql` で commit (= `BEGIN/COMMIT` 内で 2 段 dedup + UNIQUE INDEX 2 種再作成)
- [ ] PR title: `fix(wbs): dedup v2 + force unique index recreate (Phase 2 from cross-instance-pr 20260508)`
- [ ] PR description に Step 1 (1) (2) (3) の before/after 件数 (= e.g. `89 (title) + ~20 (issue#) dup combos / 700+ 余剰行 → 0 / 0 / 0`)
- [ ] `deploy-prod` workflow 成功確認後、UI で再度「法人銀行口座開設」が 1 件 + Issue #1282 等が 1 件 (= 仕様通り) になることを screenshot で確認
- [ ] Step 3 cron audit (= `wbs-stale-subdivide` workflow) は別 issue 起票 (= scope 外 / `[追加要望][P2]` 推奨)
- [ ] **データ保全 verify**: Step 2.5 で削除された行の中に `progress > 0` または `ai_review_status != 'pending'` の行が**含まれないこと**を CTE 結果でログ確認 (= migration コメントに `RAISE NOTICE` で件数出力推奨)

---

## 6. 関連 / 影響範囲

- **memory**: `[WBS-DEDUP]` (= inject-rules.txt) → Phase 2 完了後「修正済 (Phase 2)」追記推奨
- **WBS UI**: `/project-gantt` の総件数 (= 現 1000 件) が dedup 分減少
- **WBS API**: `wbs.priority_for_instance` (= 全 instance 毎セッション必須) の top 5 が真の優先順になる
- **影響なし**: GitHub Issues 同期 / 進捗計算 / マイルストーン risk view (= 重複 1 件分しか影響しない)

---

## 7. Phase 1 と Phase 2 の差分

| | Phase 1 (= 20260426080000) | Phase 2 (= 本 spec) |
|---|---|---|
| dedup 方式 | `DELETE WHERE id NOT IN (DISTINCT ON title, instance)` | 同じ + Step 2.5 `(github_issue_number, instance)` 二段 dedup + `BEGIN/COMMIT` で原子化 |
| UNIQUE INDEX | `(title, instance)` のみ / `CREATE IF NOT EXISTS` (= 既存重複時 skip 失敗の懸念) | `(title, instance)` + `(github_issue_number, instance) WHERE NOT NULL` 2 種 / `DROP → 重複削除 → CREATE` (= 強制再作成) |
| Issue # 重複対応 | なし (= title バリエーション違いの行が残存) | Step 2.5 で `progress > 0` 優先 keep + 詳細 title 優先で集約 |
| 検証 | なし | Step 1 診断 SQL 5 種 + before/after 件数 + データ保全 verify |
| cron audit | なし | Step 3 (= 別 issue 起票) |
| 推定削除件数 | ~582 行 | ~700-800 行 (= Phase 1 後の cron 増殖分 + Issue # 重複 ~20 ペア) |

---

> **承継**: Phase 2 完了後、Win Claude が本 spec を `archived: true` フラグで mark + memory `[WBS-DEDUP]`
> ルール文言を「修正済 (= 2026-05-22 Phase 2 / migration `2026MMDDHHMMSS_wbs_dedup_v2_force_index.sql`)」に更新する。

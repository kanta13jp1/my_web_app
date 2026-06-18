# cross-instance-pr: WBS に SDLC 7 工程軸 (phase) を追加

- **宛先**: L2 = VSCode + Codex (実装/SQL lane)
- **起票**: L3 = VSCode + Claude Code (Win Claude / part 240d / 2026-06-03)
- **優先度**: high
- **関連**: [`docs/AI_DRIVEN_DEV_OPERATING_MODEL.md`](../AI_DRIVEN_DEV_OPERATING_MODEL.md) §2 / [`project_gantt_page.dart`](../../lib/pages/project_gantt_page.dart)
- **pattern**: Architect-Implementer ③ (設計=L3 / 適用=L2)

## 背景 / なぜ

現 `wbs_tasks` は **8 機能カテゴリ**のみで、SDLC 工程軸（企画/設計/実装/テスト/リリース/運用/保守）が無い。user 要件 = 「企画から保守まで足りないタスクが一つもない」。→ `phase` 列を追加し、欠落工程に seed タスクを投入する。

スキーマ実体: `wbs_tasks` (NOT NULL = `category`,`title` / 既存列 `category`,`status`,`instance`,`priority`,`progress` 等 / [`20260417180000_create_wbs_tables.sql`](../../supabase/migrations/20260417180000_create_wbs_tables.sql))。

## 依頼内容 (= migration 1 本を author + 適用)

ファイル名: `supabase/migrations/20260603HHMMSS_wbs_add_sdlc_phase.sql`（HHMMSS は作成時刻 / [命名規約](../DEVELOPMENT_ACHIEVEMENTS_FORMAT.md)）。
additive + idempotent。下記をそのまま使用可:

```sql
-- WBS に SDLC 7 工程軸 (phase) を追加 + 各工程の欠落タスクを seed
-- 設計: Win Claude (part 240d / docs/AI_DRIVEN_DEV_OPERATING_MODEL.md §2) / 適用: Win Codex (L2)

-- 1) phase 列追加 (idempotent)
ALTER TABLE wbs_tasks ADD COLUMN IF NOT EXISTS phase text;
COMMENT ON COLUMN wbs_tasks.phase IS 'SDLC 工程: planning/design/impl/test/release/ops/maintenance (NULL=未分類)';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'wbs_tasks_phase_check') THEN
    ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_phase_check
      CHECK (phase IS NULL OR phase IN ('planning','design','impl','test','release','ops','maintenance'));
  END IF;
END $$;

-- 2) 既存タスクの phase backfill (category ヒューリスティック / NULL のみ上書き)
UPDATE wbs_tasks SET phase = 'ops'    WHERE phase IS NULL AND category LIKE '%インフラ%';
UPDATE wbs_tasks SET phase = 'design' WHERE phase IS NULL AND category LIKE '%デザイン%';
UPDATE wbs_tasks SET phase = 'test'   WHERE phase IS NULL AND category LIKE '%品質%';
UPDATE wbs_tasks SET phase = 'impl'   WHERE phase IS NULL AND category IN ('コアSaaS機能','AI統合','AI大学');
-- 残りは NULL のまま (手動分類対象)

-- 3) 各工程の欠落タスクを seed (idempotent: title NOT EXISTS guard)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, priority, phase)
SELECT v.category, v.category_icon, v.category_order, v.title, v.description, v.instance, v.status, v.priority, v.phase
FROM (VALUES
  ('企画・要件', '🧭', 10, '[企画] プロダクト要件定義書 (PRD) 整備',      'L1 Antigravity+Gemini で企画/要件を1枚化。ペルソナ・KPI・スコープ。', 'all', 'pending',     'high',   'planning'),
  ('企画・要件', '🧭', 10, '[企画] 四半期ロードマップ策定',                  '競合監視 digest を反映した次Qの WBS 優先順位。',                     'all', 'pending',     'medium', 'planning'),
  ('設計',       '📐', 11, '[設計] アーキ設計判断ログ運用 (ADR)',           'L3 で主要設計判断を ADR 化し NotebookLM 蓄積。',                      'win', 'pending',     'medium', 'design'),
  ('テスト',     '🧪', 14, '[テスト] E2E/結合テスト カバレッジ整備',        'L2 で主要導線の E2E。flutter test + integration。',                   'win', 'pending',     'high',   'test'),
  ('リリース',   '🚀', 15, '[リリース] リリースチェックリスト+ロールバック', 'deploy-prod gate / canary / rollback runbook。',                     'all', 'pending',     'high',   'release'),
  ('運用',       '🛠️', 16, '[運用] 本番監視+インシデント対応 runbook',      'cs-check/ci-cd-audit routine + incident-reports 運用。',              'all', 'in_progress', 'high',   'ops'),
  ('保守',       '♻️', 17, '[保守] 依存更新+技術的負債 棚卸し',             'dependabot/週次 vendor-digest 反映 + stale doc/コード削除。',         'all', 'pending',     'medium', 'maintenance')
) AS v(category, category_icon, category_order, title, description, instance, status, priority, phase)
WHERE NOT EXISTS (SELECT 1 FROM wbs_tasks w WHERE w.title = v.title);
```

## 受け入れ条件 (acceptance)

1. `supabase db push` が成功（additive / 既存データ破壊なし）。
2. `wbs_tasks.phase` 列が存在し、7 工程すべてに 1 件以上タスクが存在（`SELECT phase, count(*) FROM wbs_tasks GROUP BY phase`）。
3. 再適用（idempotent）でエラーnot・重複 insert not。
4. 任意: [`project_gantt_page.dart`](../../lib/pages/project_gantt_page.dart) に phase フィルタ/表示を追加（別タスク可 / L2+L3 協議）。

## 備考

- 列 backfill の category 文字列は seed 実値に合わせ微調整可（`SELECT DISTINCT category FROM wbs_tasks`)。
- gantt UI への phase 反映は scope 分離（本 handoff は schema+seed まで）。
- 完了時: 対応する WBS タスク（運用モデル整備）を `wbs.update_progress` で更新 + 本 file を `docs/cross-instance-prs/done/` へ移動。

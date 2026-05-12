-- WBS update — #974 SECOND_BRAIN ingest pipeline 完了 (Win版#132 part 111 / 2026-05-01)
--
-- Phase 6 自律 cycle 継続. 上から順 Win territory task #974 (= AI 第二の脳 Ingest).
-- nocheck: time-relative
-- Safe: this migration marks the touched WBS row completed, so
-- wbs_enforce_recovery_plan() returns before CURRENT_DATE checks run.
UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 111] scripts/memory_ingest.py 実装 (~200 行 / GitHub Issue / URL / stdin の 3 source / Atomic Note frontmatter / Obsidian 互換 [[link]] / SECOND_BRAIN #2 dogfood). 動作確認済 (= #1405 を test_ingest で frontmatter + body 出力).'
WHERE github_issue_number = 974;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[SECOND_BRAIN #2 dogfood] memory_ingest.py + Atomic Note convention',
  'CX',
  'win',
  'win',
  'medium',
  'completed',
  100,
  'Win版#132 part 111 で実装. WBS Issue #974 解決. GitHub Issue / URL / stdin から memory/ingest_YYYYMMDD_<slug>.md を生成 (= Atomic Note frontmatter付 / Obsidian 互換). 既存 memory/ infrastructure (= MEMORY.md + log.md + consolidate-memory --lint + knowledge_vault_lint.py) と統合.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[SECOND_BRAIN #2 dogfood] memory_ingest.py + Atomic Note convention'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 111: AI 第二の脳 Ingest pipeline 実装 (#974)',
  'Phase 6 自律 cycle 継続. scripts/memory_ingest.py 新規 (~200 行 / SECOND_BRAIN #2 + INDIE #1 dogfood). 3 source 対応 (= GitHub Issue / URL / stdin). Atomic Note frontmatter + Obsidian 互換 [[link]] convention. 既存 memory/ infrastructure (= MEMORY.md + log.md + knowledge_vault_lint.py) と統合. 動作確認: #1405 を ingest 成功.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 111: AI 第二の脳 Ingest pipeline 実装 (#974)'
);

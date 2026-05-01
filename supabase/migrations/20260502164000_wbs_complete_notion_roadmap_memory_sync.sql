-- WBS update: #1036/#1037 Notion ROADMAP + Memory sync actions complete
-- Codex #3 PowerShell / 2026-05-01
--
-- nocheck: time-relative
-- Safe: this migration marks the touched WBS rows completed, so
-- wbs_enforce_recovery_plan() returns before CURRENT_DATE checks run.

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Codex #3 PowerShell 2026-05-01] Implemented schedule-hub:notion.sync_roadmap. It appends recent development_achievements rows to the Notion ROADMAP page with an idempotency marker and runs from notion-sync.yml hourly cron.'
WHERE github_issue_number = 1036;

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Codex #3 PowerShell 2026-05-01] Implemented schedule-hub:notion.sync_memory_index. It upserts recent Supabase memory_index rows into the Notion Memory Index database by filename title and runs from notion-sync.yml hourly cron.'
WHERE github_issue_number = 1037;

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Codex #3: Notion ROADMAP + Memory Index sync implemented (#1036/#1037)',
  'Closed overdue WBS tasks #1036/#1037 at implementation level by adding schedule-hub actions notion.sync_roadmap and notion.sync_memory_index. The hourly Notion Mirror Sync workflow now calls WBS, ROADMAP, and Memory sync actions, using Notion as the Master Brain mirror while GitHub Actions keeps the flow automated.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Codex #3: Notion ROADMAP + Memory Index sync implemented (#1036/#1037)'
);

-- WBS update: #1287 Notion title collision guard and property wrappers complete
-- Codex #3 PowerShell / 2026-05-01
--
-- nocheck: time-relative
-- Safe: this migration marks the targeted WBS row completed, so
-- wbs_enforce_recovery_plan() returns before CURRENT_DATE checks run.

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Codex #3 PowerShell 2026-05-01] Implemented strict Notion property wrappers in schedule-hub. Title, rich_text, select, number, and date payloads are now built through helper functions, and rich_text property name title is rejected before calling the Notion API.'
WHERE id = '7d056fd3-2881-41d6-b237-dd6a75ac8d00';

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Codex #3: Notion property wrappers implemented (#1287)',
  'Added strict Notion property wrappers to schedule-hub and applied them to WBS and Memory Index sync. This prevents the title property collision class from recurring while keeping the Notion mirror workflow fully automated.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Codex #3: Notion property wrappers implemented (#1287)'
);

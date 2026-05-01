-- WBS update: #1321/#1288 checklist generation complete
-- Codex #3 PowerShell / 2026-05-02
--
-- nocheck: time-relative
-- Safe: this migration marks targeted WBS rows completed, so
-- wbs_enforce_recovery_plan() returns before CURRENT_DATE checks run.

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Codex #3 PowerShell 2026-05-02] Generated docs/task-checklists/notion_style_comments_flutter_supabase.md from the Flutter + Supabase Notion-style comments implementation notes. The checklist covers schema, RLS, Edge Function ownership checks, Flutter UI, and automation hooks.'
WHERE github_issue_number = 1321;

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Codex #3 PowerShell 2026-05-02] Generated docs/task-checklists/notion_database_ids_api_properties.md from the Notion database ID and API property setup material. The checklist covers ID extraction, secret handling, property schemas, strict API wrappers, and verification.'
WHERE github_issue_number = 1288;

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Codex #3: Notion checklist generation completed (#1321/#1288)',
  'Generated execution checklists for Notion-style comments and Notion database ID/API property handling, turning pending user-task knowledge into reusable repo-local automation guidance.',
  '2026-05-02'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Codex #3: Notion checklist generation completed (#1321/#1288)'
);

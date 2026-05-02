-- Codex #3 / 2026-05-02: advance Issue #1299 Notion WBS DB sync.
--
-- Implemented a fail-closed schema preflight for schedule-hub:notion.sync_wbs
-- so hourly sync no longer burns a full batch before discovering that the
-- Notion database is missing required properties.

UPDATE public.wbs_tasks
SET status = CASE
      WHEN status = 'completed' THEN status
      ELSE 'in_progress'
    END,
    progress = CASE
      WHEN status = 'completed' THEN progress
      ELSE GREATEST(COALESCE(progress, 0), 60)
    END,
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Notion WBS sync now has a schedule-hub schema preflight. Remaining user-side work: create/repair the Notion WBS DB properties reported by notion_schema_mismatch, then rerun notion-sync.yml.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-02] Hardened schedule-hub:notion.sync_wbs with a Notion DB schema preflight for id/title, task_title, instance, status, progress, deadline, and updated_at. notion-sync.yml now soft-fails with the exact missing/mismatched properties instead of creating repeated workflow-failure issues.'
WHERE github_issue_number = 1299
  AND title ILIKE '%Notion WBS%';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #3: Notion WBS sync schema preflight',
  'Added schedule-hub:notion.sync_wbs schema validation and notion-sync.yml handling for notion_schema_mismatch, reducing repeated manual triage and aligning WBS/Notion/NotebookLM automation.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;

-- Top PowerShell WBS item: BYPASS_RULES can be verified for existence only.
-- The PAT value and branch-protection bypass capability cannot be read back
-- from GitHub; final completion still needs a workflow smoke test with no GH006.
UPDATE public.wbs_tasks
SET status = CASE
      WHEN status = 'completed' THEN status
      ELSE 'in_progress'
    END,
    progress = CASE
      WHEN status = 'completed' THEN progress
      ELSE GREATEST(COALESCE(progress, 0), 95)
    END,
    recovery_plan = 'BYPASS_RULES exists in GitHub Actions secrets as of Codex #3 verification on 2026-05-02. Remaining: observe/trigger one protected-branch push workflow and rotate only if GH006 or permission errors recur.',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-02] Verified repository secret BYPASS_RULES exists with gh secret list. Secret values and bypass capability are not readable via GitHub API, so final proof remains workflow smoke-test only.'
WHERE title ILIKE '%BYPASS_RULES%';

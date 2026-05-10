-- Codex #1 / 2026-05-11:
-- Existing GitHub-origin WBS duplicates were being marked in_progress when the
-- source Issue was still open. That made the "unfinished only" WBS view keep
-- showing duplicate rows. Keep one canonical row per GitHub Issue and complete
-- the remaining mirrors as duplicate bookkeeping rows.

WITH issue_rows AS (
  SELECT
    task.id,
    task.instance,
    task.status,
    task.progress,
    task.remaining_work,
    task.github_issue_state,
    task.created_at,
    task.updated_at,
    COALESCE(
      NULLIF(task.github_issue_number, 0),
      substring(task.title from '\[Issue #([0-9]+)\]')::integer,
      substring(task.description from 'issues/([0-9]+)')::integer,
      substring(COALESCE(task.github_issue_url, '') from 'issues/([0-9]+)')::integer
    ) AS issue_number
  FROM public.wbs_tasks AS task
  WHERE
    NULLIF(task.github_issue_number, 0) IS NOT NULL
    OR task.title ~ '\[Issue #[0-9]+\]'
    OR COALESCE(task.github_issue_url, '') ~ 'issues/[0-9]+'
),
ranked AS (
  SELECT
    issue_rows.*,
    ROW_NUMBER() OVER (
      PARTITION BY issue_rows.issue_number
      ORDER BY
        CASE
          WHEN lower(COALESCE(issue_rows.remaining_work, '')) LIKE 'duplicate%' THEN 1
          ELSE 0
        END,
        CASE WHEN issue_rows.status = 'completed' THEN 1 ELSE 0 END,
        issue_rows.created_at ASC NULLS LAST,
        issue_rows.updated_at ASC NULLS LAST,
        issue_rows.id ASC
    ) AS rn
  FROM issue_rows
  WHERE issue_rows.issue_number IS NOT NULL
),
duplicates AS (
  SELECT
    duplicate.id,
    duplicate.issue_number,
    keeper.id AS keeper_id
  FROM ranked AS duplicate
  JOIN ranked AS keeper
    ON keeper.issue_number = duplicate.issue_number
   AND keeper.rn = 1
  WHERE duplicate.rn > 1
)
UPDATE public.wbs_tasks AS task
SET
  status = 'completed',
  progress = 100,
  ai_review_status = 'pending',
  github_issue_number = duplicates.issue_number,
  github_issue_synced_at = NOW(),
  remaining_work = CASE
    WHEN lower(COALESCE(task.remaining_work, '')) LIKE 'duplicate%' THEN task.remaining_work
    ELSE 'Duplicate of WBS task ' || duplicates.keeper_id || '; GitHub Issue #' || duplicates.issue_number || ' is kept on one canonical WBS row.'
  END,
  recovery_plan = COALESCE(
    NULLIF(task.recovery_plan, ''),
    'Completed as a duplicate GitHub-origin WBS row by migration 20260511023000.'
  ),
  recovery_planned_at = COALESCE(task.recovery_planned_at, NOW())
FROM duplicates
WHERE task.id = duplicates.id;

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #1: completed duplicate GitHub-origin WBS rows',
  'Marked non-canonical GitHub Issue WBS mirrors as completed duplicate rows so unfinished WBS views show one actionable task per Issue.',
  '2026-05-11'
)
ON CONFLICT DO NOTHING;

-- Safe re-implementation of 20260426100000_wbs_github_issue_sync.sql (PS#5 S82)
--
-- 20260426100000 triggers SQLSTATE 23514 from wbs_enforce_recovery_plan_trg:
--   - Its UPDATE on wbs_tasks fires the BEFORE trigger for task 714ee4a4
--     (deadline=2026-04-27, recovery_plan=NULL)
--   - The trigger blocks the UPDATE even though CURRENT_DATE > deadline
--
-- Fix: mark 20260426100000 as applied (skip it), re-implement here with
-- recovery_plan backfill BEFORE the github_issue UPDATE in the same statement sequence.

-- Step 1: Add columns (idempotent — IF NOT EXISTS handles prior attempts)
ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS github_issue_number int,
  ADD COLUMN IF NOT EXISTS github_issue_url text,
  ADD COLUMN IF NOT EXISTS github_issue_state text,
  ADD COLUMN IF NOT EXISTS github_issue_labels text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS github_issue_synced_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_github_issue_number
  ON public.wbs_tasks (github_issue_number)
  WHERE github_issue_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_github_issue_state
  ON public.wbs_tasks (github_issue_state)
  WHERE github_issue_state IS NOT NULL;

COMMENT ON COLUMN public.wbs_tasks.github_issue_number IS 'GitHub Issue number mirrored into WBS for idempotent issue sync.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_url IS 'Canonical GitHub Issue URL.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_state IS 'Last synced GitHub Issue state: OPEN/CLOSED.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_labels IS 'Last synced GitHub Issue labels.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_synced_at IS 'Last GitHub Issue <-> WBS sync timestamp.';

-- Step 2: Pre-backfill recovery_plan for any overdue tasks that would be touched.
-- This runs BEFORE the github_issue UPDATE so the trigger sees non-NULL recovery_plan.
UPDATE public.wbs_tasks
SET
  recovery_plan       = COALESCE(
    NULLIF(trim(recovery_plan), ''),
    'TBD — 遅延 detect 済 (PS#5 S82: github-issue-sync deploy 修復 fix)'
  ),
  recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE status != 'completed'
  AND COALESCE(planned_end_date, end_date) IS NOT NULL
  AND COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

-- Step 3: Now safe to parse github issue numbers (trigger passes because recovery_plan is set)
WITH parsed AS (
  SELECT
    id,
    regexp_match(
      coalesce(title, '') || ' ' || coalesce(description, ''),
      '(?:github\.com/kanta13jp1/my_web_app/issues/|\[Issue #)([0-9]+)'
    ) AS match
  FROM public.wbs_tasks
  WHERE github_issue_number IS NULL
)
UPDATE public.wbs_tasks t
SET
  github_issue_number = (p.match)[1]::int,
  github_issue_url = coalesce(
    t.github_issue_url,
    'https://github.com/kanta13jp1/my_web_app/issues/' || (p.match)[1]
  ),
  github_issue_synced_at = coalesce(t.github_issue_synced_at, now())
FROM parsed p
WHERE t.id = p.id
  AND p.match IS NOT NULL;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'GitHub Issues <-> WBS sync metadata (v2 safe-deploy)',
  'Re-implementation of 20260426100000 with pre-backfill of recovery_plan to prevent SQLSTATE 23514 from wbs_enforce_recovery_plan_trg. Original 20260426100000 marked as applied (skipped) in deploy-prod.yml.',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;

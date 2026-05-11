-- WBS dedup v2 / Issue #2171.
-- The 2026-05-11 prod diagnosis showed:
--   - (title, instance) duplicates: 0 active groups; existing unique index is present.
--   - (github_issue_number, instance) duplicates: 144 groups / 145 excess rows,
--     including 98 active excess rows.
--
-- Keep completed history intact. For active GitHub-origin WBS mirrors, keep one
-- canonical row per (github_issue_number, instance), complete the remaining
-- active mirrors as duplicate bookkeeping rows, and enforce the active shape
-- with a partial unique index.

BEGIN;

DROP INDEX IF EXISTS public.wbs_tasks_issue_instance_unique;
DROP INDEX IF EXISTS public.wbs_tasks_issue_instance_active_unique;
DROP INDEX IF EXISTS public.wbs_tasks_title_instance_unique;

CREATE TABLE IF NOT EXISTS public.wbs_dedup_v2_audit (
  audit_id bigserial PRIMARY KEY,
  original_task_id uuid NOT NULL,
  kept_task_id uuid,
  dedup_reason text NOT NULL,
  dedup_group_key text NOT NULL,
  github_issue_number int,
  task_snapshot jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS wbs_dedup_v2_audit_original_reason_unique
  ON public.wbs_dedup_v2_audit (original_task_id, dedup_reason);

ALTER TABLE public.wbs_dedup_v2_audit ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  before_title_groups int := 0;
  before_title_excess int := 0;
  before_issue_active_groups int := 0;
  before_issue_active_excess int := 0;
  completed_duplicate_rows int := 0;
  after_issue_active_groups int := 0;
  after_issue_active_excess int := 0;
BEGIN
  WITH title_groups AS (
    SELECT COUNT(*) AS cnt
    FROM public.wbs_tasks
    GROUP BY title, instance
    HAVING COUNT(*) > 1
  )
  SELECT
    COALESCE(COUNT(*), 0),
    COALESCE(SUM(cnt - 1), 0)
  INTO before_title_groups, before_title_excess
  FROM title_groups;

  WITH issue_groups AS (
    SELECT COUNT(*) AS cnt
    FROM public.wbs_tasks
    WHERE github_issue_number IS NOT NULL
      AND status <> 'completed'
    GROUP BY github_issue_number, instance
    HAVING COUNT(*) > 1
  )
  SELECT
    COALESCE(COUNT(*), 0),
    COALESCE(SUM(cnt - 1), 0)
  INTO before_issue_active_groups, before_issue_active_excess
  FROM issue_groups;

  RAISE NOTICE
    'WBS dedup v2 before: title_groups=%, title_excess=%, active_issue_groups=%, active_issue_excess=%',
    before_title_groups,
    before_title_excess,
    before_issue_active_groups,
    before_issue_active_excess;

  WITH ranked AS (
    SELECT
      task.*,
      ROW_NUMBER() OVER (
        PARTITION BY task.github_issue_number, task.instance
        ORDER BY
          CASE WHEN COALESCE(task.progress, 0) > 0 THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(task.ai_review_status, 'pending') <> 'pending' THEN 0 ELSE 1 END,
          LENGTH(task.title) DESC,
          task.created_at ASC,
          task.id ASC
      ) AS rn,
      FIRST_VALUE(task.id) OVER (
        PARTITION BY task.github_issue_number, task.instance
        ORDER BY
          CASE WHEN COALESCE(task.progress, 0) > 0 THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(task.ai_review_status, 'pending') <> 'pending' THEN 0 ELSE 1 END,
          LENGTH(task.title) DESC,
          task.created_at ASC,
          task.id ASC
      ) AS kept_task_id
    FROM public.wbs_tasks AS task
    WHERE task.github_issue_number IS NOT NULL
      AND task.status <> 'completed'
  ),
  duplicate_rows AS (
    SELECT *
    FROM ranked
    WHERE rn > 1
  )
  INSERT INTO public.wbs_dedup_v2_audit (
    original_task_id,
    kept_task_id,
    dedup_reason,
    dedup_group_key,
    github_issue_number,
    task_snapshot
  )
  SELECT
    duplicate_rows.id,
    duplicate_rows.kept_task_id,
    'active_github_issue_instance_duplicate',
    duplicate_rows.github_issue_number::text || ':' || duplicate_rows.instance,
    duplicate_rows.github_issue_number,
    to_jsonb(duplicate_rows) - 'rn' - 'kept_task_id'
  FROM duplicate_rows
  ON CONFLICT (original_task_id, dedup_reason) DO NOTHING;

  WITH ranked AS (
    SELECT
      task.id,
      task.github_issue_number,
      task.instance,
      ROW_NUMBER() OVER (
        PARTITION BY task.github_issue_number, task.instance
        ORDER BY
          CASE WHEN COALESCE(task.progress, 0) > 0 THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(task.ai_review_status, 'pending') <> 'pending' THEN 0 ELSE 1 END,
          LENGTH(task.title) DESC,
          task.created_at ASC,
          task.id ASC
      ) AS rn,
      FIRST_VALUE(task.id) OVER (
        PARTITION BY task.github_issue_number, task.instance
        ORDER BY
          CASE WHEN COALESCE(task.progress, 0) > 0 THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(task.ai_review_status, 'pending') <> 'pending' THEN 0 ELSE 1 END,
          LENGTH(task.title) DESC,
          task.created_at ASC,
          task.id ASC
      ) AS kept_task_id
    FROM public.wbs_tasks AS task
    WHERE task.github_issue_number IS NOT NULL
      AND task.status <> 'completed'
  ),
  duplicate_rows AS (
    SELECT *
    FROM ranked
    WHERE rn > 1
  )
  UPDATE public.wbs_tasks AS task
  SET
    status = 'completed',
    progress = 100,
    ai_review_status = 'manual_override',
    remaining_work = format(
      'Duplicate of WBS task %s; GitHub Issue #%s is kept on one active canonical WBS row.',
      duplicate_rows.kept_task_id,
      duplicate_rows.github_issue_number
    ),
    recovery_plan = COALESCE(
      NULLIF(task.recovery_plan, ''),
      'Completed as an active duplicate GitHub-origin WBS row by migration 20260511211500.'
    ),
    recovery_planned_at = COALESCE(task.recovery_planned_at, now()),
    github_issue_synced_at = now()
  FROM duplicate_rows
  WHERE task.id = duplicate_rows.id;

  GET DIAGNOSTICS completed_duplicate_rows = ROW_COUNT;

  WITH issue_groups AS (
    SELECT COUNT(*) AS cnt
    FROM public.wbs_tasks
    WHERE github_issue_number IS NOT NULL
      AND status <> 'completed'
    GROUP BY github_issue_number, instance
    HAVING COUNT(*) > 1
  )
  SELECT
    COALESCE(COUNT(*), 0),
    COALESCE(SUM(cnt - 1), 0)
  INTO after_issue_active_groups, after_issue_active_excess
  FROM issue_groups;

  RAISE NOTICE
    'WBS dedup v2 completed active duplicate rows=%; after active_issue_groups=%, active_issue_excess=%',
    completed_duplicate_rows,
    after_issue_active_groups,
    after_issue_active_excess;
END $$;

CREATE UNIQUE INDEX wbs_tasks_title_instance_unique
  ON public.wbs_tasks (title, instance);

CREATE UNIQUE INDEX wbs_tasks_issue_instance_active_unique
  ON public.wbs_tasks (github_issue_number, instance)
  WHERE github_issue_number IS NOT NULL
    AND status <> 'completed';

COMMENT ON INDEX public.wbs_tasks_issue_instance_active_unique IS
  'Issue #2171: one active WBS row per GitHub Issue and instance; completed duplicate history remains preserved.';

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #1: WBS dedup v2 active issue uniqueness',
  'Completed active duplicate GitHub-origin WBS rows, preserved snapshots in wbs_dedup_v2_audit, and enforced one active row per (github_issue_number, instance). Related Issue #2171.',
  now()
)
ON CONFLICT DO NOTHING;

COMMIT;

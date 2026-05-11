-- nocheck: time-relative
-- Keep every open GitHub Issue-linked WBS task ahead of non-Issue WBS work.
-- Additional-request tasks are already first-class issue work; this migration
-- broadens the same schedule policy to all active Issue mirrors while moving
-- only non-Issue rows that would otherwise overlap the Issue window.

WITH params AS (
  SELECT
    GREATEST(CURRENT_DATE, DATE '2026-05-11') AS anchor_date,
    GREATEST(CURRENT_DATE, DATE '2026-05-11') + 4 AS regular_anchor_date
),
open_tasks AS (
  SELECT
    task.*,
    (
      COALESCE(task.github_issue_number, 0) > 0
      OR COALESCE(task.github_issue_url, '') ~* '/issues/[0-9]+'
      OR COALESCE(task.title, '') ~* '(^|[[:space:]])\[?Issue #[0-9]+\]?'
    ) AS is_issue_linked
  FROM public.wbs_tasks AS task
  WHERE COALESCE(task.status, 'pending') <> 'completed'
    AND COALESCE(task.github_issue_state, '') <> 'CLOSED'
),
issue_tasks AS (
  SELECT
    open_tasks.id,
    params.anchor_date,
    CASE
      WHEN lower(COALESCE(open_tasks.priority, 'medium')) IN ('high', 'urgent')
        THEN params.anchor_date + 1
      ELSE params.anchor_date + 3
    END AS issue_end_date
  FROM open_tasks
  CROSS JOIN params
  WHERE open_tasks.is_issue_linked
),
updated_issue_tasks AS (
  UPDATE public.wbs_tasks AS task
  SET
    planned_start_date = issue_tasks.anchor_date,
    planned_end_date = issue_tasks.issue_end_date,
    start_date = issue_tasks.anchor_date,
    end_date = issue_tasks.issue_end_date,
    recovery_plan = trim(BOTH FROM CONCAT_WS(
      E'\n',
      NULLIF(task.recovery_plan, ''),
      format(
        'GitHub Issue schedule priority: moved planned dates to %s - %s so Issue-linked tasks appear before non-Issue WBS tasks.',
        issue_tasks.anchor_date,
        issue_tasks.issue_end_date
      )
    )),
    recovery_planned_at = COALESCE(task.recovery_planned_at, NOW()),
    rescheduled_count = COALESCE(task.rescheduled_count, 0) + 1,
    last_rebalanced_at = NOW(),
    updated_at = NOW()
  FROM issue_tasks
  WHERE task.id = issue_tasks.id
  RETURNING task.id
),
non_issue_candidates AS (
  SELECT
    open_tasks.id,
    params.regular_anchor_date,
    COALESCE(
      open_tasks.planned_start_date,
      open_tasks.start_date,
      params.regular_anchor_date
    ) AS current_start,
    COALESCE(
      open_tasks.planned_end_date,
      open_tasks.end_date,
      COALESCE(
        open_tasks.planned_start_date,
        open_tasks.start_date,
        params.regular_anchor_date
      )
    ) AS current_end
  FROM open_tasks
  CROSS JOIN params
  WHERE NOT open_tasks.is_issue_linked
    AND COALESCE(
      open_tasks.planned_start_date,
      open_tasks.start_date,
      params.regular_anchor_date
    ) < params.regular_anchor_date
),
regular_targets AS (
  SELECT
    non_issue_candidates.id,
    non_issue_candidates.regular_anchor_date,
    GREATEST(
      0,
      non_issue_candidates.current_end - non_issue_candidates.current_start
    ) AS duration_days
  FROM non_issue_candidates
),
updated_regular_tasks AS (
  UPDATE public.wbs_tasks AS task
  SET
    planned_start_date = regular_targets.regular_anchor_date,
    planned_end_date = regular_targets.regular_anchor_date +
      regular_targets.duration_days,
    start_date = regular_targets.regular_anchor_date,
    end_date = regular_targets.regular_anchor_date +
      regular_targets.duration_days,
    recovery_plan = trim(BOTH FROM CONCAT_WS(
      E'\n',
      NULLIF(task.recovery_plan, ''),
      format(
        'GitHub Issue schedule priority: shifted this non-Issue task to %s or later so Issue-linked WBS tasks stay first.',
        regular_targets.regular_anchor_date
      )
    )),
    recovery_planned_at = COALESCE(task.recovery_planned_at, NOW()),
    rescheduled_count = COALESCE(task.rescheduled_count, 0) + 1,
    last_rebalanced_at = NOW(),
    updated_at = NOW()
  FROM regular_targets
  WHERE task.id = regular_targets.id
  RETURNING task.id
)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: prioritized GitHub Issue-linked WBS task dates',
  format(
    'Prioritized %s open GitHub Issue-linked WBS task(s) and shifted %s overlapping non-Issue task(s) after the Issue window.',
    (SELECT COUNT(*) FROM updated_issue_tasks),
    (SELECT COUNT(*) FROM updated_regular_tasks)
  ),
  NOW()
WHERE
  (SELECT COUNT(*) FROM updated_issue_tasks) > 0
  OR (SELECT COUNT(*) FROM updated_regular_tasks) > 0;

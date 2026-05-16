-- nocheck: time-relative
-- Keep Home/GitHub additional-request WBS tasks ahead of regular work in the
-- project timeline.  The UI displays planned_* dates first, so this migration
-- front-loads existing open additional requests without rewriting completed
-- history.

WITH params AS (
  SELECT GREATEST(CURRENT_DATE, DATE '2026-05-11') AS anchor_date
),
feature_tasks AS (
  SELECT task.id
  FROM public.wbs_tasks AS task
  WHERE COALESCE(task.status, 'pending') <> 'completed'
    AND COALESCE(task.github_issue_state, '') <> 'CLOSED'
    AND (
      POSITION(U&'\8FFD\52A0\8981\671B' IN COALESCE(task.title, '')) > 0
      OR POSITION(U&'\8FFD\52A0\8981\671B' IN COALESCE(task.category, '')) > 0
    )
),
updated_feature_tasks AS (
  UPDATE public.wbs_tasks AS task
  SET
    planned_start_date = params.anchor_date,
    planned_end_date = params.anchor_date,
    start_date = CASE
      WHEN task.start_date IS NULL OR task.start_date > params.anchor_date
        THEN params.anchor_date
      ELSE task.start_date
    END,
    end_date = CASE
      WHEN task.end_date IS NULL OR task.end_date > params.anchor_date
        THEN params.anchor_date
      ELSE task.end_date
    END,
    recovery_plan = trim(BOTH FROM CONCAT_WS(
      E'\n',
      NULLIF(task.recovery_plan, ''),
      format(
        'Additional request schedule priority: moved planned dates to %s so additional requests appear before regular WBS tasks.',
        params.anchor_date
      )
    )),
    recovery_planned_at = COALESCE(task.recovery_planned_at, NOW()),
    rescheduled_count = COALESCE(task.rescheduled_count, 0) + 1,
    last_rebalanced_at = NOW(),
    updated_at = NOW()
  FROM params
  WHERE task.id IN (SELECT id FROM feature_tasks)
  RETURNING task.id
)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: prioritized additional-request WBS task dates',
  format(
    'Prioritized %s open additional-request WBS task(s) by moving planned dates ahead of regular tasks.',
    COUNT(*)
  ),
  NOW()
FROM updated_feature_tasks
HAVING COUNT(*) > 0;

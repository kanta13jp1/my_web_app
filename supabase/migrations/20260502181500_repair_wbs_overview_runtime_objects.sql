-- Repair WBS overview runtime objects for AI status reports.
--
-- The original 20260420190000 migration is recorded as applied in production,
-- but production was missing wbs_project_overview_view and
-- wbs_auto_repair_dependencies(). Keep this migration idempotent so deploys can
-- safely recreate the objects without depending on the old migration body.

CREATE OR REPLACE VIEW public.wbs_project_overview_view AS
WITH counts AS (
  SELECT
    COUNT(*)::integer AS total_tasks,
    COUNT(*) FILTER (WHERE status = 'completed')::integer AS done_tasks,
    COUNT(*) FILTER (WHERE status = 'in_progress')::integer AS in_progress_tasks,
    COUNT(*) FILTER (WHERE status = 'pending')::integer AS pending_tasks,
    COUNT(*) FILTER (WHERE status = 'blocked')::integer AS blocked_tasks,
    COUNT(*) FILTER (
      WHERE status != 'completed'
        AND end_date IS NOT NULL
        AND end_date < CURRENT_DATE
    )::integer AS overdue_tasks,
    COUNT(*) FILTER (
      WHERE status != 'completed'
        AND end_date IS NOT NULL
        AND end_date < CURRENT_DATE
        AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0)
    )::integer AS overdue_no_recovery,
    COUNT(DISTINCT instance) FILTER (
      WHERE COALESCE(instance, '') NOT IN ('', 'all')
    )::integer AS active_instances,
    ROUND(AVG(progress) FILTER (WHERE status = 'in_progress'))::integer AS avg_in_progress_pct
  FROM public.wbs_tasks
),
by_instance AS (
  SELECT
    COALESCE(NULLIF(instance, ''), 'unassigned') AS instance_key,
    COUNT(*)::integer AS instance_count
  FROM public.wbs_tasks
  GROUP BY COALESCE(NULLIF(instance, ''), 'unassigned')
)
SELECT
  counts.total_tasks,
  counts.done_tasks,
  counts.in_progress_tasks,
  counts.pending_tasks,
  counts.blocked_tasks,
  counts.overdue_tasks,
  counts.overdue_no_recovery,
  counts.active_instances,
  counts.avg_in_progress_pct,
  COALESCE(
    (SELECT jsonb_object_agg(instance_key, instance_count ORDER BY instance_key) FROM by_instance),
    '{}'::jsonb
  ) AS by_instance
FROM counts;

COMMENT ON VIEW public.wbs_project_overview_view IS
  'AI WBS status report snapshot: task counts, progress, overdue counts, and instance distribution.';

GRANT SELECT ON public.wbs_project_overview_view TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.wbs_auto_repair_dependencies()
RETURNS TABLE (
  task_id uuid,
  task_title text,
  old_start date,
  new_start date,
  trigger_dependency text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH dep_max AS (
    SELECT
      task.id,
      task.title,
      task.start_date AS old_start,
      MAX(dep.end_date) AS dep_end_max,
      array_agg(dep.title ORDER BY dep.end_date DESC) AS dep_titles
    FROM public.wbs_tasks task
    JOIN LATERAL unnest(COALESCE(task.depends_on, '{}'::uuid[])) AS dep_id ON TRUE
    JOIN public.wbs_tasks dep ON dep.id = dep_id
    WHERE task.status != 'completed'
      AND dep.end_date IS NOT NULL
    GROUP BY task.id, task.title, task.start_date
  )
  UPDATE public.wbs_tasks target
  SET
    start_date = dep_max.dep_end_max + 1,
    auto_recovery_applied = true,
    updated_at = now()
  FROM dep_max
  WHERE target.id = dep_max.id
    AND (target.start_date IS NULL OR target.start_date <= dep_max.dep_end_max)
  RETURNING
    dep_max.id,
    dep_max.title,
    dep_max.old_start,
    target.start_date,
    dep_max.dep_titles[1];
END;
$$;

COMMENT ON FUNCTION public.wbs_auto_repair_dependencies() IS
  'Moves WBS tasks after their latest dependency end date when dependency order is invalid.';

GRANT EXECUTE ON FUNCTION public.wbs_auto_repair_dependencies() TO authenticated, service_role;

-- Server-side lane aggregation RPC for Self-Devin Control Tower (#4092).
-- Replaces transferring ~88 kB of raw open wbs_tasks rows (including titles)
-- with 4 pre-aggregated numeric lane rows (~400 bytes).
-- SECURITY DEFINER returns aggregate counts only (zero raw titles/rows),
-- compatible with future lockdown of direct anon reads on wbs_tasks (#4083).

CREATE OR REPLACE FUNCTION public.get_self_devin_lane_summary(
  p_today date DEFAULT ((now() AT TIME ZONE 'Asia/Tokyo')::date),
  p_now timestamptz DEFAULT now()
)
RETURNS TABLE (
  lane_id text,
  active_tasks integer,
  blocked_tasks integer,
  overdue_tasks integer,
  stale_tasks integer,
  feature_request_tasks integer,
  high_priority_tasks integer,
  average_progress integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH canonical_lanes(lane_id, sort_order) AS (
    VALUES
      ('vscode', 1),
      ('web', 2),
      ('windows', 3),
      ('powershell', 4)
  ),
  normalized_open AS (
    SELECT
      CASE lower(trim(COALESCE(owner_instance, instance, '')))
        WHEN 'vscode' THEN 'vscode'
        WHEN 'web' THEN 'web'
        WHEN 'win' THEN 'windows'
        WHEN 'windows' THEN 'windows'
        WHEN 'powershell' THEN 'powershell'
        WHEN 'ps' THEN 'powershell'
        WHEN 'ps1' THEN 'powershell'
        WHEN 'ps2' THEN 'powershell'
        WHEN 'ps3' THEN 'powershell'
        WHEN 'ps4' THEN 'powershell'
        WHEN 'ps5' THEN 'powershell'
        WHEN 'ps6' THEN 'powershell'
        ELSE NULL
      END AS lane_id,
      status,
      COALESCE(progress, 0) AS progress,
      end_date,
      updated_at,
      category,
      COALESCE(title, '') AS title,
      priority
    FROM public.wbs_tasks
    WHERE status IS DISTINCT FROM 'completed'
  ),
  aggregated AS (
    SELECT
      lane_id,
      COUNT(*)::integer AS active_tasks,
      COUNT(*) FILTER (WHERE status = 'blocked')::integer AS blocked_tasks,
      COUNT(*) FILTER (
        WHERE end_date IS NOT NULL AND end_date < p_today
      )::integer AS overdue_tasks,
      COUNT(*) FILTER (
        WHERE updated_at IS NOT NULL
          AND updated_at <= p_now - interval '3 days'
      )::integer AS stale_tasks,
      COUNT(*) FILTER (
        WHERE category = 'ユーザー要望'
          OR left(title, char_length('[追加要望]')) = '[追加要望]'
      )::integer AS feature_request_tasks,
      COUNT(*) FILTER (WHERE priority = 'high')::integer AS high_priority_tasks,
      COALESCE(ROUND(AVG(progress)::numeric), 0)::integer AS average_progress
    FROM normalized_open
    WHERE lane_id IS NOT NULL
    GROUP BY lane_id
  )
  SELECT
    cl.lane_id,
    COALESCE(agg.active_tasks, 0)::integer AS active_tasks,
    COALESCE(agg.blocked_tasks, 0)::integer AS blocked_tasks,
    COALESCE(agg.overdue_tasks, 0)::integer AS overdue_tasks,
    COALESCE(agg.stale_tasks, 0)::integer AS stale_tasks,
    COALESCE(agg.feature_request_tasks, 0)::integer AS feature_request_tasks,
    COALESCE(agg.high_priority_tasks, 0)::integer AS high_priority_tasks,
    COALESCE(agg.average_progress, 0)::integer AS average_progress
  FROM canonical_lanes cl
  LEFT JOIN aggregated agg ON agg.lane_id = cl.lane_id
  ORDER BY cl.sort_order;
$$;

COMMENT ON FUNCTION public.get_self_devin_lane_summary(date, timestamptz) IS
  'Returns 4 canonical Self-Devin lane summary rows (counts & average progress only) for /admin Control Tower (#4092).';

REVOKE ALL ON FUNCTION public.get_self_devin_lane_summary(date, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_self_devin_lane_summary(date, timestamptz) TO anon, authenticated, service_role;

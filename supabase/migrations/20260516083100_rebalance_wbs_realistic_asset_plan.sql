-- nocheck: time-relative
-- Rebaseline active WBS work onto a realistic effort-based schedule.
--
-- Context captured on 2026-05-16 JST:
-- - 486 active WBS rows were open.
-- - 366 rows were planned for 2026-05-15 -> 2026-05-15.
-- - This migration estimates effort and spreads work by lane capacity so a
--   single day only contains work that can plausibly be completed.
-- - Asset-management roadmap Issues #2445-#2456 are pinned first because this
--   planning session explicitly prioritizes that feature stream.

WITH params AS (
  SELECT GREATEST(CURRENT_DATE, DATE '2026-05-16') AS anchor_date
),
asset_plan AS (
  SELECT *
  FROM (
    VALUES
      (2445, DATE '2026-05-16', DATE '2026-05-17', 2, 1),
      (2446, DATE '2026-05-18', DATE '2026-05-19', 2, 2),
      (2447, DATE '2026-05-20', DATE '2026-05-21', 2, 3),
      (2448, DATE '2026-05-22', DATE '2026-05-23', 2, 4),
      (2449, DATE '2026-05-24', DATE '2026-05-26', 3, 5),
      (2450, DATE '2026-05-27', DATE '2026-05-28', 2, 6),
      (2451, DATE '2026-05-29', DATE '2026-05-31', 3, 7),
      (2452, DATE '2026-06-01', DATE '2026-06-02', 2, 8),
      (2453, DATE '2026-06-03', DATE '2026-06-04', 2, 9),
      (2454, DATE '2026-06-05', DATE '2026-06-07', 3, 10),
      (2455, DATE '2026-06-08', DATE '2026-06-09', 2, 11),
      (2456, DATE '2026-06-10', DATE '2026-06-10', 1, 12)
  ) AS plan(issue_number, planned_start_date, planned_end_date, effort_days, plan_order)
),
active_tasks AS (
  SELECT
    task.*,
    plan.issue_number AS asset_issue_number,
    plan.planned_start_date AS asset_start_date,
    plan.planned_end_date AS asset_end_date,
    plan.effort_days AS asset_effort_days,
    plan.plan_order AS asset_plan_order,
    CASE
      WHEN lower(trim(COALESCE(NULLIF(task.owner_instance, ''), NULLIF(task.instance, ''), 'codex'))) IN
        ('codex', 'codex1', 'codex2', 'cx', 'ps2', 'ps5', 'ps6') THEN 'codex'
      WHEN lower(trim(COALESCE(NULLIF(task.owner_instance, ''), NULLIF(task.instance, ''), 'codex'))) IN
        ('claude', 'claude-code', 'win', 'windows', 'vscode', 'web', 'mobile', 'ps1', 'ps3', 'ps4') THEN 'claude'
      WHEN lower(trim(COALESCE(NULLIF(task.owner_instance, ''), NULLIF(task.instance, ''), 'codex'))) IN
        ('automation', 'auto', 'schedule', 'scheduled', 'gha', 'github-actions', 'gemini', 'co-pilot', 'copilot', 'github-copilot') THEN 'automation'
      WHEN lower(trim(COALESCE(NULLIF(task.owner_instance, ''), NULLIF(task.instance, ''), 'codex'))) IN
        ('user', 'usr', 'human') THEN 'user'
      ELSE 'codex'
    END AS lane
  FROM public.wbs_tasks AS task
  LEFT JOIN asset_plan AS plan
    ON plan.issue_number = task.github_issue_number
  WHERE COALESCE(task.status, 'pending') <> 'completed'
    AND COALESCE(task.github_issue_state, '') <> 'CLOSED'
),
non_asset_estimates AS (
  SELECT
    active_tasks.*,
    COALESCE(
      active_tasks.planned_end_date,
      active_tasks.end_date,
      DATE '2099-12-31'
    ) AS old_deadline,
    CASE active_tasks.status
      WHEN 'in_progress' THEN 0
      WHEN 'pending' THEN 1
      WHEN 'blocked' THEN 2
      ELSE 3
    END AS status_rank,
    CASE lower(COALESCE(active_tasks.priority, 'medium'))
      WHEN 'urgent' THEN 0
      WHEN 'high' THEN 1
      WHEN 'medium' THEN 2
      WHEN 'low' THEN 3
      ELSE 4
    END AS priority_rank,
    CASE
      WHEN active_tasks.status = 'in_progress' THEN
        GREATEST(
          1,
          LEAST(
            4,
            CEIL((100 - COALESCE(active_tasks.progress, 0)) / 30.0)::int
          )
        )
      WHEN lower(COALESCE(active_tasks.priority, 'medium')) IN ('urgent', 'high') THEN 2
      WHEN COALESCE(active_tasks.title, '') ~* '(EPIC|E2E|Supabase|AI|sync|workflow|migration|View|GA|MVP)' THEN 2
      WHEN COALESCE(active_tasks.title, '') ~ '(同期|全機能|技術的負債|自動化|実装|連携)' THEN 2
      ELSE 1
    END AS effort_points,
    CASE active_tasks.lane
      WHEN 'codex' THEN 2
      WHEN 'claude' THEN 1
      WHEN 'automation' THEN 4
      WHEN 'user' THEN 1
      ELSE 1
    END AS daily_capacity,
    CASE
      WHEN active_tasks.lane = 'codex' THEN DATE '2026-06-11'
      ELSE (SELECT anchor_date FROM params)
    END AS lane_anchor_date
  FROM active_tasks
  WHERE active_tasks.asset_issue_number IS NULL
),
ranked_non_asset AS (
  SELECT
    non_asset_estimates.*,
    SUM(non_asset_estimates.effort_points) OVER (
      PARTITION BY non_asset_estimates.lane
      ORDER BY
        non_asset_estimates.status_rank,
        non_asset_estimates.priority_rank,
        non_asset_estimates.old_deadline,
        non_asset_estimates.updated_at NULLS LAST,
        non_asset_estimates.title
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) - non_asset_estimates.effort_points AS effort_before,
    SUM(non_asset_estimates.effort_points) OVER (
      PARTITION BY non_asset_estimates.lane
      ORDER BY
        non_asset_estimates.status_rank,
        non_asset_estimates.priority_rank,
        non_asset_estimates.old_deadline,
        non_asset_estimates.updated_at NULLS LAST,
        non_asset_estimates.title
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS effort_through
  FROM non_asset_estimates
),
non_asset_schedule AS (
  SELECT
    id,
    lane,
    effort_points,
    (lane_anchor_date + FLOOR(effort_before::numeric / daily_capacity)::int)::date AS new_start_date,
    (
      lane_anchor_date +
      GREATEST(0, CEIL(effort_through::numeric / daily_capacity)::int - 1)
    )::date AS new_end_date
  FROM ranked_non_asset
),
asset_schedule AS (
  SELECT
    id,
    lane,
    asset_effort_days AS effort_points,
    asset_start_date AS new_start_date,
    asset_end_date AS new_end_date
  FROM active_tasks
  WHERE asset_issue_number IS NOT NULL
),
final_schedule AS (
  SELECT * FROM asset_schedule
  UNION ALL
  SELECT * FROM non_asset_schedule
),
updated_tasks AS (
  UPDATE public.wbs_tasks AS task
  SET
    planned_start_date = final_schedule.new_start_date,
    planned_end_date = final_schedule.new_end_date,
    recovery_plan = trim(BOTH FROM CONCAT_WS(
      E'\n',
      NULLIF(task.recovery_plan, ''),
      format(
        '2026-05-16 realistic WBS rebalance: estimated %s effort point(s), planned %s to %s. Active work is scheduled by lane capacity so one day only contains feasible work.',
        final_schedule.effort_points,
        final_schedule.new_start_date,
        final_schedule.new_end_date
      )
    )),
    recovery_planned_at = COALESCE(task.recovery_planned_at, NOW()),
    rescheduled_count = COALESCE(task.rescheduled_count, 0) + 1,
    last_rebalanced_at = NOW(),
    updated_at = NOW()
  FROM final_schedule
  WHERE task.id = final_schedule.id
  RETURNING
    task.id,
    task.github_issue_number,
    final_schedule.lane,
    final_schedule.effort_points,
    final_schedule.new_start_date,
    final_schedule.new_end_date
)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: realistic WBS schedule rebalance for asset-management roadmap',
  format(
    'Rebalanced %s active WBS task(s) by estimated effort and lane capacity. Pinned asset-management roadmap Issues #2445-#2456 from 2026-05-16 to 2026-06-10, then moved remaining Codex backlog after the focused plan.',
    COUNT(*)
  ),
  NOW()
FROM updated_tasks
HAVING COUNT(*) > 0;

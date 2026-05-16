-- nocheck: time-relative
-- Rebalance WBS after asset-management AI/model planning and GitHub Issue sync.
--
-- Context:
-- - Issue sync reintroduced many active rows planned for 2026-05-16 only.
-- - Asset-management work remains the priority stream.
-- - New Issues #2520-#2523 add official AI model benchmarking, provider
--   routing, model telemetry, and /goal wrap-up standardization.
-- - The schedule keeps Codex capacity at roughly 2 effort points per day.

WITH params AS (
  SELECT
    DATE '2026-05-16' AS anchor_date,
    DATE '2026-08-12' AS codex_backlog_resume_date
),
pinned_plan AS (
  SELECT *
  FROM (
    VALUES
      (2517, DATE '2026-05-16', DATE '2026-05-16', 1, 1),
      (2523, DATE '2026-05-16', DATE '2026-05-16', 1, 2),
      (2448, DATE '2026-05-17', DATE '2026-05-18', 2, 3),
      (2449, DATE '2026-05-19', DATE '2026-05-21', 3, 4),
      (2450, DATE '2026-05-22', DATE '2026-05-23', 2, 5),
      (2451, DATE '2026-05-24', DATE '2026-05-26', 3, 6),
      (2452, DATE '2026-05-27', DATE '2026-05-28', 2, 7),
      (2453, DATE '2026-05-29', DATE '2026-05-30', 2, 8),
      (2454, DATE '2026-05-31', DATE '2026-06-02', 3, 9),
      (2455, DATE '2026-06-03', DATE '2026-06-04', 2, 10),
      (2456, DATE '2026-06-05', DATE '2026-06-05', 1, 11),
      (2520, DATE '2026-06-06', DATE '2026-06-07', 2, 12),
      (2521, DATE '2026-06-08', DATE '2026-06-09', 2, 13),
      (2522, DATE '2026-06-10', DATE '2026-06-11', 2, 14),
      (2460, DATE '2026-06-12', DATE '2026-06-12', 1, 15),
      (2461, DATE '2026-06-13', DATE '2026-06-14', 2, 16),
      (2462, DATE '2026-06-15', DATE '2026-06-15', 1, 17),
      (2463, DATE '2026-06-16', DATE '2026-06-17', 2, 18),
      (2464, DATE '2026-06-18', DATE '2026-06-18', 1, 19),
      (2465, DATE '2026-06-19', DATE '2026-06-19', 1, 20),
      (2466, DATE '2026-06-20', DATE '2026-06-21', 2, 21),
      (2467, DATE '2026-06-22', DATE '2026-06-22', 1, 22),
      (2468, DATE '2026-06-23', DATE '2026-06-24', 2, 23),
      (2469, DATE '2026-06-25', DATE '2026-06-26', 2, 24),
      (2470, DATE '2026-06-27', DATE '2026-06-28', 2, 25),
      (2471, DATE '2026-06-29', DATE '2026-06-29', 1, 26),
      (2472, DATE '2026-06-30', DATE '2026-07-01', 2, 27),
      (2473, DATE '2026-07-02', DATE '2026-07-02', 1, 28),
      (2474, DATE '2026-07-03', DATE '2026-07-03', 1, 29),
      (2475, DATE '2026-07-04', DATE '2026-07-04', 1, 30),
      (2476, DATE '2026-07-05', DATE '2026-07-05', 1, 31),
      (2477, DATE '2026-07-06', DATE '2026-07-07', 2, 32),
      (2478, DATE '2026-07-08', DATE '2026-07-08', 1, 33),
      (2479, DATE '2026-07-09', DATE '2026-07-10', 2, 34),
      (2480, DATE '2026-07-11', DATE '2026-07-11', 1, 35),
      (2481, DATE '2026-07-12', DATE '2026-07-13', 2, 36),
      (2482, DATE '2026-07-14', DATE '2026-07-14', 1, 37),
      (2483, DATE '2026-07-15', DATE '2026-07-15', 1, 38),
      (2484, DATE '2026-07-16', DATE '2026-07-16', 1, 39),
      (2485, DATE '2026-07-17', DATE '2026-07-18', 2, 40),
      (2486, DATE '2026-07-19', DATE '2026-07-20', 2, 41),
      (2487, DATE '2026-07-21', DATE '2026-07-21', 1, 42),
      (2488, DATE '2026-07-22', DATE '2026-07-22', 1, 43),
      (2489, DATE '2026-07-23', DATE '2026-07-23', 1, 44),
      (2490, DATE '2026-07-24', DATE '2026-07-24', 1, 45),
      (2491, DATE '2026-07-25', DATE '2026-07-25', 1, 46),
      (2492, DATE '2026-07-26', DATE '2026-07-27', 2, 47),
      (2493, DATE '2026-07-28', DATE '2026-07-28', 1, 48),
      (2496, DATE '2026-07-29', DATE '2026-07-29', 1, 49),
      (2497, DATE '2026-07-30', DATE '2026-07-31', 2, 50),
      (2498, DATE '2026-08-01', DATE '2026-08-01', 1, 51),
      (2499, DATE '2026-08-02', DATE '2026-08-02', 1, 52),
      (2500, DATE '2026-08-03', DATE '2026-08-03', 1, 53),
      (2501, DATE '2026-08-04', DATE '2026-08-04', 1, 54),
      (2502, DATE '2026-08-05', DATE '2026-08-06', 2, 55),
      (2503, DATE '2026-08-07', DATE '2026-08-07', 1, 56),
      (2504, DATE '2026-08-08', DATE '2026-08-08', 1, 57),
      (2505, DATE '2026-08-09', DATE '2026-08-09', 1, 58),
      (2508, DATE '2026-08-10', DATE '2026-08-11', 2, 59)
  ) AS plan(issue_number, planned_start_date, planned_end_date, effort_points, plan_order)
),
active_tasks AS (
  SELECT
    task.*,
    pinned_plan.issue_number AS pinned_issue_number,
    pinned_plan.planned_start_date AS pinned_start_date,
    pinned_plan.planned_end_date AS pinned_end_date,
    pinned_plan.effort_points AS pinned_effort_points,
    pinned_plan.plan_order AS pinned_plan_order,
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
  LEFT JOIN pinned_plan
    ON pinned_plan.issue_number = task.github_issue_number
  WHERE COALESCE(task.status, 'pending') <> 'completed'
    AND COALESCE(task.github_issue_state, '') <> 'CLOSED'
),
non_pinned_estimates AS (
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
      WHEN 'critical' THEN 0
      WHEN 'high' THEN 1
      WHEN 'medium' THEN 2
      WHEN 'low' THEN 3
      ELSE 4
    END AS priority_rank,
    CASE
      WHEN active_tasks.status = 'in_progress' THEN
        GREATEST(1, LEAST(4, CEIL((100 - COALESCE(active_tasks.progress, 0)) / 30.0)::int))
      WHEN lower(COALESCE(active_tasks.priority, 'medium')) IN ('urgent', 'critical', 'high') THEN 2
      WHEN COALESCE(active_tasks.title, '') ~* '(EPIC|E2E|Supabase|AI|sync|workflow|migration|View|GA|MVP)' THEN 2
      ELSE 1
    END AS effort_points,
    CASE active_tasks.lane
      WHEN 'codex' THEN 2
      WHEN 'claude' THEN 1
      WHEN 'automation' THEN 4
      WHEN 'user' THEN 1
      ELSE 1
    END AS daily_capacity,
    CASE active_tasks.lane
      WHEN 'codex' THEN (SELECT codex_backlog_resume_date FROM params)
      ELSE (SELECT anchor_date FROM params)
    END AS lane_anchor_date
  FROM active_tasks
  WHERE active_tasks.pinned_issue_number IS NULL
),
ranked_non_pinned AS (
  SELECT
    non_pinned_estimates.*,
    SUM(non_pinned_estimates.effort_points) OVER (
      PARTITION BY non_pinned_estimates.lane
      ORDER BY
        non_pinned_estimates.status_rank,
        non_pinned_estimates.priority_rank,
        non_pinned_estimates.old_deadline,
        non_pinned_estimates.updated_at NULLS LAST,
        non_pinned_estimates.title
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) - non_pinned_estimates.effort_points AS effort_before,
    SUM(non_pinned_estimates.effort_points) OVER (
      PARTITION BY non_pinned_estimates.lane
      ORDER BY
        non_pinned_estimates.status_rank,
        non_pinned_estimates.priority_rank,
        non_pinned_estimates.old_deadline,
        non_pinned_estimates.updated_at NULLS LAST,
        non_pinned_estimates.title
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS effort_through
  FROM non_pinned_estimates
),
non_pinned_schedule AS (
  SELECT
    id,
    lane,
    effort_points,
    (lane_anchor_date + FLOOR(effort_before::numeric / daily_capacity)::int)::date AS new_start_date,
    (
      lane_anchor_date +
      GREATEST(0, CEIL(effort_through::numeric / daily_capacity)::int - 1)
    )::date AS new_end_date
  FROM ranked_non_pinned
),
pinned_schedule AS (
  SELECT
    id,
    lane,
    pinned_effort_points AS effort_points,
    pinned_start_date AS new_start_date,
    pinned_end_date AS new_end_date
  FROM active_tasks
  WHERE pinned_issue_number IS NOT NULL
),
final_schedule AS (
  SELECT * FROM pinned_schedule
  UNION ALL
  SELECT * FROM non_pinned_schedule
),
updated_tasks AS (
  UPDATE public.wbs_tasks AS task
  SET
    planned_start_date = final_schedule.new_start_date,
    planned_end_date = final_schedule.new_end_date,
    estimated_hours = final_schedule.effort_points * 4,
    recovery_plan = trim(BOTH FROM CONCAT_WS(
      E'\n',
      NULLIF(task.recovery_plan, ''),
      format(
        '2026-05-16 asset AI/model WBS rebalance: estimated %s effort point(s), planned %s to %s. Uses 2-instance routing and keeps one day within realistic capacity.',
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
  'Codex #1: asset-management WBS rebalance with AI model benchmark plan',
  format(
    'Rebalanced %s active WBS task(s). Pinned asset-management Issues #2448-#2456, #2460-#2505, #2508, #2517, and #2520-#2523 from 2026-05-16 to 2026-08-11; remaining Codex backlog resumes after the focused plan.',
    COUNT(*)
  ),
  NOW()
FROM updated_tasks
HAVING COUNT(*) > 0;

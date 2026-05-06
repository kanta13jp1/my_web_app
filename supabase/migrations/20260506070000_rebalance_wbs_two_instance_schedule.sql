-- Rebaseline WBS plans for the two-instance operating model.
--
-- start_date/end_date are kept as actual fields.  The project Gantt UI now
-- displays planned_start_date/planned_end_date when present, so this migration
-- moves every open task onto a realistic forward-looking schedule without
-- rewriting completed history.

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'claude', 'codex', 'codex1', 'codex2', 'cx', 'automation', 'auto', 'user', 'usr', 'human',
    'gemini', 'co-pilot', 'copilot',
    'vscode', 'win', 'windows',
    'ps', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile', 'schedule', 'scheduled', 'gha', 'github-actions', 'github-copilot', 'all'
  ));

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'claude', 'codex', 'codex1', 'codex2', 'cx', 'automation', 'auto', 'user', 'usr', 'human',
    'gemini', 'co-pilot', 'copilot',
    'vscode', 'win', 'windows',
    'ps', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile', 'schedule', 'scheduled', 'gha', 'github-actions', 'github-copilot', 'all'
  ));

WITH normalized AS (
  SELECT
    id,
    title,
    status,
    progress,
    priority,
    updated_at,
    COALESCE(planned_end_date, end_date, DATE '2099-12-31') AS old_deadline,
    GREATEST(CURRENT_DATE, DATE '2026-05-06') AS anchor_date,
    CASE
      WHEN lower(trim(COALESCE(NULLIF(owner_instance, ''), NULLIF(instance, ''), 'codex'))) IN
        ('codex', 'codex1', 'codex2', 'cx', 'ps2', 'ps5', 'ps6') THEN 'codex'
      WHEN lower(trim(COALESCE(NULLIF(owner_instance, ''), NULLIF(instance, ''), 'codex'))) IN
        ('claude', 'claude-code', 'win', 'windows', 'vscode', 'web', 'mobile', 'ps1', 'ps3', 'ps4') THEN 'claude'
      WHEN lower(trim(COALESCE(NULLIF(owner_instance, ''), NULLIF(instance, ''), 'codex'))) IN
        ('automation', 'auto', 'schedule', 'scheduled', 'gha', 'github-actions', 'gemini', 'co-pilot', 'copilot', 'github-copilot') THEN 'automation'
      WHEN lower(trim(COALESCE(NULLIF(owner_instance, ''), NULLIF(instance, ''), 'codex'))) IN
        ('user', 'usr', 'human') THEN 'user'
      ELSE 'codex'
    END AS lane,
    CASE status
      WHEN 'in_progress' THEN 0
      WHEN 'pending' THEN 1
      WHEN 'blocked' THEN 2
      ELSE 3
    END AS status_rank,
    CASE priority
      WHEN 'high' THEN 0
      WHEN 'medium' THEN 1
      WHEN 'low' THEN 2
      ELSE 3
    END AS priority_rank,
    CASE
      WHEN status = 'in_progress' THEN GREATEST(1, LEAST(3, CEIL((100 - COALESCE(progress, 0)) / 50.0)::int))
      WHEN priority = 'high' THEN 2
      ELSE 1
    END AS duration_days
  FROM public.wbs_tasks
  WHERE COALESCE(status, 'pending') <> 'completed'
    AND COALESCE(github_issue_state, '') <> 'CLOSED'
),
ranked AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY lane
      ORDER BY status_rank, priority_rank, old_deadline, updated_at NULLS LAST, title
    ) - 1 AS lane_index
  FROM normalized
),
scheduled AS (
  SELECT
    id,
    lane,
    old_deadline,
    anchor_date,
    duration_days,
    CASE lane
      WHEN 'claude' THEN 2
      WHEN 'codex' THEN 2
      WHEN 'automation' THEN 4
      WHEN 'user' THEN 1
      ELSE 2
    END AS daily_capacity,
    lane_index
  FROM ranked
),
final_schedule AS (
  SELECT
    id,
    lane,
    old_deadline,
    anchor_date,
    (anchor_date + floor(lane_index::numeric / daily_capacity)::int)::date AS new_start_date,
    (anchor_date + floor(lane_index::numeric / daily_capacity)::int + duration_days - 1)::date AS new_end_date
  FROM scheduled
)
UPDATE public.wbs_tasks AS task
SET
  planned_start_date = final_schedule.new_start_date,
  planned_end_date = final_schedule.new_end_date,
  owner_instance = final_schedule.lane,
  instance = final_schedule.lane,
  recovery_plan = CASE
    WHEN final_schedule.old_deadline < final_schedule.anchor_date THEN
      trim(BOTH FROM CONCAT_WS(
        E'\n',
        NULLIF(task.recovery_plan, ''),
        format(
          '%s: 2インスタンス制(Claude Code 1 / Codex 1)へ再計画。実行可能開始=%s、完了可能=%sへ更新。',
          to_char(final_schedule.anchor_date, 'YYYY-MM-DD'),
          final_schedule.new_start_date,
          final_schedule.new_end_date
        )
      ))
    ELSE task.recovery_plan
  END,
  recovery_planned_at = CASE
    WHEN final_schedule.old_deadline < final_schedule.anchor_date THEN now()
    ELSE task.recovery_planned_at
  END,
  rescheduled_count = COALESCE(task.rescheduled_count, 0) + 1,
  last_rebalanced_at = now(),
  updated_at = now()
FROM final_schedule
WHERE task.id = final_schedule.id;

-- WBS instance cleanup:
-- - Remove the shared "all" instance from active data and constraints.
-- - Split existing "all" tasks into per-instance copies so progress is visible by lane.
-- - Add "codex" as a first-class instance value.

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text,
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS depends_on uuid[] DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS depends_on_titles text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS auto_recovery_applied boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(6,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_planned_at timestamptz,
  ADD COLUMN IF NOT EXISTS rescheduled_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS planned_start_date date,
  ADD COLUMN IF NOT EXISTS planned_end_date date,
  ADD COLUMN IF NOT EXISTS parent_task_id uuid REFERENCES public.wbs_tasks(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ai_review_status text DEFAULT 'pending'
    CHECK (ai_review_status IN ('pending', 'approved', 'needs_split', 'needs_replan', 'skip')),
  ADD COLUMN IF NOT EXISTS ai_review_notes text,
  ADD COLUMN IF NOT EXISTS ai_reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS stale_threshold_hours int DEFAULT 24;

WITH target_instances(instance) AS (
  VALUES
    ('vscode'),
    ('win'),
    ('ps1'),
    ('ps2'),
    ('ps3'),
    ('ps4'),
    ('ps5'),
    ('ps6'),
    ('web'),
    ('mobile'),
    ('schedule'),
    ('gha')
)
INSERT INTO public.wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  created_at,
  updated_at,
  remaining_work,
  depends_on,
  depends_on_titles,
  auto_recovery_applied,
  estimated_hours,
  owner_instance,
  recovery_plan,
  recovery_planned_at,
  rescheduled_count,
  planned_start_date,
  planned_end_date,
  parent_task_id,
  ai_review_status,
  ai_review_notes,
  ai_reviewed_at,
  stale_threshold_hours
)
SELECT
  src.category,
  src.category_icon,
  src.category_order,
  src.title,
  src.description,
  target_instances.instance,
  src.status,
  src.progress,
  src.start_date,
  src.end_date,
  src.milestone_code,
  src.priority,
  src.created_at,
  src.updated_at,
  COALESCE(src.remaining_work, ''),
  COALESCE(src.depends_on, '{}'::uuid[]),
  COALESCE(src.depends_on_titles, '{}'::text[]),
  COALESCE(src.auto_recovery_applied, false),
  COALESCE(src.estimated_hours, 0),
  target_instances.instance,
  COALESCE(src.recovery_plan, ''),
  src.recovery_planned_at,
  COALESCE(src.rescheduled_count, 0),
  src.planned_start_date,
  src.planned_end_date,
  src.parent_task_id,
  COALESCE(src.ai_review_status, 'pending'),
  src.ai_review_notes,
  src.ai_reviewed_at,
  COALESCE(src.stale_threshold_hours, 24)
FROM public.wbs_tasks src
CROSS JOIN target_instances
WHERE src.instance = 'all'
  AND NOT EXISTS (
    SELECT 1
    FROM public.wbs_tasks existing
    WHERE existing.category = src.category
      AND existing.title = src.title
      AND existing.instance = target_instances.instance
  );

UPDATE public.wbs_tasks
SET instance = 'codex',
    owner_instance = 'codex'
WHERE instance = 'all';

UPDATE public.wbs_tasks
SET instance = 'win'
WHERE instance = 'windows';

UPDATE public.wbs_tasks
SET instance = 'ps1'
WHERE instance = 'ps';

-- Defensive WHERE: avoid touching rows with newer valid instance values
-- ('user'/'gemini'/'copilot' added in 20260425225000+ / 20260425230000) so that
-- this migration is idempotent on re-runs. Without this guard, UPDATE fires CHECK
-- on every touched row and fails when 170000's CHECK lacks the new values.
-- Fix: Win版#132 hotfix 2026-04-26.
UPDATE public.wbs_tasks
SET owner_instance = CASE
  WHEN owner_instance = 'windows' THEN 'win'
  WHEN owner_instance = 'ps' THEN 'ps1'
  WHEN owner_instance = 'all' THEN 'codex'
  WHEN owner_instance IS NULL THEN instance
  ELSE owner_instance
END
WHERE owner_instance IN ('windows', 'ps', 'all') OR owner_instance IS NULL;

UPDATE public.wbs_tasks
SET instance = 'codex'
WHERE instance NOT IN (
  'codex',
  'vscode', 'win',
  'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
  'web', 'mobile',
  'schedule', 'gha',
  -- Allow newer valid values (added by 225000/230000 migrations)
  'user', 'gemini', 'copilot'
);

UPDATE public.wbs_tasks
SET owner_instance = 'codex'
WHERE owner_instance NOT IN (
  'codex',
  'vscode', 'win',
  'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
  'web', 'mobile',
  'schedule', 'gha',
  -- Allow newer valid values
  'user', 'gemini', 'copilot'
);

ALTER TABLE public.wbs_tasks
  ALTER COLUMN instance SET DEFAULT 'codex',
  ALTER COLUMN owner_instance SET DEFAULT 'codex',
  ALTER COLUMN owner_instance SET NOT NULL;

-- CHECK 制約: 'user'/'gemini'/'copilot' を super-set に含める (idempotent / future-proof)
-- 後続の 230000 でも同じ super-set + 'user'/'gemini'/'copilot' で再設定される。
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'codex',
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'user', 'gemini', 'copilot'
  ));

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'codex',
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'user', 'gemini', 'copilot'
  ));

COMMENT ON COLUMN public.wbs_tasks.instance IS
  'Execution instance. The shared "all" value was removed on 2026-04-25; shared work is represented by per-instance task rows. Valid values: codex/vscode/win/ps1-ps6/web/mobile/schedule/gha.';

COMMENT ON COLUMN public.wbs_tasks.owner_instance IS
  'Primary owner instance. Valid values: codex/vscode/win/ps1-ps6/web/mobile/schedule/gha.';

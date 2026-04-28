-- PS#5 S83: Pre-push recovery_plan backfill (runs first in pending queue)
--
-- Root cause of SQLSTATE 23514 recurring failures:
--   20260425xxx migrations do broad UPDATE wbs_tasks SET instance=... which
--   fires wbs_enforce_recovery_plan_trg for task 714ee4a4 (deadline=2026-04-27,
--   recovery_plan=NULL). The 20260426090000 backfill migration has a LATER
--   timestamp, so it runs AFTER the trigger already fired and failed.
--
-- Fix: Place this backfill at 20260424225000 (before all pending 20260424234000+
--   migrations) so recovery_plan is always set before any UPDATE fires the trigger.

-- Step 1: Fix task 714ee4a4 unconditionally (it has deadline=2026-04-27, recovery_plan=NULL)
UPDATE public.wbs_tasks
SET
  recovery_plan       = COALESCE(
    NULLIF(trim(recovery_plan), ''),
    'TBD — 遅延 detect 済 (PS#5 S83: pre-push backfill / deadline 2026-04-27 超過)'
  ),
  recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE id = '714ee4a4-13c8-4161-9b78-de468660c3cf'
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

-- Step 2: Broader backfill — any other overdue tasks with NULL recovery_plan
UPDATE public.wbs_tasks
SET
  recovery_plan       = COALESCE(
    NULLIF(trim(recovery_plan), ''),
    'TBD — 遅延 detect 済 (PS#5 S83: pre-push backfill)'
  ),
  recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE status != 'completed'
  AND COALESCE(planned_end_date, end_date) IS NOT NULL
  AND COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S83: pre-push recovery_plan backfill (SQLSTATE 23514 永続修正)',
  '20260425xxx migrations の broad UPDATE wbs_tasks が 20260426090000 より先に実行されて '
  'trigger SQLSTATE 23514 を発火する根本原因を解消。20260424225000 に先行 backfill migration を配置。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;

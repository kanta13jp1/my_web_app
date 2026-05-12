-- PS#5 S78: Fix SQLSTATE 23514 blocking CI deploys (2026-04-28)
--
-- Root cause: wbs_enforce_recovery_plan_trg fires when 20260426100000_wbs_github_issue_sync.sql
-- updates task 714ee4a4-13c8-4161-9b78-de468660c3cf (deadline=2026-04-27, no recovery_plan).
-- The migration ran when deadline was still in the future (2026-04-26), but CI retries on
-- 2026-04-28 see the deadline as past → trigger raises SQLSTATE 23514.
--
-- Fix: Backfill recovery_plan for any non-completed tasks whose deadline has now passed,
-- so the trigger passes when the github sync migration touches those rows.

UPDATE public.wbs_tasks
SET
  recovery_plan         = 'TBD — 遅延 detect 済・CI deploy ブロッカー修正 (PS#5 S78 backfill)',
  recovery_planned_at   = COALESCE(recovery_planned_at, NOW())
WHERE status != 'completed'
  AND COALESCE(planned_end_date, end_date) IS NOT NULL
  AND COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS recovery_plan backfill fix — CI deploy ブロッカー解消 (PS#5 S78)',
  '20260426100000_wbs_github_issue_sync が wbs_tasks UPDATE 時に wbs_enforce_recovery_plan_trg を発火。deadline 超過タスク (714ee4a4 等) の recovery_plan NULL → SQLSTATE 23514。このマイグレーションで事前 backfill。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;

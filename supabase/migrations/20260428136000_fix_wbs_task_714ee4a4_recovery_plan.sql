-- PS#5 S82: 直接 fix — task 714ee4a4 の recovery_plan をセット
--
-- Root cause: 20260426090000 backfill は CURRENT_DATE < 2026-04-27 (作成日) のため
-- task 714ee4a4 (deadline=2026-04-27) をスキップ。20260426100000 が UPDATE 時に
-- wbs_enforce_recovery_plan_trg が発火 → SQLSTATE 23514。
-- 20260426090000 は applied 済みのため再実行されない → 今回 direct fix が必要。

UPDATE public.wbs_tasks
SET
  recovery_plan       = 'TBD — 遅延 detect 済 (PS#5 S82 direct fix: deadline 2026-04-27 超過)',
  recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE id = '714ee4a4-13c8-4161-9b78-de468660c3cf'
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

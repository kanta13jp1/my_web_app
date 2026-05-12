-- PS#5 S82: task 714ee4a4 recovery_plan 直接 fix (20260426100000 より前に実行)
--
-- 問題の経緯:
-- 20260426090000: CURRENT_DATE = 2026-04-26 → deadline=2026-04-27 は未来日 → スキップ
-- 20260426100000: wbs_tasks UPDATE → trigger → SQLSTATE 23514 (recovery_plan=NULL)
--
-- このファイルは 20260426090000 と 20260426100000 の間 (timestamp=20260426095000) に
-- 挿入することで、100000 の UPDATE より前に recovery_plan をセットする。

UPDATE public.wbs_tasks
SET
  recovery_plan       = 'TBD — 遅延 detect 済 (PS#5 S82: deadline 2026-04-27 超過を直接 fix)',
  recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE id = '714ee4a4-13c8-4161-9b78-de468660c3cf'
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

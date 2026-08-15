-- Revenue-first X growth hotfix:
-- production growth-hub was returning "Unknown action: x.trends" from the AI
-- share briefing flow. The Edge Function was redeployed with the local
-- x.trends implementation; keep WBS evidence tied to first-yen-revenue.

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 98),
  remaining_work =
    'Hotfix applied 2026-06-27: growth-hub was redeployed with x.trends after the live AI share dialog returned "Unknown action: x.trends". Remaining verification: retry the logged-in AI share briefing flow and confirm it enters trend-aware generation instead of the evergreen fallback.',
  recovery_plan =
    'If x.trends still fails, hard-refresh the hosted app, confirm the request is authenticated, then inspect Supabase growth-hub logs. Continue posting with the evergreen briefing fallback rather than stopping the 7-day 10K sprint.',
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND title = '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化'
  AND status <> 'completed';

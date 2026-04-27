-- Codex takeover: life-management AI operating loop.
--
-- User request:
-- - Take over an actually handled WBS item as Codex.
-- - Apply AI current-state analysis, KGI/CSF/KPI, periodic monitoring, and
--   improvement to all features while avoiding duplicated feature surfaces.
-- - In life management, prioritize eliminating waste of time, money, health,
--   stamina, intelligence, and focus.
--
-- Implementation evidence:
-- - Reused the existing FeatureStrategyMonitor and LifeWasteElimination
--   abstractions instead of adding a new duplicate dashboard.
-- - Added a daily operating directive to the life-waste report and UI so the
--   user sees one low-hurdle action, the no-expansion guardrail, and the daily
--   KGI/CSF/KPI monitoring loop.

DELETE FROM public.wbs_tasks
WHERE id = 'a4a5b0db-2e0b-401d-abc3-0c1c8d7154f0'::uuid
  AND instance = 'codex'
  AND owner_instance = 'codex'
  AND title LIKE '???AI%';

INSERT INTO public.wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  priority,
  remaining_work,
  ai_review_status,
  updated_at
)
VALUES (
  'AI Strategy',
  '🤖',
  15,
  '全機能AI連携・ライフ浪費ゼロ運用ループ',
  'Codex担当。既存の全機能AI戦略モニタとライフ浪費ゼロ司令塔を活かし、今日の1手・拡張しない条件・毎日のKGI/CSF/KPI再計算をUIに接続した。',
  'codex',
  'codex',
  'completed',
  100,
  DATE '2026-04-27',
  DATE '2026-04-27',
  'high',
  'Completed by Codex on 2026-04-27. No duplicated feature surface was added; the existing cross-feature monitor and life-waste service now expose the daily operating loop.',
  'approved',
  now()
)
ON CONFLICT (title, instance) DO UPDATE
SET
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  end_date = DATE '2026-04-27',
  priority = 'high',
  remaining_work = EXCLUDED.remaining_work,
  ai_review_status = 'approved',
  description = EXCLUDED.description,
  updated_at = now();

INSERT INTO public.development_achievements (
  title,
  description,
  completed_at
)
VALUES (
  'Codex: life-management AI operating loop',
  'Added a daily operating directive to LifeWasteElimination so the site turns AI analysis, KGI/CSF/KPI, monitoring, and improvement into one low-hurdle action while keeping other life-capital tasks parked until stable.',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;

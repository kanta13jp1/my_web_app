-- Codex takeover: life-capital representative feature lanes.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: group all monitored
-- features by life-capital resource and assign one representative lane per
-- resource so similar functions can be treated as aliases/sub-routes instead
-- of competing entry points.

ALTER TABLE IF EXISTS public.feature_strategy_daily_snapshots
  ADD COLUMN IF NOT EXISTS life_capital_lane_count integer NOT NULL DEFAULT 0
    CHECK (life_capital_lane_count >= 0),
  ADD COLUMN IF NOT EXISTS life_capital_lane_waste_minutes_saved integer
    NOT NULL DEFAULT 0
    CHECK (life_capital_lane_waste_minutes_saved >= 0);

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS estimated_hours numeric DEFAULT 0;

INSERT INTO wbs_tasks (
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
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'AI統合',
  '🤖',
  3,
  '全機能生命資本別 代表導線レーン',
  '時間・お金・健康・体力・知能・集中力ごとに代表機能を1つ決め、類似機能をサブ導線として束ねる。代表レーン数と導線迷い削減見込みをKGI/CSF/KPI、AIレビュー、日次スナップショットへ反映する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added life-capital representative lanes, portfolio KPIs, AI review prompt context, Home UI, snapshot persistence fields, and regression tests.',
  'Next: connect representative lanes to a central feature registry so duplicate navigation entries can be hidden or redirected after human review.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本別 代表導線レーン'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本別 代表導線レーン',
  'Codex grouped all monitored features by time, money, health, stamina, intelligence, and focus, assigned representative feature lanes, and fed lane KPIs into AI review and daily snapshots.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;

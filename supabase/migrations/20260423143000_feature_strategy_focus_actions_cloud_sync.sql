-- Codex takeover: feature strategy focus-action cloud sync.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: persist the all-feature
-- low-hurdle action completion/defer loop so KGI/CSF/KPI monitoring can
-- continue across devices and feed regular review decisions.

CREATE TABLE IF NOT EXISTS public.feature_strategy_focus_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_id text NOT NULL,
  action_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'completed', 'deferred')
  ),
  completed_at timestamptz,
  deferred_at timestamptz,
  completion_streak_days integer NOT NULL DEFAULT 0 CHECK (
    completion_streak_days >= 0
  ),
  life_capital_resource text NOT NULL DEFAULT 'time',
  feature_name text NOT NULL DEFAULT '',
  section_name text NOT NULL DEFAULT '',
  csf text NOT NULL DEFAULT '',
  kpi text NOT NULL DEFAULT '',
  action text NOT NULL DEFAULT '',
  monitoring_cadence text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, feature_id, action_date)
);

CREATE INDEX IF NOT EXISTS idx_feature_strategy_focus_actions_user_date
  ON public.feature_strategy_focus_actions(user_id, action_date DESC);

CREATE INDEX IF NOT EXISTS idx_feature_strategy_focus_actions_resource_date
  ON public.feature_strategy_focus_actions(
    user_id,
    life_capital_resource,
    action_date DESC
  );

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_feature_strategy_focus_actions_updated_at
  ON public.feature_strategy_focus_actions;
CREATE TRIGGER update_feature_strategy_focus_actions_updated_at
  BEFORE UPDATE ON public.feature_strategy_focus_actions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.feature_strategy_focus_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feature_strategy_focus_actions_select_own
  ON public.feature_strategy_focus_actions;
CREATE POLICY feature_strategy_focus_actions_select_own
  ON public.feature_strategy_focus_actions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_focus_actions_insert_own
  ON public.feature_strategy_focus_actions;
CREATE POLICY feature_strategy_focus_actions_insert_own
  ON public.feature_strategy_focus_actions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_focus_actions_update_own
  ON public.feature_strategy_focus_actions;
CREATE POLICY feature_strategy_focus_actions_update_own
  ON public.feature_strategy_focus_actions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_focus_actions_delete_own
  ON public.feature_strategy_focus_actions;
CREATE POLICY feature_strategy_focus_actions_delete_own
  ON public.feature_strategy_focus_actions
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

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
  'AI Integration',
  'AI',
  3,
  'Feature focus action Supabase sync',
  'Persist the all-feature low-hurdle action completion/defer loop to Supabase so AI current-state analysis, KGI, CSF, KPI, review cadence, and life-capital waste-reduction decisions continue across devices.',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a feature_strategy_focus_actions table, RLS policies, repository abstraction, Home integration, cloud/local merge behavior, sync status UI, and regression tests.',
  'Next: use synced focus outcomes for cross-device review cadence and life-capital cohort analytics.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'Feature focus action Supabase sync'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Feature focus action Supabase sync',
  'Codex persisted all-feature low-hurdle action outcomes to Supabase and merged cloud history back into the AI/KGI/CSF/KPI monitor so life-capital waste-reduction loops continue across devices.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;

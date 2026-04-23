-- Codex takeover: all-feature AI strategy daily snapshots.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: persist all-feature
-- AI/KGI/CSF/KPI monitoring summaries so review cadence, similar-feature
-- consolidation, and life-capital waste-reduction trends survive refreshes
-- and cross-device use.

CREATE TABLE IF NOT EXISTS public.feature_strategy_daily_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  snapshot_date date NOT NULL,
  monitored_at timestamptz NOT NULL DEFAULT now(),
  total_features integer NOT NULL DEFAULT 0 CHECK (total_features >= 0),
  on_track_count integer NOT NULL DEFAULT 0 CHECK (on_track_count >= 0),
  watch_count integer NOT NULL DEFAULT 0 CHECK (watch_count >= 0),
  improve_count integer NOT NULL DEFAULT 0 CHECK (improve_count >= 0),
  portfolio_progress_percent integer NOT NULL DEFAULT 0 CHECK (
    portfolio_progress_percent >= 0 AND portfolio_progress_percent <= 100
  ),
  ai_coverage_percent integer NOT NULL DEFAULT 0 CHECK (
    ai_coverage_percent >= 0 AND ai_coverage_percent <= 100
  ),
  life_capital_coverage_percent integer NOT NULL DEFAULT 0 CHECK (
    life_capital_coverage_percent >= 0
    AND life_capital_coverage_percent <= 100
  ),
  review_due_count integer NOT NULL DEFAULT 0 CHECK (review_due_count >= 0),
  review_overdue_count integer NOT NULL DEFAULT 0 CHECK (
    review_overdue_count >= 0
  ),
  review_cadence_compliance_percent integer NOT NULL DEFAULT 0 CHECK (
    review_cadence_compliance_percent >= 0
    AND review_cadence_compliance_percent <= 100
  ),
  consolidation_count integer NOT NULL DEFAULT 0 CHECK (
    consolidation_count >= 0
  ),
  consolidation_waste_minutes_saved integer NOT NULL DEFAULT 0 CHECK (
    consolidation_waste_minutes_saved >= 0
  ),
  high_waste_reduction_count integer NOT NULL DEFAULT 0 CHECK (
    high_waste_reduction_count >= 0
  ),
  focus_feature_id text NOT NULL DEFAULT '',
  focus_resource text NOT NULL DEFAULT '',
  focus_completed_days_last7 integer NOT NULL DEFAULT 0 CHECK (
    focus_completed_days_last7 >= 0
  ),
  focus_deferred_days_last7 integer NOT NULL DEFAULT 0 CHECK (
    focus_deferred_days_last7 >= 0
  ),
  focus_streak_days integer NOT NULL DEFAULT 0 CHECK (
    focus_streak_days >= 0
  ),
  focus_habit_stable boolean NOT NULL DEFAULT false,
  priority_feature_ids text[] NOT NULL DEFAULT '{}'::text[],
  review_due_feature_ids text[] NOT NULL DEFAULT '{}'::text[],
  life_capital_scores jsonb NOT NULL DEFAULT '{}'::jsonb,
  next_action text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_feature_strategy_daily_snapshots_user_date
  ON public.feature_strategy_daily_snapshots(user_id, snapshot_date DESC);

CREATE INDEX IF NOT EXISTS idx_feature_strategy_daily_snapshots_review
  ON public.feature_strategy_daily_snapshots(
    user_id,
    review_overdue_count,
    snapshot_date DESC
  );

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_feature_strategy_daily_snapshots_updated_at
  ON public.feature_strategy_daily_snapshots;
CREATE TRIGGER update_feature_strategy_daily_snapshots_updated_at
  BEFORE UPDATE ON public.feature_strategy_daily_snapshots
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.feature_strategy_daily_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feature_strategy_daily_snapshots_select_own
  ON public.feature_strategy_daily_snapshots;
CREATE POLICY feature_strategy_daily_snapshots_select_own
  ON public.feature_strategy_daily_snapshots
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_daily_snapshots_insert_own
  ON public.feature_strategy_daily_snapshots;
CREATE POLICY feature_strategy_daily_snapshots_insert_own
  ON public.feature_strategy_daily_snapshots
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_daily_snapshots_update_own
  ON public.feature_strategy_daily_snapshots;
CREATE POLICY feature_strategy_daily_snapshots_update_own
  ON public.feature_strategy_daily_snapshots
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS feature_strategy_daily_snapshots_delete_own
  ON public.feature_strategy_daily_snapshots;
CREATE POLICY feature_strategy_daily_snapshots_delete_own
  ON public.feature_strategy_daily_snapshots
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
  'All-feature strategy daily snapshots',
  'Persist all-feature AI current-state analysis, KGI, CSF, KPI, review cadence, similar-feature consolidation, and life-capital waste-reduction trend metrics to Supabase with local fallback.',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added feature_strategy_daily_snapshots, RLS policies, a local/Supabase snapshot service, Home integration, monitoring-history UI, and regression tests.',
  'Next: use accumulated snapshots for weekly AI trend summaries and automatic consolidation rollout decisions.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'All-feature strategy daily snapshots'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'All-feature strategy daily snapshots',
  'Codex persisted all-feature AI/KGI/CSF/KPI monitoring summaries so review cadence, consolidation, and life-capital waste-reduction trend data survives refreshes and cross-device use.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;

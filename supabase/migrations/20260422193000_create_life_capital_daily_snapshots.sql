-- Persist life-capital monitoring snapshots per authenticated user.
-- 2026-04-22

CREATE TABLE IF NOT EXISTS public.life_capital_daily_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  snapshot_date date NOT NULL,
  monitored_at timestamptz NOT NULL DEFAULT now(),
  waste_free_score integer NOT NULL CHECK (
    waste_free_score >= 0 AND waste_free_score <= 100
  ),
  resource_scores jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority_resource text NOT NULL DEFAULT 'focus',
  next_action text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_life_capital_daily_snapshots_user_date
  ON public.life_capital_daily_snapshots(user_id, snapshot_date DESC);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_life_capital_daily_snapshots_updated_at
  ON public.life_capital_daily_snapshots;
CREATE TRIGGER update_life_capital_daily_snapshots_updated_at
  BEFORE UPDATE ON public.life_capital_daily_snapshots
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.life_capital_daily_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS life_capital_daily_snapshots_select_own
  ON public.life_capital_daily_snapshots;
CREATE POLICY life_capital_daily_snapshots_select_own
  ON public.life_capital_daily_snapshots
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS life_capital_daily_snapshots_insert_own
  ON public.life_capital_daily_snapshots;
CREATE POLICY life_capital_daily_snapshots_insert_own
  ON public.life_capital_daily_snapshots
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS life_capital_daily_snapshots_update_own
  ON public.life_capital_daily_snapshots;
CREATE POLICY life_capital_daily_snapshots_update_own
  ON public.life_capital_daily_snapshots
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS life_capital_daily_snapshots_delete_own
  ON public.life_capital_daily_snapshots;
CREATE POLICY life_capital_daily_snapshots_delete_own
  ON public.life_capital_daily_snapshots
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

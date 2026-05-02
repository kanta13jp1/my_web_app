CREATE TABLE IF NOT EXISTS public.mental_health_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mood_score integer NOT NULL DEFAULT 3,
  stress_score integer NOT NULL DEFAULT 3,
  sleep_hours numeric NOT NULL DEFAULT 7,
  note text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mental_health_records
  ADD COLUMN IF NOT EXISTS analysis_report jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ai_summary text,
  ADD COLUMN IF NOT EXISTS emotion_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS trigger_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS next_actions text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS risk_level text NOT NULL DEFAULT 'low',
  ADD COLUMN IF NOT EXISTS focus_area text NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS ai_model text,
  ADD COLUMN IF NOT EXISTS analyzed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_mental_health_records_user_recorded
  ON public.mental_health_records (user_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_mental_health_records_analyzed
  ON public.mental_health_records (user_id, analyzed_at DESC NULLS LAST);

ALTER TABLE public.mental_health_records ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY "mental_health_records_select_own"
    ON public.mental_health_records
    FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "mental_health_records_insert_own"
    ON public.mental_health_records
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "mental_health_records_update_own"
    ON public.mental_health_records
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "mental_health_records_delete_own"
    ON public.mental_health_records
    FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE public.mental_health_records IS
  'Daily mood and diary records with AI-generated feedback and next-day actions.';

-- Issue #1124 Phase 1: AI executive GPA evaluations.
-- Stores only compact evaluation metadata; raw prompts/responses stay in source logs.

CREATE TABLE IF NOT EXISTS public.agent_gpa_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (
    source_type IN ('executive_chat', 'executive_meeting', 'secretary_action')
  ),
  source_id uuid NOT NULL,
  goal_score numeric(3, 1) NOT NULL CHECK (goal_score BETWEEN 0 AND 4),
  plan_score numeric(3, 1) NOT NULL CHECK (plan_score BETWEEN 0 AND 4),
  action_score numeric(3, 1) NOT NULL CHECK (action_score BETWEEN 0 AND 4),
  consistency_score numeric(3, 1) NOT NULL CHECK (
    consistency_score BETWEEN 0 AND 4
  ),
  gpa numeric(3, 2) GENERATED ALWAYS AS (
    (goal_score + plan_score + action_score + consistency_score) / 4
  ) STORED,
  judge_model text NOT NULL DEFAULT 'claude-sonnet-4-6',
  rationale_short text,
  improvement_suggestions jsonb NOT NULL DEFAULT '[]'::jsonb,
  evaluated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_gpa_rationale_short_max_len
    CHECK (rationale_short IS NULL OR length(rationale_short) <= 500),
  CONSTRAINT agent_gpa_suggestions_array
    CHECK (jsonb_typeof(improvement_suggestions) = 'array')
);

CREATE INDEX IF NOT EXISTS agent_gpa_evaluations_user_created_idx
  ON public.agent_gpa_evaluations (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS agent_gpa_evaluations_user_source_idx
  ON public.agent_gpa_evaluations (user_id, source_type, source_id);

CREATE INDEX IF NOT EXISTS agent_gpa_evaluations_user_gpa_idx
  ON public.agent_gpa_evaluations (user_id, gpa, created_at DESC);

CREATE INDEX IF NOT EXISTS agent_gpa_evaluations_evaluated_at_idx
  ON public.agent_gpa_evaluations (evaluated_at);

ALTER TABLE public.agent_gpa_evaluations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_gpa_evaluations'
      AND policyname = 'agent_gpa_owner_select'
  ) THEN
    CREATE POLICY "agent_gpa_owner_select"
      ON public.agent_gpa_evaluations
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_gpa_evaluations'
      AND policyname = 'agent_gpa_owner_insert'
  ) THEN
    CREATE POLICY "agent_gpa_owner_insert"
      ON public.agent_gpa_evaluations
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'agent_gpa_evaluations'
      AND policyname = 'agent_gpa_service_role_all'
  ) THEN
    CREATE POLICY "agent_gpa_service_role_all"
      ON public.agent_gpa_evaluations
      FOR ALL
      USING (auth.role() = 'service_role')
      WITH CHECK (auth.role() = 'service_role');
  END IF;
END $$;

COMMENT ON TABLE public.agent_gpa_evaluations IS
  'Issue #1124 AI executive GPA scores for Goal, Plan, Action, and Consistency.';

COMMENT ON COLUMN public.agent_gpa_evaluations.rationale_short IS
  'Short evaluation reason only; do not store raw user prompts, responses, or PII.';

COMMENT ON COLUMN public.agent_gpa_evaluations.improvement_suggestions IS
  'Array of compact suggestions such as rerun, prompt_edit, approval_gate, or scope_split.';

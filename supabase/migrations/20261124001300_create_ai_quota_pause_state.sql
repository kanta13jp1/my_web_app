-- Quota threshold (80% warning / 100% auto-pause) state table & RLS (#2612).
-- Complements public.ai_quota_usage written daily by quota-monitor.yml.

CREATE TABLE IF NOT EXISTS public.ai_quota_pause_state (
  tool text PRIMARY KEY CHECK (char_length(btrim(tool)) > 0),
  usage_pct numeric(6, 2) NOT NULL DEFAULT 0
    CHECK (usage_pct >= 0 AND usage_pct <= 1000),
  warning_80_sent boolean NOT NULL DEFAULT false,
  warning_80_sent_at timestamptz,
  auto_paused boolean NOT NULL DEFAULT false,
  paused_at timestamptz,
  silent_pause_detected boolean NOT NULL DEFAULT false,
  resumed_by_admin boolean NOT NULL DEFAULT false,
  resumed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resumed_at timestamptz,
  admin_issue_number integer CHECK (admin_issue_number IS NULL OR admin_issue_number > 0),
  admin_note text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_pause_state_paused_updated
  ON public.ai_quota_pause_state (auto_paused, updated_at DESC);

ALTER TABLE public.ai_quota_pause_state ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.ai_quota_pause_state FROM PUBLIC, anon;
REVOKE INSERT, DELETE ON TABLE public.ai_quota_pause_state FROM authenticated;
GRANT SELECT, UPDATE ON TABLE public.ai_quota_pause_state TO authenticated;
GRANT ALL ON TABLE public.ai_quota_pause_state TO service_role;

DROP POLICY IF EXISTS "quota_pause_select_authenticated"
  ON public.ai_quota_pause_state;
CREATE POLICY "quota_pause_select_authenticated"
  ON public.ai_quota_pause_state
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "quota_pause_admin_update"
  ON public.ai_quota_pause_state;
CREATE POLICY "quota_pause_admin_update"
  ON public.ai_quota_pause_state
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND (up.is_admin = true OR up.role = 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND (up.is_admin = true OR up.role = 'admin')
    )
  );

DROP POLICY IF EXISTS "quota_pause_write_service_role"
  ON public.ai_quota_pause_state;
CREATE POLICY "quota_pause_write_service_role"
  ON public.ai_quota_pause_state
  FOR ALL
  TO service_role
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

COMMENT ON TABLE public.ai_quota_pause_state IS
  'Per-tool 80% warning, 100% auto-pause, silent-pause mismatch detection, and manual admin resume state (#2612).';

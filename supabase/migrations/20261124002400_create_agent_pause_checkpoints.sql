-- Batch 69 (#2616): Agent checkpoint & lossless pause/resume state machine +
-- 90% early-warning & silent-pause protection table, strict RLS, and trigger guard.
-- Complements public.ai_quota_pause_state (#2612) at the per-run checkpoint layer.

CREATE TABLE IF NOT EXISTS public.agent_pause_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  run_key text NOT NULL CHECK (char_length(trim(run_key)) BETWEEN 1 AND 120),
  agent_name text NOT NULL CHECK (char_length(trim(agent_name)) BETWEEN 1 AND 80),
  checkpoint_seq integer NOT NULL DEFAULT 1 CHECK (checkpoint_seq >= 1),
  state_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  usage_ratio_pct numeric(6,2) NOT NULL DEFAULT 0 CHECK (
    usage_ratio_pct >= 0 AND usage_ratio_pct <= 1000
  ),
  warning_90_threshold_pct numeric(5,2) NOT NULL DEFAULT 90.00 CHECK (
    warning_90_threshold_pct BETWEEN 50 AND 99
  ),
  pause_status text NOT NULL DEFAULT 'running' CHECK (
    pause_status IN ('running', 'warning_90', 'paused_lossless', 'resumed', 'failed')
  ),
  warning_90_sent boolean NOT NULL DEFAULT false,
  silent_pause_alerted boolean NOT NULL DEFAULT false,
  resumed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_agent_pause_checkpoints_user_status_updated
  ON public.agent_pause_checkpoints (user_id, pause_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_pause_checkpoints_run_seq
  ON public.agent_pause_checkpoints (run_key, checkpoint_seq DESC);

ALTER TABLE public.agent_pause_checkpoints ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.agent_pause_checkpoints FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.agent_pause_checkpoints
  TO authenticated;
GRANT ALL ON TABLE public.agent_pause_checkpoints TO service_role;

DROP POLICY IF EXISTS agent_pause_checkpoints_owner_admin_select
  ON public.agent_pause_checkpoints;
CREATE POLICY agent_pause_checkpoints_owner_admin_select
  ON public.agent_pause_checkpoints
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS agent_pause_checkpoints_owner_insert
  ON public.agent_pause_checkpoints;
CREATE POLICY agent_pause_checkpoints_owner_insert
  ON public.agent_pause_checkpoints
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS agent_pause_checkpoints_owner_admin_update
  ON public.agent_pause_checkpoints;
CREATE POLICY agent_pause_checkpoints_owner_admin_update
  ON public.agent_pause_checkpoints
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS agent_pause_checkpoints_owner_admin_delete
  ON public.agent_pause_checkpoints;
CREATE POLICY agent_pause_checkpoints_owner_admin_delete
  ON public.agent_pause_checkpoints
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS agent_pause_checkpoints_service_role_all
  ON public.agent_pause_checkpoints;
CREATE POLICY agent_pause_checkpoints_service_role_all
  ON public.agent_pause_checkpoints
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.guard_agent_pause_checkpoint()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_service boolean;
  v_is_admin boolean;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for agent_pause_checkpoints'
        USING ERRCODE = '42501';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    ) INTO v_is_admin;

    IF TG_OP = 'INSERT' THEN
      IF NOT v_is_admin AND NEW.user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'user_id must match authenticated caller'
          USING ERRCODE = '42501';
      END IF;
      IF NOT v_is_admin AND NEW.pause_status = 'resumed' THEN
        RAISE EXCEPTION 'Only administrators or service_role may insert resumed checkpoints'
          USING ERRCODE = '42501';
      END IF;
      IF NOT v_is_admin AND (NEW.resumed_by IS NOT NULL OR NEW.resumed_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Only administrators or service_role may set resumed metadata'
          USING ERRCODE = '42501';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, user_id, created_at cannot be modified'
          USING ERRCODE = '42501';
      END IF;

      IF NEW.checkpoint_seq < OLD.checkpoint_seq THEN
        RAISE EXCEPTION 'checkpoint_seq cannot decrease (% -> %)', OLD.checkpoint_seq, NEW.checkpoint_seq
          USING ERRCODE = '22000';
      END IF;

      IF NOT v_is_admin THEN
        IF NEW.pause_status = 'resumed' AND OLD.pause_status IS DISTINCT FROM 'resumed' THEN
          RAISE EXCEPTION 'Only administrators or service_role may resume paused checkpoints'
            USING ERRCODE = '42501';
        END IF;
        IF NEW.resumed_by IS DISTINCT FROM OLD.resumed_by
          OR NEW.resumed_at IS DISTINCT FROM OLD.resumed_at THEN
          RAISE EXCEPTION 'Only administrators or service_role may modify resumed audit columns'
            USING ERRCODE = '42501';
        END IF;
        IF NEW.warning_90_threshold_pct > OLD.warning_90_threshold_pct THEN
          RAISE EXCEPTION 'Only administrators or service_role may raise warning_90_threshold_pct'
            USING ERRCODE = '42501';
        END IF;
      END IF;
    END IF;
  END IF;

  IF NEW.pause_status = 'resumed' AND (v_is_service OR COALESCE(v_is_admin, false)) THEN
    IF NOT v_is_service AND auth.uid() IS NOT NULL THEN
      NEW.resumed_by := COALESCE(NEW.resumed_by, auth.uid());
    END IF;
    NEW.resumed_at := COALESCE(NEW.resumed_at, timezone('utc', now()));
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_agent_pause_checkpoint
  ON public.agent_pause_checkpoints;
CREATE TRIGGER trg_guard_agent_pause_checkpoint
  BEFORE INSERT OR UPDATE
  ON public.agent_pause_checkpoints
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_agent_pause_checkpoint();

COMMENT ON TABLE public.agent_pause_checkpoints IS
  'Per-run lossless agent checkpoint state machine, 90% early-warning flag, and silent-pause audit protection (#2616).';

COMMENT ON FUNCTION public.guard_agent_pause_checkpoint() IS
  'Guards immutable columns, non-decreasing checkpoint_seq, and admin-only resume transitions on agent_pause_checkpoints (#2616).';

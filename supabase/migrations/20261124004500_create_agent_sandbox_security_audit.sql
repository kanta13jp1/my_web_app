-- Issue #2722: Agent Isolated Sandbox Capability Policies & Immutable Security Audit Log.
-- Enforces sandbox boundaries (allow_host_fs=false, allow_prod_db=false),
-- least-privilege policies, and append-only audit telemetry/error traces.

CREATE TABLE IF NOT EXISTS public.agent_sandbox_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
  sandbox_profile text NOT NULL DEFAULT 'isolated_worker'
    CHECK (sandbox_profile IN ('isolated_worker', 'strict_read_only')),
  allow_host_fs boolean NOT NULL DEFAULT false CHECK (allow_host_fs = false),
  allow_prod_db boolean NOT NULL DEFAULT false CHECK (allow_prod_db = false),
  network_egress_mode text NOT NULL DEFAULT 'none'
    CHECK (network_egress_mode IN ('none', 'allowlist_only')),
  max_retries_per_tool integer NOT NULL DEFAULT 3
    CHECK (max_retries_per_tool BETWEEN 1 AND 5),
  max_burst_per_window integer NOT NULL DEFAULT 10
    CHECK (max_burst_per_window BETWEEN 1 AND 50),
  allowed_tools text[] NOT NULL DEFAULT ARRAY[
    'sandbox.json_validate',
    'sandbox.text_metrics',
    'sandbox.math_eval'
  ]::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS agent_sandbox_policies_user_profile_idx
  ON public.agent_sandbox_policies(user_id, sandbox_profile);

CREATE OR REPLACE FUNCTION public.touch_agent_sandbox_policy_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'user_id is immutable on agent_sandbox_policies'
        USING ERRCODE = '42501';
    END IF;
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_agent_sandbox_policy_updated_at
  ON public.agent_sandbox_policies;
CREATE TRIGGER trg_touch_agent_sandbox_policy_updated_at
BEFORE UPDATE ON public.agent_sandbox_policies
FOR EACH ROW
EXECUTE FUNCTION public.touch_agent_sandbox_policy_updated_at();

ALTER TABLE public.agent_sandbox_policies ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.agent_sandbox_policies FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.agent_sandbox_policies TO authenticated;
GRANT ALL ON public.agent_sandbox_policies TO service_role;

DROP POLICY IF EXISTS agent_sandbox_policies_select_own ON public.agent_sandbox_policies;
CREATE POLICY agent_sandbox_policies_select_own
  ON public.agent_sandbox_policies
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS agent_sandbox_policies_insert_own ON public.agent_sandbox_policies;
CREATE POLICY agent_sandbox_policies_insert_own
  ON public.agent_sandbox_policies
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS agent_sandbox_policies_update_own ON public.agent_sandbox_policies;
CREATE POLICY agent_sandbox_policies_update_own
  ON public.agent_sandbox_policies
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS agent_sandbox_policies_delete_own ON public.agent_sandbox_policies;
CREATE POLICY agent_sandbox_policies_delete_own
  ON public.agent_sandbox_policies
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Dedicated Immutable Audit Log for Agent Sandbox Telemetry & Error Traces
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.agent_sandbox_security_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
  session_id text NOT NULL DEFAULT '',
  sandbox_id text NOT NULL DEFAULT 'isolated_worker',
  actor_role text NOT NULL DEFAULT 'generated_ui_sandbox',
  tool_name text NOT NULL CHECK (char_length(btrim(tool_name)) > 0),
  action_kind text NOT NULL DEFAULT 'sandbox_preflight'
    CHECK (
      action_kind IN (
        'sandbox_preflight',
        'tool_execution',
        'blocked_guard',
        'agent_run_preflight'
      )
    ),
  decision text NOT NULL CHECK (decision IN ('allowed', 'blocked')),
  blocked_category text NOT NULL DEFAULT 'none'
    CHECK (
      blocked_category IN (
        'none',
        'host_filesystem_access',
        'prod_db_access',
        'ssrf_metadata',
        'prompt_injection',
        'excessive_retries',
        'invalid_tool_args',
        'least_privilege_denied',
        'sandbox_escape'
      )
    ),
  blocked_reason text,
  retry_attempt integer NOT NULL DEFAULT 0 CHECK (retry_attempt >= 0),
  sanitized_args jsonb NOT NULL DEFAULT '{}'::jsonb,
  anomaly_flags text[] NOT NULL DEFAULT ARRAY[]::text[],
  injection_signals jsonb NOT NULL DEFAULT '[]'::jsonb,
  network_egress_target text,
  error_trace text,
  latency_ms integer NOT NULL DEFAULT 0 CHECK (latency_ms >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agent_sandbox_security_audit_user_created_idx
  ON public.agent_sandbox_security_audit(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS agent_sandbox_security_audit_blocked_idx
  ON public.agent_sandbox_security_audit(user_id, decision, blocked_category, created_at DESC);

CREATE OR REPLACE FUNCTION public.guard_agent_sandbox_audit_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'agent_sandbox_security_audit is immutable append-only'
    USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_agent_sandbox_audit_immutable
  ON public.agent_sandbox_security_audit;
CREATE TRIGGER trg_guard_agent_sandbox_audit_immutable
BEFORE UPDATE OR DELETE ON public.agent_sandbox_security_audit
FOR EACH ROW
EXECUTE FUNCTION public.guard_agent_sandbox_audit_immutable();

ALTER TABLE public.agent_sandbox_security_audit ENABLE ROW LEVEL SECURITY;

-- Least-privilege: authenticated users can only SELECT their own audit logs;
-- writes are strictly restricted to Edge Functions / service_role.
REVOKE ALL ON public.agent_sandbox_security_audit FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.agent_sandbox_security_audit FROM authenticated;
GRANT SELECT ON public.agent_sandbox_security_audit TO authenticated;
GRANT ALL ON public.agent_sandbox_security_audit TO service_role;

DROP POLICY IF EXISTS agent_sandbox_audit_select_own ON public.agent_sandbox_security_audit;
CREATE POLICY agent_sandbox_audit_select_own
  ON public.agent_sandbox_security_audit
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

COMMENT ON TABLE public.agent_sandbox_policies IS
  'Issue #2722 per-user isolated sandbox policy. CHECK constraints force allow_host_fs=false and allow_prod_db=false.';
COMMENT ON TABLE public.agent_sandbox_security_audit IS
  'Issue #2722 append-only security telemetry and error trace log written by Edge Function sandbox preflight guards.';

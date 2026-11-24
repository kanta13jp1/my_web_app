-- Admin action audit logs (append-only) and pre-change impact assessment
-- confirmation workflow with PostgreSQL triggers and admin-only RLS (#2617).

CREATE TABLE IF NOT EXISTS public.admin_impact_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (
      action_type IN (
        'rls_policy_update',
        'schema_migration',
        'feature_flag_toggle',
        'quota_override',
        'user_privilege_change',
        'data_backfill',
        'config_change'
      )
    ),
  target_resource text NOT NULL CHECK (char_length(btrim(target_resource)) > 0),
  change_summary text NOT NULL CHECK (char_length(btrim(change_summary)) > 0),
  expected_impact_scope text NOT NULL DEFAULT '',
  risk_level text NOT NULL DEFAULT 'medium'
    CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  risk_score integer NOT NULL DEFAULT 50
    CHECK (risk_score >= 0 AND risk_score <= 100),
  mitigation_plan text NOT NULL DEFAULT '',
  requires_pre_confirmation boolean NOT NULL DEFAULT true,
  impact_confirmed boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending_review'
    CHECK (status IN ('pending_review', 'approved', 'executed', 'cancelled')),
  approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  executed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_impact_assessments_status_created
  ON public.admin_impact_assessments (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_impact_assessments_risk_created
  ON public.admin_impact_assessments (risk_level, created_at DESC);

ALTER TABLE public.admin_impact_assessments ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_impact_assessments FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.admin_impact_assessments TO authenticated;
GRANT ALL ON TABLE public.admin_impact_assessments TO service_role;

DROP POLICY IF EXISTS "admin_impact_assessments_admin_select"
  ON public.admin_impact_assessments;
CREATE POLICY "admin_impact_assessments_admin_select"
  ON public.admin_impact_assessments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_impact_assessments_admin_insert"
  ON public.admin_impact_assessments;
CREATE POLICY "admin_impact_assessments_admin_insert"
  ON public.admin_impact_assessments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
    AND (SELECT auth.uid()) = actor_user_id
    AND status = 'pending_review'
    AND impact_confirmed = false
    AND approved_by IS NULL
    AND approved_at IS NULL
    AND executed_at IS NULL
  );

DROP POLICY IF EXISTS "admin_impact_assessments_admin_update"
  ON public.admin_impact_assessments;
CREATE POLICY "admin_impact_assessments_admin_update"
  ON public.admin_impact_assessments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_impact_assessments_service_role_all"
  ON public.admin_impact_assessments;
CREATE POLICY "admin_impact_assessments_service_role_all"
  ON public.admin_impact_assessments
  FOR ALL
  TO service_role
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE TABLE IF NOT EXISTS public.admin_action_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id uuid REFERENCES public.admin_impact_assessments(id) ON DELETE SET NULL,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role text NOT NULL DEFAULT 'admin',
  action_type text NOT NULL CHECK (char_length(btrim(action_type)) > 0),
  target_table text NOT NULL DEFAULT 'admin_impact_assessments'
    CHECK (char_length(btrim(target_table)) > 0),
  target_resource text NOT NULL CHECK (char_length(btrim(target_resource)) > 0),
  operation text NOT NULL
    CHECK (operation IN ('INSERT', 'UPDATE', 'APPROVE', 'EXECUTE', 'CANCEL')),
  risk_level text NOT NULL DEFAULT 'medium'
    CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  impact_summary text NOT NULL DEFAULT '',
  pre_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  post_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  impact_confirmed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_action_audit_logs_created_at
  ON public.admin_action_audit_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_action_audit_logs_action_risk_created
  ON public.admin_action_audit_logs (action_type, risk_level, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_action_audit_logs_actor_created
  ON public.admin_action_audit_logs (actor_user_id, created_at DESC);

ALTER TABLE public.admin_action_audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_action_audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.admin_action_audit_logs TO authenticated;
GRANT ALL ON TABLE public.admin_action_audit_logs TO service_role;

DROP POLICY IF EXISTS "admin_action_audit_logs_admin_select"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_admin_select"
  ON public.admin_action_audit_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_action_audit_logs_deny_client_insert"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_deny_client_insert"
  ON public.admin_action_audit_logs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "admin_action_audit_logs_deny_client_update"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_deny_client_update"
  ON public.admin_action_audit_logs
  FOR UPDATE
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "admin_action_audit_logs_deny_client_delete"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_deny_client_delete"
  ON public.admin_action_audit_logs
  FOR DELETE
  TO anon, authenticated
  USING (false);

DROP POLICY IF EXISTS "admin_action_audit_logs_service_role_select"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_service_role_select"
  ON public.admin_action_audit_logs
  FOR SELECT
  TO service_role
  USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "admin_action_audit_logs_service_role_insert"
  ON public.admin_action_audit_logs;
CREATE POLICY "admin_action_audit_logs_service_role_insert"
  ON public.admin_action_audit_logs
  FOR INSERT
  TO service_role
  WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION public.guard_admin_impact_assessment_workflow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $guard$
DECLARE
  v_uid uuid := auth.uid();
  v_role text := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    ''
  );
  v_is_admin boolean := false;
BEGIN
  IF v_role = 'service_role'
     OR (
       session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
       AND v_role NOT IN ('anon', 'authenticated')
     ) THEN
    RETURN NEW;
  END IF;

  IF v_uid IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = v_uid
        AND up.is_admin = true
    )
    INTO v_is_admin;
  END IF;

  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION
      'Only administrators with is_admin=true may manage impact assessments'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.actor_user_id IS DISTINCT FROM v_uid
       OR NEW.status IS DISTINCT FROM 'pending_review'
       OR NEW.impact_confirmed IS DISTINCT FROM false
       OR NEW.approved_by IS NOT NULL
       OR NEW.approved_at IS NOT NULL
       OR NEW.executed_at IS NOT NULL THEN
      RAISE EXCEPTION
        'New impact assessments must start in pending_review with unconfirmed state'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.actor_user_id IS DISTINCT FROM OLD.actor_user_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION
      'actor_user_id and created_at are immutable on impact assessments'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status IN ('approved', 'executed') THEN
    IF COALESCE(NEW.impact_confirmed, false) = false
       OR NEW.approved_by IS NULL
       OR NEW.approved_at IS NULL THEN
      RAISE EXCEPTION
        'Impact scope and risk confirmation is required before approval or execution'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF NEW.status = 'executed' THEN
    IF OLD.status NOT IN ('approved', 'executed')
       OR NEW.executed_at IS NULL THEN
      RAISE EXCEPTION
        'Impact assessment must be approved before execution'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_admin_impact_assessment_workflow
  ON public.admin_impact_assessments;
CREATE TRIGGER trg_guard_admin_impact_assessment_workflow
  BEFORE INSERT OR UPDATE ON public.admin_impact_assessments
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_admin_impact_assessment_workflow();

CREATE OR REPLACE FUNCTION public.log_admin_impact_assessment_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $audit$
DECLARE
  v_uid uuid := auth.uid();
  v_actor_role text := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    session_user
  );
  v_operation text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_operation := 'INSERT';
  ELSIF NEW.status = 'executed' AND OLD.status IS DISTINCT FROM 'executed' THEN
    v_operation := 'EXECUTE';
  ELSIF NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved' THEN
    v_operation := 'APPROVE';
  ELSIF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    v_operation := 'CANCEL';
  ELSE
    v_operation := 'UPDATE';
  END IF;

  INSERT INTO public.admin_action_audit_logs (
    assessment_id,
    actor_user_id,
    actor_role,
    action_type,
    target_table,
    target_resource,
    operation,
    risk_level,
    impact_summary,
    pre_state,
    post_state,
    impact_confirmed
  )
  VALUES (
    NEW.id,
    COALESCE(v_uid, NEW.approved_by, NEW.actor_user_id),
    v_actor_role,
    NEW.action_type,
    TG_TABLE_NAME,
    NEW.target_resource,
    v_operation,
    NEW.risk_level,
    NEW.expected_impact_scope,
    CASE WHEN TG_OP = 'INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END,
    to_jsonb(NEW),
    COALESCE(NEW.impact_confirmed, false)
  );

  RETURN NEW;
END;
$audit$;

DROP TRIGGER IF EXISTS trg_log_admin_impact_assessment_audit
  ON public.admin_impact_assessments;
CREATE TRIGGER trg_log_admin_impact_assessment_audit
  AFTER INSERT OR UPDATE ON public.admin_impact_assessments
  FOR EACH ROW
  EXECUTE FUNCTION public.log_admin_impact_assessment_audit();

CREATE OR REPLACE FUNCTION public.prevent_admin_action_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $immutable$
BEGIN
  RAISE EXCEPTION
    'admin_action_audit_logs is append-only; UPDATE and DELETE are prohibited'
    USING ERRCODE = '42501';
END;
$immutable$;

DROP TRIGGER IF EXISTS trg_prevent_admin_action_audit_log_mutation
  ON public.admin_action_audit_logs;
CREATE TRIGGER trg_prevent_admin_action_audit_log_mutation
  BEFORE UPDATE OR DELETE ON public.admin_action_audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_admin_action_audit_log_mutation();

COMMENT ON FUNCTION public.guard_admin_impact_assessment_workflow() IS
  'Enforces is_admin=true and pre-change impact confirmation before approval or execution (#2617).';

COMMENT ON FUNCTION public.log_admin_impact_assessment_audit() IS
  'Automatically appends immutable audit rows to admin_action_audit_logs on assessment changes (#2617).';

COMMENT ON FUNCTION public.prevent_admin_action_audit_log_mutation() IS
  'Prevents UPDATE or DELETE mutations on append-only admin_action_audit_logs (#2617).';

COMMENT ON TABLE public.admin_impact_assessments IS
  'Pre-change impact scope, risk level, and admin confirmation state before major system changes (#2617).';

COMMENT ON TABLE public.admin_action_audit_logs IS
  'Append-only audit trail automatically populated by PostgreSQL triggers for admin actions (#2617).';

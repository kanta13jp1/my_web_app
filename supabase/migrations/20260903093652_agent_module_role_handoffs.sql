-- Issue #2921: module-scoped agent access and auditable task handoffs.
--
-- Existing owner-facing agent organization flows remain unchanged unless a
-- task explicitly opts into module governance. Agent runtimes must receive
-- trusted app_metadata claims named agent_module and agent_id. Supabase Auth
-- app_metadata is administrator-controlled; user_metadata must never be used
-- for these authorization decisions.

ALTER TABLE public.agent_tasks
  ADD COLUMN IF NOT EXISTS module_governed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS current_module text,
  ADD COLUMN IF NOT EXISTS handoff_state text NOT NULL DEFAULT 'none';

DO $constraints$
BEGIN
  ALTER TABLE public.agent_tasks
    ADD CONSTRAINT agent_tasks_current_module_check
    CHECK (
      current_module IS NULL
      OR current_module IN ('front_office', 'management')
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.agent_tasks
    ADD CONSTRAINT agent_tasks_module_governance_check
    CHECK (
      (NOT module_governed AND current_module IS NULL)
      OR (module_governed AND current_module IS NOT NULL)
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.agent_tasks
    ADD CONSTRAINT agent_tasks_handoff_state_check
    CHECK (handoff_state IN ('none', 'requested', 'accepted', 'rejected'));
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

CREATE OR REPLACE FUNCTION public.current_agent_module()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT NULLIF(auth.jwt() -> 'app_metadata' ->> 'agent_module', '');
$$;

CREATE OR REPLACE FUNCTION public.current_agent_claim_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN COALESCE(auth.jwt() -> 'app_metadata' ->> 'agent_id', '')
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN (auth.jwt() -> 'app_metadata' ->> 'agent_id')::uuid
    ELSE NULL
  END;
$$;

REVOKE ALL ON FUNCTION public.current_agent_module() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_agent_claim_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_agent_module()
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_agent_claim_id()
  TO anon, authenticated, service_role;

-- Restrictive policies narrow the legacy owner policies only for explicitly
-- governed tasks. A normal owner token has no module claims and keeps its
-- read-only oversight, while an agent token sees only its assigned module.
DROP POLICY IF EXISTS "Agent tasks module read boundary" ON public.agent_tasks;
CREATE POLICY "Agent tasks module read boundary"
  ON public.agent_tasks
  AS RESTRICTIVE
  FOR SELECT
  USING (
    NOT module_governed
    OR (
      public.current_agent_module() IS NULL
      AND public.current_agent_claim_id() IS NULL
    )
    OR (
      current_module = public.current_agent_module()
      AND assignee_agent_id = public.current_agent_claim_id()
    )
  );

DROP POLICY IF EXISTS "Agent tasks module insert boundary" ON public.agent_tasks;
CREATE POLICY "Agent tasks module insert boundary"
  ON public.agent_tasks
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    NOT module_governed
    OR (
      auth.uid() = user_id
      AND current_module = public.current_agent_module()
      AND assignee_agent_id = public.current_agent_claim_id()
    )
  );

DROP POLICY IF EXISTS "Agent tasks module update boundary" ON public.agent_tasks;
CREATE POLICY "Agent tasks module update boundary"
  ON public.agent_tasks
  AS RESTRICTIVE
  FOR UPDATE
  USING (
    NOT module_governed
    OR (
      auth.uid() = user_id
      AND current_module = public.current_agent_module()
      AND assignee_agent_id = public.current_agent_claim_id()
    )
  )
  WITH CHECK (
    NOT module_governed
    OR (
      auth.uid() = user_id
      AND current_module = public.current_agent_module()
      AND assignee_agent_id = public.current_agent_claim_id()
    )
  );

DROP POLICY IF EXISTS "Agent tasks module delete boundary" ON public.agent_tasks;
CREATE POLICY "Agent tasks module delete boundary"
  ON public.agent_tasks
  AS RESTRICTIVE
  FOR DELETE
  USING (
    NOT module_governed
    OR (
      auth.uid() = user_id
      AND current_module = public.current_agent_module()
      AND assignee_agent_id = public.current_agent_claim_id()
    )
  );

CREATE TABLE IF NOT EXISTS public.agent_module_handoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.agent_tasks(id) ON DELETE CASCADE,
  from_agent_id uuid NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
  to_agent_id uuid NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
  from_module text NOT NULL CHECK (from_module IN ('front_office', 'management')),
  to_module text NOT NULL CHECK (to_module IN ('front_office', 'management')),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'accepted', 'rejected')),
  summary text NOT NULL,
  decision_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (from_module <> to_module),
  CHECK (from_agent_id <> to_agent_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_module_handoffs_one_requested
  ON public.agent_module_handoffs(task_id)
  WHERE status = 'requested';

CREATE INDEX IF NOT EXISTS idx_agent_module_handoffs_user_status
  ON public.agent_module_handoffs(user_id, status, requested_at DESC);

CREATE TABLE IF NOT EXISTS public.agent_module_handoff_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  handoff_id uuid NOT NULL
    REFERENCES public.agent_module_handoffs(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.agent_tasks(id) ON DELETE CASCADE,
  actor_agent_id uuid NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
  actor_module text NOT NULL
    CHECK (actor_module IN ('front_office', 'management')),
  event_type text NOT NULL
    CHECK (event_type IN ('requested', 'accepted', 'rejected')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_module_handoff_events_handoff
  ON public.agent_module_handoff_events(handoff_id, created_at);

ALTER TABLE public.agent_module_handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_module_handoff_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agent module handoffs scoped read"
  ON public.agent_module_handoffs;
CREATE POLICY "Agent module handoffs scoped read"
  ON public.agent_module_handoffs
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    AND (
      (
        public.current_agent_module() IS NULL
        AND public.current_agent_claim_id() IS NULL
      )
      OR (
        from_module = public.current_agent_module()
        AND from_agent_id = public.current_agent_claim_id()
      )
      OR (
        to_module = public.current_agent_module()
        AND to_agent_id = public.current_agent_claim_id()
      )
    )
  );

DROP POLICY IF EXISTS "Agent module handoff events scoped read"
  ON public.agent_module_handoff_events;
CREATE POLICY "Agent module handoff events scoped read"
  ON public.agent_module_handoff_events
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    AND (
      (
        public.current_agent_module() IS NULL
        AND public.current_agent_claim_id() IS NULL
      )
      OR EXISTS (
        SELECT 1
        FROM public.agent_module_handoffs AS handoff
        WHERE handoff.id = handoff_id
          AND handoff.user_id = auth.uid()
          AND (
            (
              handoff.from_module = public.current_agent_module()
              AND handoff.from_agent_id = public.current_agent_claim_id()
            )
            OR (
              handoff.to_module = public.current_agent_module()
              AND handoff.to_agent_id = public.current_agent_claim_id()
            )
          )
      )
    )
  );

REVOKE ALL ON TABLE public.agent_module_handoffs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.agent_module_handoff_events
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.agent_module_handoffs TO authenticated;
GRANT SELECT ON TABLE public.agent_module_handoff_events TO authenticated;
GRANT ALL ON TABLE public.agent_module_handoffs TO service_role;
GRANT ALL ON TABLE public.agent_module_handoff_events TO service_role;

CREATE OR REPLACE FUNCTION public.guard_agent_module_task_assignment()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_table_owner text;
  v_authorized_handoff boolean;
BEGIN
  IF OLD.module_governed AND (
    NEW.module_governed IS DISTINCT FROM OLD.module_governed
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.assignee_agent_id IS DISTINCT FROM OLD.assignee_agent_id
    OR NEW.current_module IS DISTINCT FROM OLD.current_module
    OR NEW.handoff_state IS DISTINCT FROM OLD.handoff_state
  ) THEN
    SELECT pg_catalog.pg_get_userbyid(class.relowner)
      INTO v_table_owner
    FROM pg_catalog.pg_class AS class
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = class.relnamespace
    WHERE namespace.nspname = 'public'
      AND class.relname = 'agent_tasks';

    v_authorized_handoff :=
      current_user = v_table_owner
      AND current_setting('app.agent_module_handoff_write', true)
        = 'issue-2921-verified-handoff';

    IF NOT v_authorized_handoff THEN
      RAISE EXCEPTION
        'module-governed task assignment changes require the handoff RPC'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agent_module_task_assignment_guard
  ON public.agent_tasks;
CREATE TRIGGER agent_module_task_assignment_guard
  BEFORE UPDATE ON public.agent_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_agent_module_task_assignment();

CREATE OR REPLACE FUNCTION public.request_agent_module_handoff(
  p_task_id uuid,
  p_to_agent_id uuid,
  p_to_module text,
  p_summary text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_actor_module text := public.current_agent_module();
  v_actor_agent_id uuid := public.current_agent_claim_id();
  v_task public.agent_tasks%ROWTYPE;
  v_handoff_id uuid;
  v_previous_guard text := current_setting(
    'app.agent_module_handoff_write',
    true
  );
BEGIN
  IF v_user_id IS NULL OR v_actor_module IS NULL OR v_actor_agent_id IS NULL THEN
    RAISE EXCEPTION 'trusted agent module claims are required'
      USING ERRCODE = '42501';
  END IF;
  IF p_to_module NOT IN ('front_office', 'management')
     OR p_to_module = v_actor_module
     OR p_to_agent_id = v_actor_agent_id
     OR NULLIF(btrim(p_summary), '') IS NULL THEN
    RAISE EXCEPTION 'invalid module handoff request'
      USING ERRCODE = '22023';
  END IF;

  SELECT task.*
    INTO v_task
  FROM public.agent_tasks AS task
  WHERE task.id = p_task_id
    AND task.user_id = v_user_id
    AND task.module_governed
    AND task.current_module = v_actor_module
    AND task.assignee_agent_id = v_actor_agent_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'task is not assigned to the calling module agent'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.agents AS agent
    WHERE agent.id = p_to_agent_id
      AND agent.user_id = v_user_id
      AND agent.status = 'active'
  ) THEN
    RAISE EXCEPTION 'target agent is not active in this organization'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.agent_module_handoffs (
    user_id,
    task_id,
    from_agent_id,
    to_agent_id,
    from_module,
    to_module,
    summary
  ) VALUES (
    v_user_id,
    v_task.id,
    v_actor_agent_id,
    p_to_agent_id,
    v_actor_module,
    p_to_module,
    btrim(p_summary)
  )
  RETURNING id INTO v_handoff_id;

  PERFORM set_config(
    'app.agent_module_handoff_write',
    'issue-2921-verified-handoff',
    true
  );
  UPDATE public.agent_tasks
  SET handoff_state = 'requested'
  WHERE id = v_task.id AND user_id = v_user_id;
  PERFORM set_config(
    'app.agent_module_handoff_write',
    COALESCE(v_previous_guard, ''),
    true
  );

  INSERT INTO public.agent_module_handoff_events (
    user_id,
    handoff_id,
    task_id,
    actor_agent_id,
    actor_module,
    event_type,
    details
  ) VALUES (
    v_user_id,
    v_handoff_id,
    v_task.id,
    v_actor_agent_id,
    v_actor_module,
    'requested',
    jsonb_build_object('to_module', p_to_module, 'summary', btrim(p_summary))
  );

  RETURN v_handoff_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_agent_module_handoff(
  p_handoff_id uuid,
  p_accept boolean,
  p_reason text DEFAULT NULL
)
RETURNS public.agent_module_handoffs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_actor_module text := public.current_agent_module();
  v_actor_agent_id uuid := public.current_agent_claim_id();
  v_handoff public.agent_module_handoffs%ROWTYPE;
  v_task public.agent_tasks%ROWTYPE;
  v_previous_guard text := current_setting(
    'app.agent_module_handoff_write',
    true
  );
BEGIN
  IF v_user_id IS NULL OR v_actor_module IS NULL OR v_actor_agent_id IS NULL THEN
    RAISE EXCEPTION 'trusted agent module claims are required'
      USING ERRCODE = '42501';
  END IF;

  SELECT handoff.*
    INTO v_handoff
  FROM public.agent_module_handoffs AS handoff
  WHERE handoff.id = p_handoff_id
    AND handoff.user_id = v_user_id
    AND handoff.status = 'requested'
    AND handoff.to_module = v_actor_module
    AND handoff.to_agent_id = v_actor_agent_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'handoff is not awaiting this module agent'
      USING ERRCODE = '42501';
  END IF;

  SELECT task.*
    INTO v_task
  FROM public.agent_tasks AS task
  WHERE task.id = v_handoff.task_id
    AND task.user_id = v_user_id
    AND task.module_governed
    AND task.current_module = v_handoff.from_module
    AND task.assignee_agent_id = v_handoff.from_agent_id
    AND task.handoff_state = 'requested'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'handoff source assignment changed before decision'
      USING ERRCODE = '40001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.agents AS agent
    WHERE agent.id = v_actor_agent_id
      AND agent.user_id = v_user_id
      AND agent.status = 'active'
  ) THEN
    RAISE EXCEPTION 'target agent is no longer active'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.agent_module_handoffs
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
      decision_reason = NULLIF(btrim(p_reason), ''),
      decided_at = now(),
      updated_at = now()
  WHERE id = v_handoff.id
  RETURNING * INTO v_handoff;

  PERFORM set_config(
    'app.agent_module_handoff_write',
    'issue-2921-verified-handoff',
    true
  );
  IF p_accept THEN
    UPDATE public.agent_tasks
    SET assignee_agent_id = v_handoff.to_agent_id,
        current_module = v_handoff.to_module,
        handoff_state = 'accepted'
    WHERE id = v_task.id AND user_id = v_user_id;
  ELSE
    UPDATE public.agent_tasks
    SET handoff_state = 'rejected'
    WHERE id = v_task.id AND user_id = v_user_id;
  END IF;
  PERFORM set_config(
    'app.agent_module_handoff_write',
    COALESCE(v_previous_guard, ''),
    true
  );

  INSERT INTO public.agent_module_handoff_events (
    user_id,
    handoff_id,
    task_id,
    actor_agent_id,
    actor_module,
    event_type,
    details
  ) VALUES (
    v_user_id,
    v_handoff.id,
    v_task.id,
    v_actor_agent_id,
    v_actor_module,
    CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
    jsonb_build_object('reason', NULLIF(btrim(p_reason), ''))
  );

  RETURN v_handoff;
END;
$$;

REVOKE ALL ON FUNCTION public.request_agent_module_handoff(uuid, uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decide_agent_module_handoff(uuid, boolean, text)
  FROM PUBLIC, anon;
GRANT EXECUTE
  ON FUNCTION public.request_agent_module_handoff(uuid, uuid, text, text)
  TO authenticated;
GRANT EXECUTE
  ON FUNCTION public.decide_agent_module_handoff(uuid, boolean, text)
  TO authenticated;

COMMENT ON COLUMN public.agent_tasks.module_governed IS
  'True only for tasks isolated by trusted app_metadata module and agent claims.';
COMMENT ON TABLE public.agent_module_handoffs IS
  'Validated cross-module agent task transfer requests and decisions.';
COMMENT ON TABLE public.agent_module_handoff_events IS
  'Append-only audit events emitted by agent module handoff RPCs.';

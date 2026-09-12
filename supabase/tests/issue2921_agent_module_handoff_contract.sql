-- Real PostgreSQL RLS/RPC contract for Issue #2921. This runs after the
-- production migration in the disposable Testcontainers database.

DO $contract$
DECLARE
  v_restrictive_policies integer;
  v_function record;
BEGIN
  SELECT count(*)
    INTO v_restrictive_policies
  FROM pg_catalog.pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'agent_tasks'
    AND policyname LIKE 'Agent tasks module % boundary'
    AND permissive = 'RESTRICTIVE';
  IF v_restrictive_policies <> 4 THEN
    RAISE EXCEPTION 'expected four restrictive task policies, found %',
      v_restrictive_policies;
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'agent_tasks',
        'agent_module_handoffs',
        'agent_module_handoff_events'
      )
      AND relation.relrowsecurity
  ) <> 3 THEN
    RAISE EXCEPTION 'agent task/handoff RLS is incomplete';
  END IF;

  FOR v_function IN
    SELECT
      procedure.proname,
      procedure.prosecdef,
      COALESCE(procedure.proconfig, ARRAY[]::text[]) AS config
    FROM pg_catalog.pg_proc AS procedure
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname IN (
        'request_agent_module_handoff',
        'decide_agent_module_handoff'
      )
  LOOP
    IF NOT v_function.prosecdef THEN
      RAISE EXCEPTION '% is not SECURITY DEFINER', v_function.proname;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM unnest(v_function.config) AS setting
      WHERE setting IN ('search_path=', 'search_path=""')
    ) THEN
      RAISE EXCEPTION '% search_path is not pinned empty: %',
        v_function.proname,
        v_function.config;
    END IF;
  END LOOP;

  IF has_table_privilege(
       'authenticated',
       'public.agent_module_handoffs',
       'INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.agent_module_handoff_events',
       'INSERT,UPDATE,DELETE'
     ) THEN
    RAISE EXCEPTION 'authenticated received direct handoff write privileges';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.request_agent_module_handoff(uuid,uuid,text,text)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'anon',
       'public.decide_agent_module_handoff(uuid,boolean,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'anon can execute a module handoff RPC';
  END IF;
END;
$contract$;

-- Create the governed front-office work as the database owner. Production
-- provisioning must likewise set module_governed, current_module, and the
-- assignee together.
INSERT INTO public.agent_tasks (
  id,
  user_id,
  supervisor_agent_id,
  assignee_agent_id,
  title,
  description,
  module_governed,
  current_module,
  metadata
)
VALUES (
  '00000000-0000-4000-8000-00000000f921',
  '00000000-0000-4000-8000-000000002921',
  '00000000-0000-4000-8000-00000000b921',
  '00000000-0000-4000-8000-00000000a921',
  'Qualify customer request',
  'Front office qualifies, then management makes the overall decision.',
  true,
  'front_office',
  '{"fixture":"issue-2921","module":"front_office"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- The human owner token has organization-wide oversight but cannot mutate a
-- governed assignment. Legacy tasks retain the prior owner mutation contract.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{}}',
  true
);

DO $contract$
DECLARE
  v_rows bigint;
BEGIN
  IF (
    SELECT count(*)
    FROM public.agent_tasks
    WHERE id IN (
      '00000000-0000-4000-8000-00000000e921',
      '00000000-0000-4000-8000-00000000f921'
    )
  ) <> 2 THEN
    RAISE EXCEPTION 'owner oversight cannot read both legacy and governed work';
  END IF;

  UPDATE public.agent_tasks
  SET title = 'Legacy owner update remains supported'
  WHERE id = '00000000-0000-4000-8000-00000000e921';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'legacy owner update compatibility was lost';
  END IF;

  UPDATE public.agent_tasks
  SET title = 'Unauthorized owner overwrite'
  WHERE id = '00000000-0000-4000-8000-00000000f921';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'owner token mutated module-governed work';
  END IF;
END;
$contract$;
RESET ROLE;

-- The assigned front-office component can work its own task, cannot rewrite
-- its assignment, and requests a structured handoff to management.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{"agent_module":"front_office","agent_id":"00000000-0000-4000-8000-00000000a921"}}',
  true
);

DO $contract$
DECLARE
  v_rows bigint;
BEGIN
  UPDATE public.agent_tasks
  SET title = 'Front office qualification complete', status = 'in_progress'
  WHERE id = '00000000-0000-4000-8000-00000000f921';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'assigned front-office component cannot update its task';
  END IF;

  BEGIN
    UPDATE public.agent_tasks
    SET current_module = 'management',
        assignee_agent_id = '00000000-0000-4000-8000-00000000b921'
    WHERE id = '00000000-0000-4000-8000-00000000f921';
    RAISE EXCEPTION 'direct governed assignment rewrite unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$contract$;

SELECT public.request_agent_module_handoff(
  '00000000-0000-4000-8000-00000000f921',
  '00000000-0000-4000-8000-00000000b921',
  'management',
  'Customer request is qualified; management decision is required.'
);
RESET ROLE;

-- A same-tenant but unassigned front-office identity cannot see or take over
-- the governed task and cannot impersonate the handoff recipient.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{"agent_module":"front_office","agent_id":"00000000-0000-4000-8000-00000000c921"}}',
  true
);

DO $contract$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.agent_tasks
    WHERE id = '00000000-0000-4000-8000-00000000f921'
  ) THEN
    RAISE EXCEPTION 'unassigned front component can read governed work';
  END IF;

  BEGIN
    PERFORM public.request_agent_module_handoff(
      '00000000-0000-4000-8000-00000000f921',
      '00000000-0000-4000-8000-00000000b921',
      'management',
      'Impersonated request'
    );
    RAISE EXCEPTION 'unassigned front component requested a handoff';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  BEGIN
    PERFORM public.decide_agent_module_handoff(
      (
        SELECT id
        FROM public.agent_module_handoffs
        WHERE task_id = '00000000-0000-4000-8000-00000000f921'
      ),
      true,
      'Impersonated acceptance'
    );
    RAISE EXCEPTION 'front component accepted a management handoff';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$contract$;
RESET ROLE;

-- Management sees the incoming handoff, not the source task, until its own
-- agent accepts. The RPC transfers assignment and records the decision in one
-- transaction.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{"agent_module":"management","agent_id":"00000000-0000-4000-8000-00000000b921"}}',
  true
);

DO $contract$
DECLARE
  v_handoff_id uuid;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.agent_tasks
    WHERE id = '00000000-0000-4000-8000-00000000f921'
  ) THEN
    RAISE EXCEPTION 'management read source task before accepting handoff';
  END IF;

  SELECT id
    INTO v_handoff_id
  FROM public.agent_module_handoffs
  WHERE task_id = '00000000-0000-4000-8000-00000000f921'
    AND status = 'requested';
  IF v_handoff_id IS NULL THEN
    RAISE EXCEPTION 'management cannot read its requested handoff';
  END IF;

  PERFORM public.decide_agent_module_handoff(
    v_handoff_id,
    true,
    'Accepted for overall management review.'
  );

  IF NOT EXISTS (
    SELECT 1
    FROM public.agent_tasks
    WHERE id = '00000000-0000-4000-8000-00000000f921'
      AND assignee_agent_id = '00000000-0000-4000-8000-00000000b921'
      AND current_module = 'management'
      AND handoff_state = 'accepted'
  ) THEN
    RAISE EXCEPTION 'accepted handoff did not atomically transfer the task';
  END IF;

  UPDATE public.agent_tasks
  SET status = 'completed', title = 'Management decision complete'
  WHERE id = '00000000-0000-4000-8000-00000000f921';
END;
$contract$;
RESET ROLE;

-- The source component loses task access after transfer. A different tenant,
-- even with a correctly shaped management claim, sees nothing.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{"agent_module":"front_office","agent_id":"00000000-0000-4000-8000-00000000a921"}}',
  true
);
DO $contract$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.agent_tasks
    WHERE id = '00000000-0000-4000-8000-00000000f921'
  ) THEN
    RAISE EXCEPTION 'source component retained task access after handoff';
  END IF;
END;
$contract$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002922',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002922","role":"authenticated","app_metadata":{"agent_module":"management","agent_id":"00000000-0000-4000-8000-00000000d921"}}',
  true
);
DO $contract$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.agent_tasks
    WHERE id = '00000000-0000-4000-8000-00000000f921'
  ) OR EXISTS (
    SELECT 1 FROM public.agent_module_handoffs
    WHERE task_id = '00000000-0000-4000-8000-00000000f921'
  ) THEN
    RAISE EXCEPTION 'cross-tenant management component read protected data';
  END IF;
END;
$contract$;
RESET ROLE;

-- Final owner audit proves the handoff and its two append-only events are
-- visible without granting the human token direct governed-task mutation.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002921',
  true
);
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002921","role":"authenticated","app_metadata":{}}',
  true
);
DO $contract$
DECLARE
  v_handoff record;
BEGIN
  SELECT status, from_module, to_module
    INTO v_handoff
  FROM public.agent_module_handoffs
  WHERE task_id = '00000000-0000-4000-8000-00000000f921';
  IF v_handoff.status IS DISTINCT FROM 'accepted'
     OR v_handoff.from_module IS DISTINCT FROM 'front_office'
     OR v_handoff.to_module IS DISTINCT FROM 'management' THEN
    RAISE EXCEPTION 'owner audit has an invalid handoff: %',
      row_to_json(v_handoff);
  END IF;

  IF (
    SELECT count(*)
    FROM public.agent_module_handoff_events
    WHERE task_id = '00000000-0000-4000-8000-00000000f921'
      AND event_type IN ('requested', 'accepted')
  ) <> 2 THEN
    RAISE EXCEPTION 'handoff audit trail is incomplete';
  END IF;
END;
$contract$;
RESET ROLE;

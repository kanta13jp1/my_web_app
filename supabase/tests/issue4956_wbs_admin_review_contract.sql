-- Runtime PostgreSQL contract for Issue #4956. Any mismatch raises and fails
-- the Testcontainers integration smoke.

DO $contract$
DECLARE
  v_policy record;
  v_policy_count integer := 0;
  v_admin_helper_definition text;
  v_admin_helper_is_security_definer boolean;
  v_admin_helper_config text[];
  v_function_definition text;
  v_guard_enabled text;
  v_guard_definition text;
  v_guard_function text;
BEGIN
  IF (
    SELECT count(*)
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN ('wbs_tasks', 'wbs_milestones')
      AND relation.relrowsecurity
  ) <> 2 THEN
    RAISE EXCEPTION 'WBS RLS is not enabled on both managed tables';
  END IF;

  FOR v_policy IN
    SELECT
      tablename,
      roles,
      qual,
      with_check
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
        'wbs_tasks_admin_write',
        'wbs_milestones_admin_write'
      )
    ORDER BY tablename
  LOOP
    v_policy_count := v_policy_count + 1;
    IF v_policy.roles IS DISTINCT FROM ARRAY['authenticated']::name[] THEN
      RAISE EXCEPTION 'unexpected WBS policy roles: %', row_to_json(v_policy);
    END IF;
    IF v_policy.qual NOT LIKE '%is_user_admin%auth.uid%' THEN
      RAISE EXCEPTION 'WBS USING does not use admin helper: %', row_to_json(v_policy);
    END IF;
    IF v_policy.with_check NOT LIKE '%is_user_admin%auth.uid%' THEN
      RAISE EXCEPTION 'WBS WITH CHECK missing: %', row_to_json(v_policy);
    END IF;
    IF v_policy.qual LIKE '%user_profiles%id%' OR
       v_policy.with_check LIKE '%user_profiles%id%' THEN
      RAISE EXCEPTION 'legacy profile id lookup survived: %', row_to_json(v_policy);
    END IF;
  END LOOP;

  IF v_policy_count <> 2 THEN
    RAISE EXCEPTION 'expected two WBS admin policies, found %', v_policy_count;
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_trigger
    WHERE tgrelid = 'public.wbs_tasks'::regclass
      AND NOT tgisinternal
      AND tgname IN (
        'wbs_open_github_issue_completion_guard',
        'wbs_request_ai_review'
      )
  ) <> 2 THEN
    RAISE EXCEPTION 'production WBS review trigger pair is incomplete';
  END IF;

  SELECT
    lower(pg_catalog.pg_get_functiondef(procedure.oid)),
    procedure.prosecdef,
    coalesce(procedure.proconfig, ARRAY[]::text[])
  INTO
    v_admin_helper_definition,
    v_admin_helper_is_security_definer,
    v_admin_helper_config
  FROM pg_catalog.pg_proc AS procedure
  WHERE procedure.oid = 'public.is_user_admin(uuid)'::regprocedure;
  IF v_admin_helper_definition NOT LIKE '%user_id = check_user_id%' THEN
    RAISE EXCEPTION 'admin helper does not use user_profiles.user_id';
  END IF;
  IF NOT v_admin_helper_is_security_definer THEN
    RAISE EXCEPTION 'admin helper is not SECURITY DEFINER';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM unnest(v_admin_helper_config) AS setting
    WHERE setting IN ('search_path=', 'search_path=""')
  ) THEN
    RAISE EXCEPTION 'admin helper search_path is not pinned empty: %',
      v_admin_helper_config;
  END IF;

  SELECT
    trigger.tgenabled,
    lower(pg_catalog.pg_get_triggerdef(trigger.oid)),
    procedure.proname
  INTO v_guard_enabled, v_guard_definition, v_guard_function
  FROM pg_catalog.pg_trigger AS trigger
  JOIN pg_catalog.pg_proc AS procedure
    ON procedure.oid = trigger.tgfoid
  WHERE trigger.tgrelid = 'public.wbs_tasks'::regclass
    AND trigger.tgname = 'wbs_open_github_issue_completion_guard'
    AND NOT trigger.tgisinternal;
  IF NOT FOUND
     OR v_guard_enabled NOT IN ('O', 'A')
     OR v_guard_function IS DISTINCT FROM
       'wbs_guard_open_github_issue_completion'
     OR v_guard_definition NOT LIKE '%before insert or update%'
  THEN
    RAISE EXCEPTION
      'OPEN-Issue guard trigger binding is invalid: enabled=%, function=%, def=%',
      v_guard_enabled,
      v_guard_function,
      v_guard_definition;
  END IF;

  SELECT pg_catalog.pg_get_functiondef(
    'public.wbs_guard_open_github_issue_completion()'::regprocedure
  ) INTO v_function_definition;
  v_function_definition := lower(v_function_definition);
  IF v_function_definition LIKE '%new.ai_review_status := ''manual_override''%' THEN
    RAISE EXCEPTION 'guard assigns manual_override automatically';
  END IF;
  IF v_function_definition LIKE '%new.ai_review_status := ''pending''%' THEN
    RAISE EXCEPTION 'guard still erases requested review state';
  END IF;
END;
$contract$;

-- A real administrator is recognized by user_profiles.user_id even though the
-- profile row id is intentionally different from the auth identity.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004956',
  true
);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

INSERT INTO public.wbs_milestones (code, name, target_date)
VALUES ('issue-4956-admin', 'Issue #4956 admin contract', current_date)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

UPDATE public.wbs_tasks
SET status = 'pending',
    progress = 10,
    ai_review_status = 'requested'
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'in_progress'
     OR v_task.progress IS DISTINCT FROM 100
     OR v_task.ai_review_status IS DISTINCT FROM 'requested' THEN
    RAISE EXCEPTION 'review-ready transition was not preserved: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

-- The production pending/100 path automatically enters review readiness even
-- though the alphabetically earlier OPEN-Issue guard runs first.
UPDATE public.wbs_tasks
SET status = 'pending',
    progress = 0,
    ai_review_status = 'pending'
WHERE id = '00000000-0000-4000-8000-000000024956';

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'pending'
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'in_progress'
     OR v_task.progress IS DISTINCT FROM 100
     OR v_task.ai_review_status IS DISTINCT FROM 'requested' THEN
    RAISE EXCEPTION 'pending review did not auto-request at 100: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

-- A rejected/unapproved completion cannot reuse 100% or become completed.
UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'rejected'
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'in_progress'
     OR v_task.progress IS DISTINCT FROM 99
     OR v_task.ai_review_status IS DISTINCT FROM 'rejected' THEN
    RAISE EXCEPTION 'rejected completion escaped the guard: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

-- Blank and NULL sync states are unsynchronized, not proof of Issue closure.
UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'rejected',
    github_issue_state = '   '
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'in_progress'
     OR v_task.progress IS DISTINCT FROM 99
     OR v_task.ai_review_status IS DISTINCT FROM 'rejected' THEN
    RAISE EXCEPTION 'blank Issue state bypassed completion guard: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'rejected',
    github_issue_state = NULL
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'in_progress'
     OR v_task.progress IS DISTINCT FROM 99
     OR v_task.ai_review_status IS DISTINCT FROM 'rejected' THEN
    RAISE EXCEPTION 'NULL Issue state bypassed completion guard: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

-- An explicitly CLOSED linked Issue is allowed to retain completion even when
-- its previous review state was rejected.
UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'rejected',
    github_issue_state = 'CLOSED'
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'completed'
     OR v_task.progress IS DISTINCT FROM 100
     OR v_task.ai_review_status IS DISTINCT FROM 'rejected' THEN
    RAISE EXCEPTION 'explicitly CLOSED Issue remained blocked: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;

-- manual_override remains possible only as this explicit administrator write.
UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'manual_override',
    github_issue_state = 'OPEN'
WHERE id = '00000000-0000-4000-8000-000000024956';

DO $contract$
DECLARE
  v_task record;
BEGIN
  SELECT status, progress, ai_review_status
    INTO v_task
  FROM public.wbs_tasks
  WHERE id = '00000000-0000-4000-8000-000000024956';
  IF v_task.status IS DISTINCT FROM 'completed'
     OR v_task.progress IS DISTINCT FROM 100
     OR v_task.ai_review_status IS DISTINCT FROM 'manual_override' THEN
    RAISE EXCEPTION 'explicit administrator override was not preserved: %',
      row_to_json(v_task);
  END IF;
END;
$contract$;
RESET ROLE;

-- The non-admin auth identity has a colliding legacy profile id belonging to
-- another admin. It must still be denied because only user_id is authoritative.
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004957',
  true
);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

DO $contract$
BEGIN
  BEGIN
    INSERT INTO public.wbs_tasks (
      id,
      title,
      status,
      owner_instance,
      progress
    ) VALUES (
      '00000000-0000-4000-8000-000000034956',
      'unauthorized WBS task',
      'pending',
      'Codex #1',
      0
    );
    RAISE EXCEPTION 'non-admin task insert unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  BEGIN
    INSERT INTO public.wbs_milestones (code, name, target_date)
    VALUES ('issue-4956-non-admin', 'Unauthorized milestone', current_date);
    RAISE EXCEPTION 'non-admin milestone insert unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$contract$;

DO $contract$
DECLARE
  v_rows bigint;
BEGIN
  UPDATE public.wbs_tasks
  SET title = 'unauthorized overwrite'
  WHERE id = '00000000-0000-4000-8000-000000024956';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'non-admin updated an administrator WBS task';
  END IF;
END;
$contract$;
RESET ROLE;

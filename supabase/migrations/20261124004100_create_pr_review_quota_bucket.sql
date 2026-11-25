-- Batch 100 (#2700): GitHub PR review integration & isolated PR review quota bucket.
-- Keeps PR review quotas completely isolated from general prompt quotas
-- (`user_daily_ai_request_quotas`) and organization general quotas (`organization_quotas`).
-- Exceeding the PR review quota cleanly skips without error and records an audit event.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.pr_review_quota_buckets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_key text NOT NULL CHECK (char_length(btrim(installation_key)) BETWEEN 1 AND 160),
  quota_date date NOT NULL DEFAULT (timezone('UTC', now())::date),
  plan_tier text NOT NULL DEFAULT 'consumer' CHECK (plan_tier IN ('consumer', 'enterprise')),
  pr_review_daily_limit integer NOT NULL DEFAULT 33 CHECK (pr_review_daily_limit > 0),
  pr_reviews_used integer NOT NULL DEFAULT 0 CHECK (pr_reviews_used >= 0),
  pr_review_model_calls_used integer NOT NULL DEFAULT 0 CHECK (pr_review_model_calls_used >= 0),
  pr_reviews_skipped integer NOT NULL DEFAULT 0 CHECK (pr_reviews_skipped >= 0),
  last_skipped_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_pr_review_quota_bucket_day UNIQUE (owner_user_id, installation_key, quota_date)
);

CREATE TABLE IF NOT EXISTS public.pr_review_quota_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id uuid REFERENCES public.pr_review_quota_buckets(id) ON DELETE CASCADE,
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_key text NOT NULL CHECK (char_length(btrim(installation_key)) BETWEEN 1 AND 160),
  repository text NOT NULL CHECK (char_length(btrim(repository)) BETWEEN 1 AND 200),
  pr_number integer NOT NULL CHECK (pr_number > 0),
  head_sha text NOT NULL DEFAULT '' CHECK (char_length(head_sha) <= 64),
  delivery_id text NOT NULL DEFAULT '' CHECK (char_length(delivery_id) <= 128),
  outcome text NOT NULL CHECK (
    outcome IN ('reviewed', 'skipped_quota_exceeded', 'dry_run', 'async_reconciled')
  ),
  model_calls_estimated integer NOT NULL DEFAULT 1 CHECK (model_calls_estimated >= 0),
  model_calls_actual integer CHECK (model_calls_actual IS NULL OR model_calls_actual >= 0),
  skip_reason text NOT NULL DEFAULT '' CHECK (char_length(skip_reason) <= 300),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_pr_review_quota_buckets_owner_date
  ON public.pr_review_quota_buckets (owner_user_id, quota_date DESC);

CREATE INDEX IF NOT EXISTS idx_pr_review_quota_events_owner_pr
  ON public.pr_review_quota_events (owner_user_id, repository, pr_number, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pr_review_quota_events_outcome_time
  ON public.pr_review_quota_events (outcome, created_at DESC);

ALTER TABLE public.pr_review_quota_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pr_review_quota_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.pr_review_quota_buckets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.pr_review_quota_buckets TO authenticated;
GRANT ALL ON TABLE public.pr_review_quota_buckets TO service_role;

REVOKE ALL ON TABLE public.pr_review_quota_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.pr_review_quota_events TO authenticated;
GRANT ALL ON TABLE public.pr_review_quota_events TO service_role;

DROP POLICY IF EXISTS pr_review_quota_buckets_select_own ON public.pr_review_quota_buckets;
CREATE POLICY pr_review_quota_buckets_select_own
  ON public.pr_review_quota_buckets
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS pr_review_quota_buckets_insert_own ON public.pr_review_quota_buckets;
DROP POLICY IF EXISTS pr_review_quota_buckets_update_own ON public.pr_review_quota_buckets;

DROP POLICY IF EXISTS pr_review_quota_events_select_own ON public.pr_review_quota_events;
CREATE POLICY pr_review_quota_events_select_own
  ON public.pr_review_quota_events
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS pr_review_quota_events_insert_own ON public.pr_review_quota_events;

CREATE OR REPLACE FUNCTION public._pr_review_quota_is_service_role()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
BEGIN
  IF v_claims_raw IS NOT NULL AND length(trim(v_claims_raw)) > 0 THEN
    BEGIN
      v_claims := v_claims_raw::jsonb;
    EXCEPTION
      WHEN OTHERS THEN
        v_claims := '{}'::jsonb;
    END;
  END IF;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  RETURN (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public._pr_review_quota_is_service_role() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.guard_pr_review_quota_bucket()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $guard$
BEGIN
  IF NOT public._pr_review_quota_is_service_role() THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for pr_review_quota_buckets'
        USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'INSERT' THEN
      RAISE EXCEPTION 'Direct insert to pr_review_quota_buckets requires service_role'
        USING ERRCODE = '42501';
    ELSIF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.quota_date IS DISTINCT FROM OLD.quota_date
       OR NEW.plan_tier IS DISTINCT FROM OLD.plan_tier
       OR NEW.pr_review_daily_limit IS DISTINCT FROM OLD.pr_review_daily_limit
       OR NEW.pr_reviews_used IS DISTINCT FROM OLD.pr_reviews_used
       OR NEW.pr_review_model_calls_used IS DISTINCT FROM OLD.pr_review_model_calls_used
       OR NEW.pr_reviews_skipped IS DISTINCT FROM OLD.pr_reviews_skipped
       OR NEW.last_skipped_at IS DISTINCT FROM OLD.last_skipped_at THEN
      RAISE EXCEPTION 'Protected quota bucket columns cannot be modified directly'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_at := coalesce(NEW.created_at, timezone('utc', now()));
  END IF;
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$guard$;

REVOKE ALL ON FUNCTION public.guard_pr_review_quota_bucket() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_pr_review_quota_bucket ON public.pr_review_quota_buckets;
CREATE TRIGGER trg_guard_pr_review_quota_bucket
  BEFORE INSERT OR UPDATE ON public.pr_review_quota_buckets
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_pr_review_quota_bucket();

CREATE OR REPLACE FUNCTION public.claim_or_skip_pr_review_quota(
  p_owner_user_id uuid,
  p_installation_key text,
  p_repository text,
  p_pr_number integer,
  p_head_sha text DEFAULT '',
  p_delivery_id text DEFAULT '',
  p_plan_tier text DEFAULT 'consumer',
  p_daily_limit integer DEFAULT NULL,
  p_estimated_model_calls integer DEFAULT 1,
  p_dry_run boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_is_service boolean := public._pr_review_quota_is_service_role();
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_plan text := lower(trim(coalesce(p_plan_tier, 'consumer')));
  v_limit integer;
  v_today date := timezone('UTC', now())::date;
  v_install text := left(trim(coalesce(p_installation_key, '')), 160);
  v_repo text := left(trim(coalesce(p_repository, '')), 200);
  v_calls integer := greatest(0, least(coalesce(p_estimated_model_calls, 1), 100));
  v_bucket public.pr_review_quota_buckets;
  v_next_used integer;
  v_skip_reason text;
BEGIN
  IF NOT v_is_service THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'Authentication required'
        USING ERRCODE = '42501';
    END IF;
    v_owner := v_uid;
  ELSE
    v_owner := coalesce(p_owner_user_id, v_uid);
  END IF;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'owner_user_id is required'
      USING ERRCODE = '22023';
  END IF;
  IF v_install = '' OR v_repo = '' OR p_pr_number IS NULL OR p_pr_number <= 0 THEN
    RAISE EXCEPTION 'installation_key, repository, and positive pr_number are required'
      USING ERRCODE = '22023';
  END IF;
  IF NOT v_is_service THEN
    v_plan := 'consumer';
    v_limit := 33;
  ELSE
    IF v_plan NOT IN ('consumer', 'enterprise') THEN
      v_plan := 'consumer';
    END IF;
    v_limit := coalesce(
      CASE WHEN p_daily_limit IS NOT NULL AND p_daily_limit > 0 THEN p_daily_limit ELSE NULL END,
      CASE WHEN v_plan = 'enterprise' THEN 100 ELSE 33 END
    );
  END IF;

  INSERT INTO public.pr_review_quota_buckets (
    owner_user_id,
    installation_key,
    quota_date,
    plan_tier,
    pr_review_daily_limit
  ) VALUES (
    v_owner,
    v_install,
    v_today,
    v_plan,
    v_limit
  )
  ON CONFLICT (owner_user_id, installation_key, quota_date) DO NOTHING;

  SELECT *
  INTO v_bucket
  FROM public.pr_review_quota_buckets
  WHERE owner_user_id = v_owner
    AND installation_key = v_install
    AND quota_date = v_today
  FOR UPDATE;

  IF p_dry_run THEN
    INSERT INTO public.pr_review_quota_events (
      bucket_id,
      owner_user_id,
      installation_key,
      repository,
      pr_number,
      head_sha,
      delivery_id,
      outcome,
      model_calls_estimated,
      metadata
    ) VALUES (
      v_bucket.id,
      v_owner,
      v_install,
      v_repo,
      p_pr_number,
      left(coalesce(p_head_sha, ''), 64),
      left(coalesce(p_delivery_id, ''), 128),
      'dry_run',
      v_calls,
      jsonb_build_object('plan_tier', v_bucket.plan_tier, 'isolated_from_general_quota', true)
    );

    RETURN jsonb_build_object(
      'allowed', v_bucket.pr_reviews_used < v_bucket.pr_review_daily_limit,
      'skipped', v_bucket.pr_reviews_used >= v_bucket.pr_review_daily_limit,
      'status', 'dry_run',
      'http_status', 200,
      'quota_date', v_today,
      'plan_tier', v_bucket.plan_tier,
      'pr_reviews_used', v_bucket.pr_reviews_used,
      'pr_review_daily_limit', v_bucket.pr_review_daily_limit,
      'remaining', greatest(0, v_bucket.pr_review_daily_limit - v_bucket.pr_reviews_used),
      'pr_review_model_calls_used', v_bucket.pr_review_model_calls_used,
      'isolated_from_general_quota', true
    );
  END IF;

  IF v_bucket.pr_reviews_used + 1 > v_bucket.pr_review_daily_limit THEN
    v_skip_reason := format(
      'PR review daily quota reached (%s/%s for %s on %s); skipped cleanly without failing PR.',
      v_bucket.pr_reviews_used,
      v_bucket.pr_review_daily_limit,
      v_bucket.plan_tier,
      v_today
    );

    UPDATE public.pr_review_quota_buckets
    SET pr_reviews_skipped = pr_reviews_skipped + 1,
        last_skipped_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    WHERE id = v_bucket.id
    RETURNING * INTO v_bucket;

    INSERT INTO public.pr_review_quota_events (
      bucket_id,
      owner_user_id,
      installation_key,
      repository,
      pr_number,
      head_sha,
      delivery_id,
      outcome,
      model_calls_estimated,
      skip_reason,
      metadata
    ) VALUES (
      v_bucket.id,
      v_owner,
      v_install,
      v_repo,
      p_pr_number,
      left(coalesce(p_head_sha, ''), 64),
      left(coalesce(p_delivery_id, ''), 128),
      'skipped_quota_exceeded',
      v_calls,
      v_skip_reason,
      jsonb_build_object(
        'plan_tier', v_bucket.plan_tier,
        'pr_reviews_used', v_bucket.pr_reviews_used,
        'pr_review_daily_limit', v_bucket.pr_review_daily_limit,
        'isolated_from_general_quota', true
      )
    );

    RETURN jsonb_build_object(
      'allowed', false,
      'skipped', true,
      'status', 'skipped_quota_exceeded',
      'http_status', 200,
      'skip_reason', v_skip_reason,
      'quota_date', v_today,
      'plan_tier', v_bucket.plan_tier,
      'pr_reviews_used', v_bucket.pr_reviews_used,
      'pr_review_daily_limit', v_bucket.pr_review_daily_limit,
      'remaining', 0,
      'pr_reviews_skipped', v_bucket.pr_reviews_skipped,
      'pr_review_model_calls_used', v_bucket.pr_review_model_calls_used,
      'isolated_from_general_quota', true
    );
  END IF;

  v_next_used := v_bucket.pr_reviews_used + 1;
  UPDATE public.pr_review_quota_buckets
  SET pr_reviews_used = v_next_used,
      pr_review_model_calls_used = pr_review_model_calls_used + v_calls,
      updated_at = timezone('utc', now())
  WHERE id = v_bucket.id
  RETURNING * INTO v_bucket;

  INSERT INTO public.pr_review_quota_events (
    bucket_id,
    owner_user_id,
    installation_key,
    repository,
    pr_number,
    head_sha,
    delivery_id,
    outcome,
    model_calls_estimated,
    metadata
  ) VALUES (
    v_bucket.id,
    v_owner,
    v_install,
    v_repo,
    p_pr_number,
    left(coalesce(p_head_sha, ''), 64),
    left(coalesce(p_delivery_id, ''), 128),
    'reviewed',
    v_calls,
    jsonb_build_object('plan_tier', v_bucket.plan_tier, 'isolated_from_general_quota', true)
  );

  RETURN jsonb_build_object(
    'allowed', true,
    'skipped', false,
    'status', 'reviewed',
    'http_status', 200,
    'quota_date', v_today,
    'plan_tier', v_bucket.plan_tier,
    'pr_reviews_used', v_bucket.pr_reviews_used,
    'pr_review_daily_limit', v_bucket.pr_review_daily_limit,
    'remaining', greatest(0, v_bucket.pr_review_daily_limit - v_bucket.pr_reviews_used),
    'pr_reviews_skipped', v_bucket.pr_reviews_skipped,
    'pr_review_model_calls_used', v_bucket.pr_review_model_calls_used,
    'isolated_from_general_quota', true
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.claim_or_skip_pr_review_quota(uuid, text, text, integer, text, text, text, integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_or_skip_pr_review_quota(uuid, text, text, integer, text, text, text, integer, integer, boolean) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.reconcile_pr_review_model_calls(
  p_owner_user_id uuid,
  p_installation_key text,
  p_repository text,
  p_pr_number integer,
  p_actual_model_calls integer,
  p_estimated_model_calls integer DEFAULT 1,
  p_head_sha text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_is_service boolean := public._pr_review_quota_is_service_role();
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_today date := timezone('UTC', now())::date;
  v_install text := left(trim(coalesce(p_installation_key, '')), 160);
  v_repo text := left(trim(coalesce(p_repository, '')), 200);
  v_actual integer := greatest(0, least(coalesce(p_actual_model_calls, 0), 200));
  v_est integer := greatest(0, least(coalesce(p_estimated_model_calls, 1), 100));
  v_delta integer := v_actual - v_est;
  v_bucket public.pr_review_quota_buckets;
BEGIN
  IF NOT v_is_service THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'Authentication required'
        USING ERRCODE = '42501';
    END IF;
    v_owner := v_uid;
  ELSE
    v_owner := coalesce(p_owner_user_id, v_uid);
  END IF;

  IF v_owner IS NULL OR v_install = '' OR v_repo = '' OR p_pr_number IS NULL OR p_pr_number <= 0 THEN
    RAISE EXCEPTION 'Invalid reconcile_pr_review_model_calls arguments'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.pr_review_quota_buckets
  SET pr_review_model_calls_used = greatest(0, pr_review_model_calls_used + v_delta),
      updated_at = timezone('utc', now())
  WHERE owner_user_id = v_owner
    AND installation_key = v_install
    AND quota_date = v_today
  RETURNING * INTO v_bucket;

  IF v_bucket.id IS NULL THEN
    RETURN jsonb_build_object(
      'reconciled', false,
      'reason', 'bucket_not_found',
      'quota_date', v_today
    );
  END IF;

  INSERT INTO public.pr_review_quota_events (
    bucket_id,
    owner_user_id,
    installation_key,
    repository,
    pr_number,
    head_sha,
    outcome,
    model_calls_estimated,
    model_calls_actual,
    metadata
  ) VALUES (
    v_bucket.id,
    v_owner,
    v_install,
    v_repo,
    p_pr_number,
    left(coalesce(p_head_sha, ''), 64),
    'async_reconciled',
    v_est,
    v_actual,
    jsonb_build_object('delta_model_calls', v_delta, 'isolated_from_general_quota', true)
  );

  RETURN jsonb_build_object(
    'reconciled', true,
    'quota_date', v_today,
    'delta_model_calls', v_delta,
    'pr_review_model_calls_used', v_bucket.pr_review_model_calls_used,
    'isolated_from_general_quota', true
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.reconcile_pr_review_model_calls(uuid, text, text, integer, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_pr_review_model_calls(uuid, text, text, integer, integer, integer, text) TO authenticated, service_role;

COMMENT ON TABLE public.pr_review_quota_buckets IS
  'Daily PR review quota consumption isolated from general prompt/IDE quotas (#2700).';

COMMENT ON TABLE public.pr_review_quota_events IS
  'Audit log of PR review executions, quota-exceeded clean skips, and async model-call reconciliations (#2700).';

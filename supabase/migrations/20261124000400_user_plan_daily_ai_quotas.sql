-- Per-user plan-based daily AI request quota management (#2699)
-- Provides configurable per-plan daily limits, atomic transactional claim RPC,
-- read-only quota status lookup, and daily scheduled reset via pg_cron.

CREATE TABLE IF NOT EXISTS public.ai_plan_daily_limits (
  plan text PRIMARY KEY,
  daily_request_limit integer NOT NULL CHECK (daily_request_limit > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_plan_daily_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_plan_daily_limits_read_authenticated ON public.ai_plan_daily_limits;
CREATE POLICY ai_plan_daily_limits_read_authenticated ON public.ai_plan_daily_limits
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS ai_plan_daily_limits_service_write ON public.ai_plan_daily_limits;
CREATE POLICY ai_plan_daily_limits_service_write ON public.ai_plan_daily_limits
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

INSERT INTO public.ai_plan_daily_limits (plan, daily_request_limit)
VALUES
  ('free', 50),
  ('pro', 1000),
  ('premium', 1500),
  ('team', 2000),
  ('enterprise', 2000)
ON CONFLICT (plan) DO UPDATE
  SET daily_request_limit = EXCLUDED.daily_request_limit,
      updated_at = now();

CREATE TABLE IF NOT EXISTS public.user_daily_ai_request_quotas (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quota_date date NOT NULL,
  plan text NOT NULL DEFAULT 'free',
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, quota_date)
);

CREATE INDEX IF NOT EXISTS user_daily_ai_request_quotas_date_idx
  ON public.user_daily_ai_request_quotas (quota_date);

ALTER TABLE public.user_daily_ai_request_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_daily_ai_request_quotas_owner_select ON public.user_daily_ai_request_quotas;
CREATE POLICY user_daily_ai_request_quotas_owner_select ON public.user_daily_ai_request_quotas
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS user_daily_ai_request_quotas_service_write ON public.user_daily_ai_request_quotas;
CREATE POLICY user_daily_ai_request_quotas_service_write ON public.user_daily_ai_request_quotas
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public._resolve_user_ai_plan(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_plan text;
BEGIN
  SELECT NULLIF(lower(trim(tier)), '')
  INTO v_plan
  FROM public.billing_subscriptions
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_plan IS NULL THEN
    SELECT NULLIF(lower(trim(subscription_plan)), '')
    INTO v_plan
    FROM public.user_profiles
    WHERE user_id = p_user_id
    LIMIT 1;
  END IF;

  RETURN COALESCE(v_plan, 'free');
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_user_daily_ai_quota(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_quota_date date := (timezone('Asia/Tokyo', now()))::date;
  v_reset_at timestamptz := (((timezone('Asia/Tokyo', now()))::date + 1)::timestamp AT TIME ZONE 'Asia/Tokyo');
  v_plan text := 'free';
  v_limit integer := 50;
  v_used integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  v_plan := public._resolve_user_ai_plan(p_user_id);

  SELECT daily_request_limit
  INTO v_limit
  FROM public.ai_plan_daily_limits
  WHERE plan = v_plan
  LIMIT 1;

  IF v_limit IS NULL THEN
    SELECT daily_request_limit INTO v_limit
    FROM public.ai_plan_daily_limits
    WHERE plan = 'free'
    LIMIT 1;
    v_limit := COALESCE(v_limit, 50);
  END IF;

  INSERT INTO public.user_daily_ai_request_quotas (
    user_id,
    quota_date,
    plan,
    request_count,
    updated_at
  )
  VALUES (p_user_id, v_quota_date, v_plan, 0, now())
  ON CONFLICT (user_id, quota_date) DO UPDATE
    SET plan = EXCLUDED.plan;

  UPDATE public.user_daily_ai_request_quotas
  SET request_count = request_count + 1,
      plan = v_plan,
      updated_at = now()
  WHERE user_id = p_user_id
    AND quota_date = v_quota_date
    AND request_count < v_limit
  RETURNING request_count INTO v_used;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'reason', null,
      'plan', v_plan,
      'used', v_used,
      'daily_limit', v_limit,
      'remaining', GREATEST(v_limit - v_used, 0),
      'quota_date', v_quota_date::text,
      'reset_at', v_reset_at
    );
  END IF;

  SELECT request_count
  INTO v_used
  FROM public.user_daily_ai_request_quotas
  WHERE user_id = p_user_id
    AND quota_date = v_quota_date;

  RETURN jsonb_build_object(
    'allowed', false,
    'reason', 'daily_limit',
    'plan', v_plan,
    'used', COALESCE(v_used, v_limit),
    'daily_limit', v_limit,
    'remaining', 0,
    'quota_date', v_quota_date::text,
    'reset_at', v_reset_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_daily_ai_quota_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_quota_date date := (timezone('Asia/Tokyo', now()))::date;
  v_reset_at timestamptz := (((timezone('Asia/Tokyo', now()))::date + 1)::timestamp AT TIME ZONE 'Asia/Tokyo');
  v_plan text := 'free';
  v_limit integer := 50;
  v_used integer := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  v_plan := public._resolve_user_ai_plan(p_user_id);

  SELECT daily_request_limit
  INTO v_limit
  FROM public.ai_plan_daily_limits
  WHERE plan = v_plan
  LIMIT 1;
  v_limit := COALESCE(v_limit, 50);

  SELECT COALESCE(request_count, 0)
  INTO v_used
  FROM public.user_daily_ai_request_quotas
  WHERE user_id = p_user_id
    AND quota_date = v_quota_date;
  v_used := COALESCE(v_used, 0);

  RETURN jsonb_build_object(
    'allowed', v_used < v_limit,
    'reason', CASE WHEN v_used >= v_limit THEN 'daily_limit' ELSE null END,
    'plan', v_plan,
    'used', v_used,
    'daily_limit', v_limit,
    'remaining', GREATEST(v_limit - v_used, 0),
    'quota_date', v_quota_date::text,
    'reset_at', v_reset_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_daily_ai_request_quotas(
  p_target_date date DEFAULT (timezone('Asia/Tokyo', now()))::date
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_deleted_count integer := 0;
BEGIN
  DELETE FROM public.user_daily_ai_request_quotas
  WHERE quota_date < (p_target_date - 30);

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public._resolve_user_ai_plan(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_user_daily_ai_quota(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_daily_ai_quota_status(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reset_daily_ai_request_quotas(date) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_user_daily_ai_quota(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_daily_ai_quota_status(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.reset_daily_ai_request_quotas(date) TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'daily-ai-quota-reset';

    PERFORM cron.schedule(
      'daily-ai-quota-reset',
      '0 15 * * *',
      'SELECT public.reset_daily_ai_request_quotas();'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

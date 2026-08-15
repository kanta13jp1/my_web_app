-- Bound the public landing-page AI trial without retaining raw client addresses.
CREATE TABLE IF NOT EXISTS public.landing_trial_ai_quota (
  quota_date date NOT NULL,
  client_hash text NOT NULL CHECK (client_hash ~ '^[0-9a-f]{64}$'),
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  last_requested_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (quota_date, client_hash)
);

ALTER TABLE public.landing_trial_ai_quota ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.landing_trial_ai_quota
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.landing_trial_ai_quota
  TO service_role;

CREATE OR REPLACE FUNCTION public.claim_landing_trial_ai_quota(
  p_client_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_quota_date date := (timezone('Asia/Tokyo', now()))::date;
  v_client_limit constant integer := 3;
  v_global_limit constant integer := 100;
  v_client_count integer := 0;
  v_global_count integer := 0;
BEGIN
  IF p_client_hash IS NULL OR p_client_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid landing trial client hash';
  END IF;

  -- Serialize quota claims for the day so concurrent requests cannot overshoot.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('landing_trial_ai:' || v_quota_date::text, 0)
  );

  DELETE FROM public.landing_trial_ai_quota
  WHERE quota_date < v_quota_date - 31;

  SELECT request_count
  INTO v_client_count
  FROM public.landing_trial_ai_quota
  WHERE quota_date = v_quota_date
    AND client_hash = p_client_hash;

  v_client_count := COALESCE(v_client_count, 0);

  SELECT COALESCE(sum(request_count), 0)::integer
  INTO v_global_count
  FROM public.landing_trial_ai_quota
  WHERE quota_date = v_quota_date;

  IF v_client_count >= v_client_limit OR v_global_count >= v_global_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'client_count', v_client_count,
      'global_count', v_global_count,
      'remaining_client', GREATEST(v_client_limit - v_client_count, 0),
      'remaining_global', GREATEST(v_global_limit - v_global_count, 0)
    );
  END IF;

  INSERT INTO public.landing_trial_ai_quota AS quota (
    quota_date,
    client_hash,
    request_count,
    last_requested_at
  )
  VALUES (
    v_quota_date,
    p_client_hash,
    1,
    now()
  )
  ON CONFLICT (quota_date, client_hash) DO UPDATE
  SET
    request_count = quota.request_count + 1,
    last_requested_at = now()
  RETURNING request_count INTO v_client_count;

  v_global_count := v_global_count + 1;

  RETURN jsonb_build_object(
    'allowed', true,
    'client_count', v_client_count,
    'global_count', v_global_count,
    'remaining_client', GREATEST(v_client_limit - v_client_count, 0),
    'remaining_global', GREATEST(v_global_limit - v_global_count, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_landing_trial_ai_quota(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_landing_trial_ai_quota(text)
  TO service_role;

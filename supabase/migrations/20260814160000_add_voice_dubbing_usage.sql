-- Character-metered ElevenLabs dubbing with private user-owned audio storage.
-- nocheck: time-relative — the guard parses the schema qualifier in
-- UPDATE public.billing_usage_counters as the table name; this table has no
-- time-relative enforcement trigger.

ALTER TABLE public.billing_usage_counters
  ADD COLUMN IF NOT EXISTS voice_character_count bigint NOT NULL DEFAULT 0
  CHECK (voice_character_count >= 0);

ALTER TABLE public.billing_usage_counters
  ADD COLUMN IF NOT EXISTS voice_generation_count integer NOT NULL DEFAULT 0
  CHECK (voice_generation_count >= 0);

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'voice-dubbing',
  'voice-dubbing',
  false,
  104857600,
  ARRAY['audio/mpeg']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS voice_dubbing_owner_read ON storage.objects;
CREATE POLICY voice_dubbing_owner_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'voice-dubbing'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE TABLE IF NOT EXISTS public.voice_dubbing_jobs (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  request_hash text NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  period_start date NOT NULL,
  status text NOT NULL DEFAULT 'reserved'
    CHECK (status IN ('reserved', 'processing', 'completed', 'failed', 'expired')),
  reserved_characters integer NOT NULL CHECK (reserved_characters > 0),
  started_characters integer NOT NULL DEFAULT 0 CHECK (started_characters >= 0),
  billed_characters integer NOT NULL DEFAULT 0 CHECK (billed_characters >= 0),
  released_characters integer NOT NULL DEFAULT 0 CHECK (released_characters >= 0),
  result jsonb,
  error_code text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, request_id),
  CHECK (started_characters <= reserved_characters),
  CHECK (billed_characters <= started_characters),
  CHECK (billed_characters + released_characters <= reserved_characters),
  CHECK (
    status NOT IN ('completed', 'failed', 'expired')
    OR billed_characters + released_characters = reserved_characters
  ),
  CHECK (
    status <> 'completed'
    OR (
      result IS NOT NULL
      AND started_characters = reserved_characters
      AND billed_characters = reserved_characters
      AND released_characters = 0
    )
  )
);

CREATE INDEX IF NOT EXISTS voice_dubbing_jobs_expiry_idx
  ON public.voice_dubbing_jobs (user_id, status, expires_at);

ALTER TABLE public.voice_dubbing_jobs ENABLE ROW LEVEL SECURITY;

-- No client policy is intentional. Jobs contain provider/billing state and are
-- accessed only through the authenticated Edge Function using service_role.
REVOKE ALL ON TABLE public.voice_dubbing_jobs
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.voice_dubbing_jobs TO service_role;

CREATE OR REPLACE FUNCTION public.reconcile_voice_dubbing_quota(
  p_user_id uuid
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recovered bigint := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'invalid voice dubbing reconciliation';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('voice_dubbing:' || p_user_id::text, 0)
  );

  WITH expired AS (
    UPDATE public.voice_dubbing_jobs
    SET status = 'expired',
        billed_characters = started_characters,
        released_characters = released_characters +
          (reserved_characters - started_characters),
        updated_at = pg_catalog.now()
    WHERE user_id = p_user_id
      AND status IN ('reserved', 'processing')
      AND expires_at < pg_catalog.now()
    RETURNING period_start,
      reserved_characters - started_characters AS recoverable
  ), released AS (
    SELECT period_start, pg_catalog.sum(recoverable) AS recoverable
    FROM expired
    GROUP BY period_start
  ), applied AS (
    UPDATE public.billing_usage_counters AS counters
    SET voice_character_count = greatest(
        counters.voice_character_count - released.recoverable,
        0
      )
    FROM released
    WHERE counters.user_id = p_user_id
      AND counters.period_start = released.period_start
    RETURNING released.recoverable
  )
  SELECT coalesce(pg_catalog.sum(recoverable), 0)
  INTO v_recovered
  FROM applied;

  RETURN v_recovered;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_voice_character_quota(
  p_user_id uuid,
  p_request_id uuid,
  p_request_hash text,
  p_characters integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_period_start date := pg_catalog.date_trunc(
    'month',
    pg_catalog.timezone('UTC', pg_catalog.now())
  )::date;
  v_tier text := 'free';
  v_limit bigint := 5000;
  v_generation_limit integer := 100;
  v_used bigint := 0;
  v_generation_count integer := 0;
  v_existing public.voice_dubbing_jobs%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_request_id IS NULL OR p_characters IS NULL
    OR p_characters <= 0 OR p_characters > 40000
    OR p_request_hash IS NULL OR p_request_hash !~ '^[0-9a-f]{64}$'
  THEN
    RAISE EXCEPTION 'invalid voice character quota claim';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('voice_dubbing:' || p_user_id::text, 0)
  );

  SELECT CASE
    WHEN status IN ('active', 'trialing') THEN tier
    ELSE 'free'
  END
  INTO v_tier
  FROM public.billing_subscriptions
  WHERE user_id = p_user_id;

  v_tier := coalesce(v_tier, 'free');
  v_limit := CASE v_tier
    WHEN 'team' THEN 300000
    WHEN 'pro' THEN 100000
    ELSE 5000
  END;
  v_generation_limit := CASE v_tier
    WHEN 'team' THEN 3000
    WHEN 'pro' THEN 1000
    ELSE 100
  END;

  INSERT INTO public.billing_usage_counters (user_id, period_start)
  VALUES (p_user_id, v_period_start)
  ON CONFLICT (user_id, period_start) DO NOTHING;

  PERFORM public.reconcile_voice_dubbing_quota(p_user_id);

  SELECT *
  INTO v_existing
  FROM public.voice_dubbing_jobs
  WHERE user_id = p_user_id AND request_id = p_request_id;

  IF FOUND THEN
    IF v_existing.request_hash <> p_request_hash THEN
      RETURN pg_catalog.jsonb_build_object(
        'allowed', false,
        'reason', 'idempotency_conflict'
      );
    END IF;
    IF v_existing.status = 'completed' THEN
      RETURN pg_catalog.jsonb_build_object(
        'allowed', true,
        'replayed', true,
        'job_status', v_existing.status,
        'result', v_existing.result
      );
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'allowed', false,
      'reason', CASE
        WHEN v_existing.status IN ('reserved', 'processing')
          THEN 'request_in_progress'
        ELSE 'retry_with_new_request_id'
      END,
      'job_status', v_existing.status
    );
  END IF;

  SELECT voice_character_count, voice_generation_count
  INTO v_used, v_generation_count
  FROM public.billing_usage_counters
  WHERE user_id = p_user_id AND period_start = v_period_start
  FOR UPDATE;

  IF v_used + p_characters > v_limit
    OR v_generation_count + 1 > v_generation_limit
  THEN
    RETURN pg_catalog.jsonb_build_object(
      'allowed', false,
      'tier', v_tier,
      'used', v_used,
      'limit', v_limit,
      'remaining', greatest(v_limit - v_used, 0),
      'generation_count', v_generation_count,
      'generation_limit', v_generation_limit,
      'period_start', v_period_start,
      'reason', CASE
        WHEN v_used + p_characters > v_limit
          THEN 'voice_character_limit_reached'
        ELSE 'voice_generation_limit_reached'
      END
    );
  END IF;

  UPDATE public.billing_usage_counters
  SET voice_character_count = voice_character_count + p_characters,
      voice_generation_count = voice_generation_count + 1
  WHERE user_id = p_user_id AND period_start = v_period_start
  RETURNING voice_character_count, voice_generation_count
  INTO v_used, v_generation_count;

  INSERT INTO public.voice_dubbing_jobs (
    user_id,
    request_id,
    request_hash,
    period_start,
    reserved_characters,
    expires_at
  ) VALUES (
    p_user_id,
    p_request_id,
    p_request_hash,
    v_period_start,
    p_characters,
    pg_catalog.now() + interval '15 minutes'
  );

  RETURN pg_catalog.jsonb_build_object(
    'allowed', true,
    'replayed', false,
    'job_status', 'reserved',
    'tier', v_tier,
    'used', v_used,
    'limit', v_limit,
    'remaining', greatest(v_limit - v_used, 0),
    'generation_count', v_generation_count,
    'generation_limit', v_generation_limit,
    'period_start', v_period_start
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_voice_dubbing_chunk(
  p_user_id uuid,
  p_request_id uuid,
  p_characters integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL OR p_request_id IS NULL OR p_characters IS NULL
    OR p_characters <= 0
  THEN
    RAISE EXCEPTION 'invalid voice dubbing chunk start';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('voice_dubbing:' || p_user_id::text, 0)
  );

  UPDATE public.voice_dubbing_jobs
  SET status = 'processing',
      started_characters = started_characters + p_characters,
      expires_at = pg_catalog.now() + interval '15 minutes',
      updated_at = pg_catalog.now()
  WHERE user_id = p_user_id
    AND request_id = p_request_id
    AND status IN ('reserved', 'processing')
    AND started_characters + p_characters <= reserved_characters;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'voice dubbing job is not startable';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_voice_dubbing_job(
  p_user_id uuid,
  p_request_id uuid,
  p_status text,
  p_billed_characters integer,
  p_result jsonb DEFAULT NULL,
  p_error_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job public.voice_dubbing_jobs%ROWTYPE;
  v_release integer := 0;
BEGIN
  IF p_user_id IS NULL OR p_request_id IS NULL
    OR p_status IS NULL OR p_status NOT IN ('completed', 'failed')
    OR p_billed_characters IS NULL OR p_billed_characters < 0
  THEN
    RAISE EXCEPTION 'invalid voice dubbing completion';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('voice_dubbing:' || p_user_id::text, 0)
  );

  SELECT *
  INTO v_job
  FROM public.voice_dubbing_jobs
  WHERE user_id = p_user_id AND request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'voice dubbing job not found';
  END IF;

  IF v_job.status IN ('completed', 'failed', 'expired') THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', v_job.status,
      'idempotent', v_job.status = p_status,
      'terminal_conflict', v_job.status <> p_status,
      'released_characters', v_job.released_characters,
      'result', v_job.result
    );
  END IF;

  IF p_billed_characters > v_job.started_characters THEN
    RAISE EXCEPTION 'billed characters exceed started characters';
  END IF;

  v_release := v_job.reserved_characters - p_billed_characters;

  UPDATE public.billing_usage_counters
  SET voice_character_count = greatest(
    voice_character_count - v_release,
    0
  )
  WHERE user_id = p_user_id AND period_start = v_job.period_start;

  UPDATE public.voice_dubbing_jobs
  SET status = p_status,
      billed_characters = p_billed_characters,
      released_characters = v_release,
      result = CASE WHEN p_status = 'completed' THEN p_result ELSE NULL END,
      error_code = CASE WHEN p_status = 'failed' THEN p_error_code ELSE NULL END,
      updated_at = pg_catalog.now()
  WHERE user_id = p_user_id AND request_id = p_request_id;

  RETURN pg_catalog.jsonb_build_object(
    'status', p_status,
    'idempotent', false,
    'terminal_conflict', false,
    'released_characters', v_release,
    'result', CASE WHEN p_status = 'completed' THEN p_result ELSE NULL END
  );
END;
$$;

DROP FUNCTION IF EXISTS public.claim_voice_character_quota(uuid, integer);
DROP FUNCTION IF EXISTS public.release_voice_character_quota(uuid, integer);
DROP FUNCTION IF EXISTS public.release_voice_character_quota(uuid, date, integer);

REVOKE ALL ON FUNCTION public.claim_voice_character_quota(uuid, uuid, text, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reconcile_voice_dubbing_quota(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.start_voice_dubbing_chunk(uuid, uuid, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_voice_dubbing_job(uuid, uuid, text, integer, jsonb, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_voice_character_quota(uuid, uuid, text, integer)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_voice_dubbing_quota(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.start_voice_dubbing_chunk(uuid, uuid, integer)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_voice_dubbing_job(uuid, uuid, text, integer, jsonb, text)
  TO service_role;

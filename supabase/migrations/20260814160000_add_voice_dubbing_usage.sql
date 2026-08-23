-- Character-metered ElevenLabs dubbing with private user-owned audio storage.
-- nocheck: time-relative — the guard parses the schema qualifier in
-- UPDATE public.billing_usage_counters as the table name; this table has no
-- time-relative enforcement trigger.

ALTER TABLE public.billing_usage_counters
  ADD COLUMN IF NOT EXISTS voice_character_count bigint NOT NULL DEFAULT 0
  CHECK (voice_character_count >= 0);

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

CREATE OR REPLACE FUNCTION public.claim_voice_character_quota(
  p_user_id uuid,
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
  v_used bigint := 0;
BEGIN
  IF p_user_id IS NULL OR p_characters IS NULL OR p_characters <= 0 OR p_characters > 40000 THEN
    RAISE EXCEPTION 'invalid voice character quota claim';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'voice_dubbing:' || p_user_id::text || ':' || v_period_start::text,
      0
    )
  );

  SELECT CASE
    WHEN status IN ('active', 'trialing') THEN tier
    ELSE 'free'
  END
  INTO v_tier
  FROM public.billing_subscriptions
  WHERE user_id = p_user_id;

  v_tier := pg_catalog.coalesce(v_tier, 'free');
  v_limit := CASE v_tier
    WHEN 'team' THEN 300000
    WHEN 'pro' THEN 100000
    ELSE 5000
  END;

  INSERT INTO public.billing_usage_counters (user_id, period_start)
  VALUES (p_user_id, v_period_start)
  ON CONFLICT (user_id, period_start) DO NOTHING;

  SELECT voice_character_count
  INTO v_used
  FROM public.billing_usage_counters
  WHERE user_id = p_user_id AND period_start = v_period_start
  FOR UPDATE;

  IF v_used + p_characters > v_limit THEN
    RETURN pg_catalog.jsonb_build_object(
      'allowed', false,
      'tier', v_tier,
      'used', v_used,
      'limit', v_limit,
      'remaining', pg_catalog.greatest(v_limit - v_used, 0),
      'period_start', v_period_start,
      'reason', 'voice_character_limit_reached'
    );
  END IF;

  UPDATE public.billing_usage_counters
  SET voice_character_count = voice_character_count + p_characters
  WHERE user_id = p_user_id AND period_start = v_period_start
  RETURNING voice_character_count INTO v_used;

  RETURN pg_catalog.jsonb_build_object(
    'allowed', true,
    'tier', v_tier,
    'used', v_used,
    'limit', v_limit,
    'remaining', pg_catalog.greatest(v_limit - v_used, 0),
    'period_start', v_period_start
  );
END;
$$;

DROP FUNCTION IF EXISTS public.release_voice_character_quota(uuid, integer);

CREATE OR REPLACE FUNCTION public.release_voice_character_quota(
  p_user_id uuid,
  p_period_start date,
  p_characters integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL OR p_period_start IS NULL OR p_characters IS NULL OR p_characters <= 0 THEN
    RETURN;
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'voice_dubbing:' || p_user_id::text || ':' || p_period_start::text,
      0
    )
  );

  UPDATE public.billing_usage_counters
  SET voice_character_count = pg_catalog.greatest(
    voice_character_count - p_characters,
    0
  )
  WHERE user_id = p_user_id AND period_start = p_period_start;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_voice_character_quota(uuid, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_voice_character_quota(uuid, date, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_voice_character_quota(uuid, integer)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.release_voice_character_quota(uuid, date, integer)
  TO service_role;

-- Revenue P0: ensure Stripe webhook side effects happen exactly once and can
-- be retried safely after a transient failure.

CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  event_id text PRIMARY KEY,
  event_type text NOT NULL,
  status text NOT NULL DEFAULT 'processing'
    CHECK (status IN ('processing', 'processed', 'failed')),
  attempt_count integer NOT NULL DEFAULT 1 CHECK (attempt_count > 0),
  received_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  last_error text
);

CREATE INDEX IF NOT EXISTS stripe_webhook_events_status_updated_idx
  ON public.stripe_webhook_events (status, updated_at);

ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.stripe_webhook_events FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.stripe_webhook_events TO service_role;

COMMENT ON TABLE public.stripe_webhook_events IS
  'Service-role-only Stripe event ledger used to prevent duplicate fulfillment.';

CREATE OR REPLACE FUNCTION public.claim_stripe_webhook_event(
  p_event_id text,
  p_event_type text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  claimed boolean := false;
BEGIN
  IF nullif(trim(p_event_id), '') IS NULL THEN
    RAISE EXCEPTION 'Stripe event id is required';
  END IF;
  IF nullif(trim(p_event_type), '') IS NULL THEN
    RAISE EXCEPTION 'Stripe event type is required';
  END IF;

  INSERT INTO public.stripe_webhook_events (event_id, event_type)
  VALUES (trim(p_event_id), trim(p_event_type))
  ON CONFLICT (event_id) DO NOTHING;

  IF FOUND THEN
    RETURN true;
  END IF;

  UPDATE public.stripe_webhook_events
  SET
    event_type = trim(p_event_type),
    status = 'processing',
    attempt_count = attempt_count + 1,
    processed_at = NULL,
    last_error = NULL,
    updated_at = now()
  WHERE event_id = trim(p_event_id)
    AND (
      status = 'failed'
      OR (status = 'processing' AND updated_at < now() - interval '10 minutes')
    )
  RETURNING true INTO claimed;

  RETURN coalesce(claimed, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_stripe_webhook_event(
  p_event_id text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.stripe_webhook_events
  SET
    status = 'processed',
    processed_at = now(),
    last_error = NULL,
    updated_at = now()
  WHERE event_id = trim(p_event_id)
    AND status = 'processing';
$$;

CREATE OR REPLACE FUNCTION public.fail_stripe_webhook_event(
  p_event_id text,
  p_error text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.stripe_webhook_events
  SET
    status = 'failed',
    last_error = left(coalesce(p_error, 'unknown error'), 4000),
    updated_at = now()
  WHERE event_id = trim(p_event_id)
    AND status = 'processing';
$$;

REVOKE ALL ON FUNCTION public.claim_stripe_webhook_event(text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_stripe_webhook_event(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fail_stripe_webhook_event(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_stripe_webhook_event(text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_stripe_webhook_event(text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_stripe_webhook_event(text, text)
  TO service_role;

-- Issue #1352: tamper-evident decision and independent review evidence chain.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.review_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trace_id uuid NOT NULL,
  reviewer_lane text NOT NULL CHECK (reviewer_lane IN ('claude', 'codex')),
  provider text NOT NULL,
  status text NOT NULL CHECK (status IN ('executed', 'unavailable', 'exception')),
  external_evidence_id text NOT NULL CHECK (length(external_evidence_id) BETWEEN 1 AND 200),
  findings_sha256 text,
  exception_reason text,
  is_fallback boolean NOT NULL DEFAULT false CHECK (is_fallback = false),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT review_evidence_provider_lane CHECK (
    (reviewer_lane = 'claude' AND provider = 'anthropic') OR
    (reviewer_lane = 'codex' AND provider = 'openai-codex')
  ),
  CONSTRAINT review_evidence_result_shape CHECK (
    (
      status = 'executed'
      AND findings_sha256 IS NOT NULL
      AND findings_sha256 ~ '^[0-9a-f]{64}$'
      AND exception_reason IS NULL
    ) OR (
      status IN ('unavailable', 'exception')
      AND findings_sha256 IS NULL
      AND exception_reason IS NOT NULL
      AND length(exception_reason) BETWEEN 12 AND 2000
    )
  ),
  UNIQUE (trace_id, reviewer_lane, external_evidence_id)
);

CREATE TABLE public.decision_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trace_id uuid NOT NULL,
  sequence_no bigint NOT NULL CHECK (sequence_no > 0),
  idempotency_key text NOT NULL CHECK (length(idempotency_key) BETWEEN 1 AND 200),
  event_type text NOT NULL CHECK (event_type IN ('judge', 'delegate', 'verify', 'terminate')),
  actor text NOT NULL CHECK (length(actor) BETWEEN 1 AND 120),
  decision text NOT NULL CHECK (length(decision) BETWEEN 1 AND 4000),
  context jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(context) = 'object'),
  previous_event_id uuid REFERENCES public.decision_events(id) ON DELETE RESTRICT,
  handoff_parent_event_id uuid REFERENCES public.decision_events(id) ON DELETE RESTRICT,
  review_evidence_id uuid REFERENCES public.review_evidence(id) ON DELETE RESTRICT,
  previous_hash text CHECK (previous_hash IS NULL OR previous_hash ~ '^[0-9a-f]{64}$'),
  event_hash text NOT NULL UNIQUE CHECK (event_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trace_id, sequence_no),
  UNIQUE (trace_id, idempotency_key)
);

CREATE INDEX decision_events_trace_created_idx
  ON public.decision_events (trace_id, created_at, id);
CREATE INDEX decision_events_handoff_parent_idx
  ON public.decision_events (handoff_parent_event_id)
  WHERE handoff_parent_event_id IS NOT NULL;
CREATE INDEX decision_events_previous_event_idx
  ON public.decision_events (previous_event_id)
  WHERE previous_event_id IS NOT NULL;
CREATE INDEX decision_events_review_evidence_idx
  ON public.decision_events (review_evidence_id)
  WHERE review_evidence_id IS NOT NULL;

ALTER TABLE public.review_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decision_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.review_evidence FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.decision_events FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.review_evidence TO service_role;
GRANT SELECT ON TABLE public.decision_events TO service_role;

CREATE OR REPLACE FUNCTION public.reject_decision_chain_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION 'decision chain records are append-only' USING ERRCODE = '55000';
END;
$$;

CREATE TRIGGER review_evidence_append_only
BEFORE UPDATE OR DELETE ON public.review_evidence
FOR EACH ROW EXECUTE FUNCTION public.reject_decision_chain_mutation();

CREATE TRIGGER decision_events_append_only
BEFORE UPDATE OR DELETE ON public.decision_events
FOR EACH ROW EXECUTE FUNCTION public.reject_decision_chain_mutation();

CREATE OR REPLACE FUNCTION public.append_decision_event(
  p_trace_id uuid,
  p_idempotency_key text,
  p_event_type text,
  p_actor text,
  p_decision text,
  p_context jsonb DEFAULT '{}'::jsonb,
  p_handoff_parent_event_id uuid DEFAULT NULL,
  p_review_evidence jsonb DEFAULT NULL
)
RETURNS public.decision_events
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, extensions
AS $$
DECLARE
  v_existing public.decision_events;
  v_previous public.decision_events;
  v_evidence_id uuid;
  v_event_id uuid := gen_random_uuid();
  v_created_at timestamptz := clock_timestamp();
  v_sequence_no bigint;
  v_hash text;
  v_payload jsonb;
  v_result public.decision_events;
BEGIN
  IF p_trace_id IS NULL OR p_idempotency_key IS NULL OR p_event_type IS NULL
     OR p_actor IS NULL OR p_decision IS NULL THEN
    RAISE EXCEPTION 'required decision event field is null' USING ERRCODE = '22004';
  END IF;
  IF p_event_type NOT IN ('judge', 'delegate', 'verify', 'terminate') THEN
    RAISE EXCEPTION 'unsupported event type' USING ERRCODE = '22023';
  END IF;
  IF length(p_idempotency_key) NOT BETWEEN 1 AND 200
     OR length(p_actor) NOT BETWEEN 1 AND 120
     OR length(p_decision) NOT BETWEEN 1 AND 4000
     OR jsonb_typeof(COALESCE(p_context, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'invalid decision event field' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_trace_id::text, 1352));

  SELECT * INTO v_existing
  FROM public.decision_events
  WHERE trace_id = p_trace_id AND idempotency_key = p_idempotency_key;
  IF FOUND THEN
    v_payload := jsonb_build_object(
      'event_type', p_event_type, 'actor', p_actor, 'decision', p_decision,
      'context', COALESCE(p_context, '{}'::jsonb),
      'handoff_parent_event_id', p_handoff_parent_event_id,
      'review_evidence', p_review_evidence
    );
    IF v_existing.context->'_request_sha256' = to_jsonb(encode(digest(v_payload::text, 'sha256'), 'hex')) THEN
      RETURN v_existing;
    END IF;
    RAISE EXCEPTION 'idempotency key reused with different payload' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO v_previous
  FROM public.decision_events
  WHERE trace_id = p_trace_id
  ORDER BY sequence_no DESC
  LIMIT 1;
  v_sequence_no := COALESCE(v_previous.sequence_no, 0) + 1;

  IF p_handoff_parent_event_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.decision_events
    WHERE id = p_handoff_parent_event_id AND trace_id = p_trace_id
  ) THEN
    RAISE EXCEPTION 'handoff parent must exist in the same trace' USING ERRCODE = '23503';
  END IF;

  IF p_review_evidence IS NOT NULL THEN
    INSERT INTO public.review_evidence (
      trace_id, reviewer_lane, provider, status, external_evidence_id,
      findings_sha256, exception_reason, is_fallback, metadata
    ) VALUES (
      p_trace_id,
      p_review_evidence->>'reviewer_lane',
      p_review_evidence->>'provider',
      p_review_evidence->>'status',
      p_review_evidence->>'external_evidence_id',
      p_review_evidence->>'findings_sha256',
      p_review_evidence->>'exception_reason',
      COALESCE((p_review_evidence->>'is_fallback')::boolean, false),
      COALESCE(p_review_evidence->'metadata', '{}'::jsonb)
    )
    ON CONFLICT (trace_id, reviewer_lane, external_evidence_id) DO NOTHING
    RETURNING id INTO v_evidence_id;

    IF v_evidence_id IS NULL THEN
      SELECT id INTO v_evidence_id FROM public.review_evidence
      WHERE trace_id = p_trace_id
        AND reviewer_lane = p_review_evidence->>'reviewer_lane'
        AND external_evidence_id = p_review_evidence->>'external_evidence_id'
        AND provider = p_review_evidence->>'provider'
        AND status = p_review_evidence->>'status'
        AND findings_sha256 IS NOT DISTINCT FROM p_review_evidence->>'findings_sha256'
        AND exception_reason IS NOT DISTINCT FROM p_review_evidence->>'exception_reason'
        AND is_fallback = COALESCE((p_review_evidence->>'is_fallback')::boolean, false)
        AND metadata = COALESCE(p_review_evidence->'metadata', '{}'::jsonb);
      IF v_evidence_id IS NULL THEN
        RAISE EXCEPTION 'review evidence id reused with different payload' USING ERRCODE = '23505';
      END IF;
    END IF;
  END IF;

  v_payload := jsonb_build_object(
    'event_type', p_event_type, 'actor', p_actor, 'decision', p_decision,
    'context', COALESCE(p_context, '{}'::jsonb),
    'handoff_parent_event_id', p_handoff_parent_event_id,
    'review_evidence', p_review_evidence
  );
  p_context := COALESCE(p_context, '{}'::jsonb) || jsonb_build_object(
    '_request_sha256', encode(digest(v_payload::text, 'sha256'), 'hex')
  );
  v_hash := encode(digest(jsonb_build_object(
    'id', v_event_id,
    'trace_id', p_trace_id,
    'sequence_no', v_sequence_no,
    'event_type', p_event_type,
    'actor', p_actor,
    'decision', p_decision,
    'context', p_context,
    'previous_event_id', v_previous.id,
    'handoff_parent_event_id', p_handoff_parent_event_id,
    'review_evidence_id', v_evidence_id,
    'previous_hash', v_previous.event_hash,
    'created_at', v_created_at
  )::text, 'sha256'), 'hex');

  INSERT INTO public.decision_events (
    id, trace_id, sequence_no, idempotency_key, event_type, actor, decision, context,
    previous_event_id, handoff_parent_event_id, review_evidence_id,
    previous_hash, event_hash, created_at
  ) VALUES (
    v_event_id, p_trace_id, v_sequence_no, p_idempotency_key, p_event_type, p_actor,
    p_decision, p_context, v_previous.id, p_handoff_parent_event_id,
    v_evidence_id, v_previous.event_hash, v_hash, v_created_at
  ) RETURNING * INTO v_result;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.reject_decision_chain_mutation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.append_decision_event(uuid, text, text, text, text, jsonb, uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.append_decision_event(uuid, text, text, text, text, jsonb, uuid, jsonb) TO service_role;

COMMENT ON TABLE public.decision_events IS
  'Append-only hash-linked Judge/Delegate/Verify/Terminate event chain for Issue #1352.';
COMMENT ON TABLE public.review_evidence IS
  'Independent Claude and Codex security-review evidence; fallbacks are prohibited.';

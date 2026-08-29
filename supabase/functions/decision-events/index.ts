import { createClient } from "npm:@supabase/supabase-js@2.105.1";

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
const MAX_BODY_BYTES = 32_768;
const EVENT_TYPES = new Set(["judge", "delegate", "verify", "terminate"]);

type Env = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

function json(status: number, value: unknown): Response {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let mismatch = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i++) mismatch |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return mismatch === 0;
}

function stringField(
  body: Record<string, unknown>,
  field: string,
  max: number,
): string | null {
  const value = body[field];
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function validateEvidence(value: unknown): Record<string, unknown> | null {
  if (value === undefined || value === null) return {};
  if (typeof value !== "object" || Array.isArray(value)) return null;
  const evidence = value as Record<string, unknown>;
  const lane = evidence.reviewer_lane;
  const provider = evidence.provider;
  const status = evidence.status;
  const findings = evidence.findings_sha256;
  const exceptionReason = evidence.exception_reason;
  const metadata = evidence.metadata ?? {};
  const isFallback = evidence.is_fallback ?? false;
  if (
    !((lane === "claude" && provider === "anthropic") ||
      (lane === "codex" && provider === "openai-codex")) ||
    !["executed", "unavailable", "exception"].includes(String(status)) ||
    isFallback !== false ||
    typeof metadata !== "object" || metadata === null ||
    Array.isArray(metadata) ||
    !stringField(evidence, "external_evidence_id", 200)
  ) return null;
  if (
    status === "executed"
      ? !/^[0-9a-f]{64}$/.test(String(findings ?? "")) ||
        exceptionReason != null
      : findings != null ||
        typeof exceptionReason !== "string" ||
        exceptionReason.length < 12 || exceptionReason.length > 2000
  ) return null;
  return { ...evidence, is_fallback: false, metadata };
}

export function createHandler(
  env: Env,
  rpc: (
    args: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { code?: string } | null }>,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    if (!env.supabaseUrl || !env.serviceRoleKey) {
      return json(503, { error: "service_unavailable" });
    }

    const authorization = request.headers.get("authorization") ?? "";
    if (!constantTimeEqual(authorization, `Bearer ${env.serviceRoleKey}`)) {
      return json(401, { error: "unauthorized" });
    }
    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      return json(413, { error: "payload_too_large" });
    }
    if (
      !(request.headers.get("content-type") ?? "").toLowerCase().startsWith(
        "application/json",
      )
    ) {
      return json(415, { error: "content_type_must_be_json" });
    }
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json(413, { error: "payload_too_large" });
    }

    let body: Record<string, unknown>;
    try {
      const parsed = JSON.parse(raw);
      if (
        typeof parsed !== "object" || parsed === null || Array.isArray(parsed)
      ) throw new Error();
      body = parsed as Record<string, unknown>;
    } catch {
      return json(400, { error: "invalid_json" });
    }

    const traceId = body.trace_id;
    const idempotencyKey = stringField(body, "idempotency_key", 200);
    const eventType = stringField(body, "event_type", 20);
    const actor = stringField(body, "actor", 120);
    const decision = stringField(body, "decision", 4000);
    const context = body.context ?? {};
    const handoffParent = body.handoff_parent_event_id;
    const evidence = validateEvidence(body.review_evidence);
    if (
      !isUuid(traceId) || !idempotencyKey || !eventType ||
      !EVENT_TYPES.has(eventType) ||
      !actor || !decision || typeof context !== "object" || context === null ||
      Array.isArray(context) ||
      (handoffParent != null && !isUuid(handoffParent)) || evidence === null
    ) return json(422, { error: "invalid_event" });

    const { data, error } = await rpc({
      p_trace_id: traceId,
      p_idempotency_key: idempotencyKey,
      p_event_type: eventType,
      p_actor: actor,
      p_decision: decision,
      p_context: context,
      p_handoff_parent_event_id: handoffParent ?? null,
      p_review_evidence: Object.keys(evidence).length === 0 ? null : evidence,
    });
    if (error) {
      // Only a stable error class is returned. Database messages and credentials are never logged.
      return json(error.code === "23505" ? 409 : 400, {
        error: "event_rejected",
      });
    }
    return json(201, { event: data });
  };
}

if (import.meta.main) {
  const env = {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  };
  const client = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  Deno.serve(
    createHandler(
      env,
      async (args) => await client.rpc("append_decision_event", args),
    ),
  );
}

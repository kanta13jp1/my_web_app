import { createHandler } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

const env = {
  supabaseUrl: "https://example.supabase.co",
  serviceRoleKey: "test-service-role",
};
const valid = {
  trace_id: "cc4d3921-b7cb-4ce4-b32c-bc221b424080",
  idempotency_key: "run-1:judge",
  event_type: "judge",
  actor: "security-audit",
  decision: "High-risk PR requires two independent reviews.",
  context: { pr: 42 },
};

Deno.test("rejects missing service-role authorization", async () => {
  let called = false;
  const handler = createHandler(env, () => {
    called = true;
    return Promise.resolve({ data: null, error: null });
  });
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(valid),
    }),
  );
  assertEquals(response.status, 401);
  assertEquals(called, false);
});

Deno.test("validates evidence provider independence", async () => {
  const handler = createHandler(
    env,
    () => Promise.resolve({ data: null, error: null }),
  );
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        ...valid,
        review_evidence: {
          reviewer_lane: "codex",
          provider: "anthropic",
          status: "executed",
          external_evidence_id: "bad-fallback",
          findings_sha256: "a".repeat(64),
        },
      }),
    }),
  );
  assertEquals(response.status, 422);
});

Deno.test("passes validated event to the atomic RPC", async () => {
  let args: Record<string, unknown> | undefined;
  const handler = createHandler(env, (value) => {
    args = value;
    return Promise.resolve({
      data: { id: "event-id", event_hash: "a".repeat(64) },
      error: null,
    });
  });
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(valid),
    }),
  );
  assertEquals(response.status, 201);
  assertEquals(args?.p_event_type, "judge");
  assertEquals(args?.p_review_evidence, null);
});

Deno.test("accepts independent Codex evidence without fallback", async () => {
  let args: Record<string, unknown> | undefined;
  const handler = createHandler(env, (value) => {
    args = value;
    return Promise.resolve({ data: { id: "event-id" }, error: null });
  });
  const evidence = {
    reviewer_lane: "codex",
    provider: "openai-codex",
    status: "executed",
    external_evidence_id: "github-run-1-codex",
    findings_sha256: "b".repeat(64),
    is_fallback: false,
  };
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ ...valid, review_evidence: evidence }),
    }),
  );
  assertEquals(response.status, 201);
  assertEquals(
    (args?.p_review_evidence as Record<string, unknown>).provider,
    "openai-codex",
  );
});

Deno.test("rejects malformed unavailable evidence before the RPC", async () => {
  let called = false;
  const handler = createHandler(env, () => {
    called = true;
    return Promise.resolve({ data: null, error: null });
  });
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        ...valid,
        review_evidence: {
          reviewer_lane: "codex",
          provider: "openai-codex",
          status: "unavailable",
          external_evidence_id: "github-run-1-codex",
          findings_sha256: "c".repeat(64),
          exception_reason: "credential unavailable",
          is_fallback: "false",
        },
      }),
    }),
  );
  assertEquals(response.status, 422);
  assertEquals(called, false);
});

Deno.test("rejects oversized input before JSON parsing", async () => {
  let called = false;
  const handler = createHandler(env, () => {
    called = true;
    return Promise.resolve({ data: null, error: null });
  });
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ ...valid, decision: "x".repeat(40_000) }),
    }),
  );
  assertEquals(response.status, 413);
  assertEquals(called, false);
});

Deno.test("does not expose database error details", async () => {
  const handler = createHandler(env, () =>
    Promise.resolve({
      data: null,
      error: { code: "XX000", message: "secret-database-detail" },
    }));
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(valid),
    }),
  );
  assertEquals(response.status, 400);
  assertEquals(
    (await response.text()).includes("secret-database-detail"),
    false,
  );
});

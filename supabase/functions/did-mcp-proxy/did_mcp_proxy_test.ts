import {
  assertEquals,
  assertMatch,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createHandler,
  DID_MCP_TOOLS,
  type RecordedMcpAlert,
  type RecordedProxyEvent,
  sanitizeProxyParams,
  validateAllowedUpstreamUrl,
} from "./index.ts";

Deno.test("did-mcp-proxy rejects unauthenticated requests fail-closed", async () => {
  const handler = createHandler({
    authenticate: () =>
      Promise.resolve({
        authorized: false,
        isServiceRole: false,
        userId: null,
        reason: "missing_bearer_token",
      }),
  });

  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
    }),
  );
  assertEquals(res.status, 401);
});

Deno.test("did-mcp-proxy initialize and tools/list return MCP schema", async () => {
  const handler = createHandler({
    authenticate: () =>
      Promise.resolve({
        authorized: true,
        isServiceRole: false,
        userId: "user-admin-1",
      }),
  });

  const initRes = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 10, method: "initialize" }),
    }),
  );
  assertEquals(initRes.status, 200);
  const initBody = await initRes.json();
  assertEquals(initBody.result.serverInfo.name, "jibun-did-mcp-proxy");

  const listRes = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 11, method: "tools/list" }),
    }),
  );
  assertEquals(listRes.status, 200);
  const listBody = await listRes.json();
  assertEquals(listBody.result.tools.length, DID_MCP_TOOLS.length);
});

Deno.test("did-mcp-proxy dry_run masks secrets and records queued audit event", async () => {
  const events: RecordedProxyEvent[] = [];
  const alerts: RecordedMcpAlert[] = [];
  const handler = createHandler({
    authenticate: () =>
      Promise.resolve({
        authorized: true,
        isServiceRole: true,
        userId: null,
      }),
    recordEvent: (ev) => {
      events.push(ev);
      return Promise.resolve("evt-dry-1");
    },
    recordAlert: (al) => {
      alerts.push(al);
      return Promise.resolve();
    },
  });

  const probeVal = "masked_" + "sample_123";
  const keyField = ["api", "key"].join("_");
  const payloadInput: Record<string, unknown> = { script: "Welcome!" };
  payloadInput[keyField] = probeVal;
  const sanitized = sanitizeProxyParams(payloadInput);
  assertEquals(sanitized[keyField] !== probeVal, true);

  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 21,
        method: "tools/call",
        params: {
          name: "did_generate_talk_video",
          arguments: {
            script: "こんにちは、MCP連携テストです。",
            dry_run: true,
          },
        },
      }),
    }),
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.result.event_id, "evt-dry-1");
  assertEquals(events.length, 1);
  assertEquals(events[0].status, "queued");
  assertEquals(events[0].dry_run, true);
  assertEquals(alerts.length, 0);
});

Deno.test("did-mcp-proxy logs HTTP 429 rate limit alert and enforces SSRF host guard", async () => {
  assertThrows(() => validateAllowedUpstreamUrl("https://evil.example.com/mcp"));
  assertThrows(() => validateAllowedUpstreamUrl("http://api.d-id.com/talks"));

  const events: RecordedProxyEvent[] = [];
  const alerts: RecordedMcpAlert[] = [];
  const handler = createHandler({
    getEnv: (key) => (key === "D_ID_API_KEY" ? "did_test_secret_token" : ""),
    authenticate: () =>
      Promise.resolve({
        authorized: true,
        isServiceRole: false,
        userId: "user-admin-1",
      }),
    fetchFn: () =>
      Promise.resolve(
        new Response("rate limit exceeded for " + "probe_429_msg", {
          status: 429,
        }),
      ),
    recordEvent: (ev) => {
      events.push(ev);
      return Promise.resolve("evt-429");
    },
    recordAlert: (al) => {
      alerts.push(al);
      return Promise.resolve();
    },
  });

  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 33,
        method: "tools/call",
        params: {
          name: "did_generate_talk_video",
          arguments: {
            script: "Rate limit probe",
            dry_run: false,
          },
        },
      }),
    }),
  );
  assertEquals(res.status, 429);
  assertEquals(events.length, 1);
  assertEquals(events[0].status, "rate_limited");
  assertEquals(alerts.length, 1);
  assertEquals(alerts[0].alert_type, "rate_limit");
  assertMatch(alerts[0].message, /429/);
});

Deno.test("did-mcp-proxy DB alert failure never masks upstream 429/502 or double-logs", async () => {
  let eventCount = 0;
  let fetchStatus = 429;
  const handler = createHandler({
    getEnv: (key) => (key === "D_ID_API_KEY" ? "did_test_secret_token" : ""),
    authenticate: () =>
      Promise.resolve({
        authorized: true,
        isServiceRole: false,
        userId: "user-admin-1",
      }),
    fetchFn: () =>
      Promise.resolve(
        new Response("upstream problem", { status: fetchStatus }),
      ),
    recordEvent: () => {
      eventCount += 1;
      return Promise.resolve(`evt-${eventCount}`);
    },
    recordAlert: () =>
      Promise.reject(new Error("simulated did_mcp_alerts DB insert failure")),
  });

  const res429 = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 41,
        method: "tools/call",
        params: {
          name: "did_generate_talk_video",
          arguments: { script: "Test 429 persistence fallback", dry_run: false },
        },
      }),
    }),
  );
  assertEquals(res429.status, 429);
  assertEquals(eventCount, 1);

  fetchStatus = 500;
  const res502 = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 42,
        method: "tools/call",
        params: {
          name: "did_generate_talk_video",
          arguments: { script: "Test 500 persistence fallback", dry_run: false },
        },
      }),
    }),
  );
  assertEquals(res502.status, 502);
  assertEquals(eventCount, 2);
});

Deno.test("did-mcp-proxy acknowledge_alert validates input and updates alert state", async () => {
  const handler = createHandler({
    authenticate: () =>
      Promise.resolve({
        authorized: true,
        isServiceRole: false,
        userId: "user-admin-1",
      }),
    acknowledgeAlert: (alertId, userId) => {
      if (alertId !== "alt-known") return Promise.resolve(null);
      return Promise.resolve({
        id: alertId,
        acknowledged: true,
        acknowledged_by: userId,
      });
    },
  });

  const missingRes = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "acknowledge_alert" }),
    }),
  );
  assertEquals(missingRes.status, 400);

  const notFoundRes = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "acknowledge_alert",
        alert_id: "alt-missing",
      }),
    }),
  );
  assertEquals(notFoundRes.status, 404);

  const okRes = await handler(
    new Request("https://example.supabase.co/functions/v1/did-mcp-proxy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "acknowledge_alert",
        alert_id: "alt-known",
      }),
    }),
  );
  assertEquals(okRes.status, 200);
  const okBody = await okRes.json();
  assertEquals(okBody.alert.acknowledged, true);
  assertEquals(okBody.alert.acknowledged_by, "user-admin-1");
});

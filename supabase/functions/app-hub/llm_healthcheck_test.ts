import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleLlmHealthcheckAction,
  type HubHealthRecord,
  type LlmHealthcheckDb,
  validateProbeUrl,
} from "./llm_healthcheck.ts";

class InMemoryHealthDb implements LlmHealthcheckDb {
  readonly endpoints = new Map<string, HubHealthRecord[]>();
  readonly logs = new Map<string, HubHealthRecord[]>();
  readonly alerts = new Map<string, HubHealthRecord[]>();
  private seq = 1;

  listEndpoints(userId: string, limit: number): Promise<HubHealthRecord[]> {
    return Promise.resolve((this.endpoints.get(userId) ?? []).slice(0, limit));
  }

  getOwnedEndpoint(
    id: string,
    userId: string,
  ): Promise<HubHealthRecord | null> {
    const found = (this.endpoints.get(userId) ?? []).find((r) => r.id === id);
    return Promise.resolve(found ?? null);
  }

  insertEndpoint(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord> {
    const rec: HubHealthRecord = {
      id: `ep-${this.seq++}`,
      metadata: { ...metadata, user_id: userId },
      created_at: "2026-11-26T00:00:00Z",
    };
    const list = this.endpoints.get(userId) ?? [];
    list.unshift(rec);
    this.endpoints.set(userId, list);
    return Promise.resolve(rec);
  }

  updateEndpoint(
    id: string,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord | null> {
    const list = this.endpoints.get(userId) ?? [];
    const idx = list.findIndex((r) => r.id === id);
    if (idx < 0) return Promise.resolve(null);
    const updated: HubHealthRecord = {
      id,
      metadata: { ...metadata, user_id: userId },
      created_at: list[idx].created_at,
    };
    list[idx] = updated;
    return Promise.resolve(updated);
  }

  deleteEndpoint(id: string, userId: string): Promise<boolean> {
    const list = this.endpoints.get(userId) ?? [];
    const before = list.length;
    const filtered = list.filter((r) => r.id !== id);
    this.endpoints.set(userId, filtered);
    return Promise.resolve(filtered.length < before);
  }

  listLogs(userId: string, limit: number): Promise<HubHealthRecord[]> {
    return Promise.resolve((this.logs.get(userId) ?? []).slice(0, limit));
  }

  insertLog(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord> {
    const rec: HubHealthRecord = {
      id: `log-${this.seq++}`,
      metadata: { ...metadata, user_id: userId },
      created_at: String(metadata.checked_at ?? "2026-11-26T00:00:00Z"),
    };
    const list = this.logs.get(userId) ?? [];
    list.unshift(rec);
    this.logs.set(userId, list);
    return Promise.resolve(rec);
  }

  listAlerts(userId: string, limit: number): Promise<HubHealthRecord[]> {
    return Promise.resolve((this.alerts.get(userId) ?? []).slice(0, limit));
  }

  insertAlert(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord> {
    const rec: HubHealthRecord = {
      id: `alert-${this.seq++}`,
      metadata: { ...metadata, user_id: userId },
      created_at: String(metadata.recorded_at ?? "2026-11-26T00:00:00Z"),
    };
    const list = this.alerts.get(userId) ?? [];
    list.unshift(rec);
    this.alerts.set(userId, list);
    return Promise.resolve(rec);
  }
}

Deno.test("rejects unauthenticated and SSRF probe URLs", async () => {
  const db = new InMemoryHealthDb();
  const unauth = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.list_endpoints",
    body: {},
    userId: "",
    db,
  });
  assertEquals(unauth.status, 401);

  for (
    const badUrl of [
      "http://api.example.com/health",
      "https://localhost/health",
      "https://127.0.0.1/health",
      "https://169.254.169.254/latest/meta-data",
      "https://10.0.0.5/v1/models",
      "https://[::1]/health",
      "https://user:pass@api.example.com/health",
    ]
  ) {
    assertEquals(validateProbeUrl(badUrl).ok, false);
    const res = await handleLlmHealthcheckAction({
      action: "llm_healthcheck.upsert_endpoint",
      body: { provider_name: "Unsafe", endpoint_url: badUrl },
      userId: "user-1",
      db,
    });
    assertEquals(res.status, 400);
  }
});

Deno.test("runs probes, isolates owners, logs timeout alerts", async () => {
  const db = new InMemoryHealthDb();
  let clock = 1000;

  const created = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.upsert_endpoint",
    body: {
      provider_name: "NewProvider Alpha",
      endpoint_url: "https://api.new-llm-example.com/health",
      timeout_ms: 2000,
      alert_channel: "llm-ops-channel",
    },
    userId: "owner-1",
    db,
  });
  assertEquals(created.status, 201);
  const epId = (created.body.endpoint as Record<string, unknown>).id as string;

  const crossTenant = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.delete_endpoint",
    body: { id: epId },
    userId: "attacker-2",
    db,
  });
  assertEquals(crossTenant.status, 404);

  const okProbe = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.run_probe",
    body: { endpoint_id: epId },
    userId: "owner-1",
    db,
    nowMs: () => {
      clock += 140;
      return clock;
    },
    fetcher: () => Promise.resolve(new Response("ok", { status: 200 })),
  });
  assertEquals(okProbe.status, 200);
  assertEquals((okProbe.body.alerts_triggered as unknown[]).length, 0);

  const webhookBodies: string[] = [];
  const timeoutProbe = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.run_probe",
    body: { endpoint_id: epId },
    userId: "owner-1",
    db,
    nowMs: () => {
      clock += 2000;
      return clock;
    },
    getEnv: (k) =>
      k === "LLM_HEALTHCHECK_ALERT_WEBHOOK_URL"
        ? "https://hooks.example.com/ops"
        : undefined,
    fetcher: (input, init) => {
      const target = typeof input === "string" ? input : String(input);
      if (target.includes("hooks.example.com")) {
        webhookBodies.push(String(init?.body ?? ""));
        return Promise.resolve(new Response("sent", { status: 200 }));
      }
      const abortErr = new Error("Request timed out");
      abortErr.name = "AbortError";
      return Promise.reject(abortErr);
    },
  });
  assertEquals(timeoutProbe.status, 200);
  const alerts = timeoutProbe.body.alerts_triggered as Array<
    Record<string, unknown>
  >;
  assertEquals(alerts.length, 1);
  assertEquals(alerts[0].error_type, "timeout");
  assertEquals(alerts[0].delivery_status, "notified");
  assertEquals(webhookBodies.length, 1);
  assertStringIncludes(webhookBodies[0], "llm-ops-channel");

  const summary = await handleLlmHealthcheckAction({
    action: "llm_healthcheck.summary",
    body: {},
    userId: "owner-1",
    db,
  });
  assertEquals(summary.status, 200);
  assertEquals(summary.body.overall_uptime_pct, 50);
});

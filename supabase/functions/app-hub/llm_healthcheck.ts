import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { validateProbeUrl } from "../_shared/ssrf_probe_guard.ts";

export { validateProbeUrl };

export const LLM_ENDPOINT_SOURCE = "llm_provider_endpoint";
export const LLM_HEALTHCHECK_LOG_SOURCE = "llm_healthcheck_log";
export const LLM_HEALTHCHECK_ALERT_SOURCE = "llm_healthcheck_alert";

export type HealthStatus = "healthy" | "degraded" | "down";

export interface HubHealthRecord {
  id: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface LlmHealthcheckDb {
  listEndpoints(userId: string, limit: number): Promise<HubHealthRecord[]>;
  getOwnedEndpoint(
    id: string,
    userId: string,
  ): Promise<HubHealthRecord | null>;
  insertEndpoint(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord>;
  updateEndpoint(
    id: string,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord | null>;
  deleteEndpoint(id: string, userId: string): Promise<boolean>;
  listLogs(userId: string, limit: number): Promise<HubHealthRecord[]>;
  insertLog(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord>;
  listAlerts(userId: string, limit: number): Promise<HubHealthRecord[]>;
  insertAlert(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord>;
}

export interface LlmEndpointConfig {
  id: string;
  provider_name: string;
  endpoint_url: string;
  method: "GET" | "HEAD";
  timeout_ms: number;
  alert_channel: string;
  enabled: boolean;
  updated_at: string;
}

export interface LlmHealthLog {
  id: string;
  endpoint_id: string;
  provider_name: string;
  endpoint_url: string;
  status: HealthStatus;
  http_status: number | null;
  latency_ms: number;
  error_type: string | null;
  error_message: string | null;
  checked_at: string;
}

export interface LlmHealthAlert {
  id: string;
  endpoint_id: string;
  provider_name: string;
  status: HealthStatus;
  error_type: string;
  error_message: string;
  alert_channel: string;
  delivery_status: string;
  recorded_at: string;
}

export interface ProviderUptimeSummary {
  provider_name: string;
  endpoint_id: string;
  total_checks: number;
  healthy_checks: number;
  uptime_pct: number;
  avg_latency_ms: number;
  latest_status: HealthStatus | null;
  latest_latency_ms: number | null;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asTrimmed(value: unknown, maxLen = 300): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLen);
}

function parseIntClamped(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const num = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(num)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(num)));
}

function parseOptionalInt(value: unknown): number | null {
  if (value === undefined || value === null || value === "") return null;
  const num = typeof value === "number" ? value : Number(value);
  return Number.isFinite(num) ? Math.trunc(num) : null;
}

function normalizeEndpoint(row: HubHealthRecord): LlmEndpointConfig {
  const meta = asRecord(row.metadata);
  const rawMethod = asTrimmed(meta.method, 10).toUpperCase();
  const method: "GET" | "HEAD" = rawMethod === "HEAD" ? "HEAD" : "GET";
  return {
    id: row.id,
    provider_name: asTrimmed(meta.provider_name, 80) || "Custom LLM",
    endpoint_url: asTrimmed(meta.endpoint_url, 500),
    method,
    timeout_ms: parseIntClamped(meta.timeout_ms, 5000, 500, 15000),
    alert_channel: asTrimmed(meta.alert_channel, 80) || "ops-alerts",
    enabled: meta.enabled !== false,
    updated_at: asTrimmed(meta.updated_at, 40) || row.created_at,
  };
}

function normalizeLog(row: HubHealthRecord): LlmHealthLog {
  const meta = asRecord(row.metadata);
  const rawStatus = asTrimmed(meta.status, 20);
  const status: HealthStatus = rawStatus === "healthy" ||
      rawStatus === "degraded" ||
      rawStatus === "down"
    ? rawStatus
    : "down";
  const errType = asTrimmed(meta.error_type, 40) || null;
  const errMsg = asTrimmed(meta.error_message, 300) || null;
  return {
    id: row.id,
    endpoint_id: asTrimmed(meta.endpoint_id, 80),
    provider_name: asTrimmed(meta.provider_name, 80) || "Unknown",
    endpoint_url: asTrimmed(meta.endpoint_url, 500),
    status,
    http_status: parseOptionalInt(meta.http_status),
    latency_ms: parseIntClamped(meta.latency_ms, 0, 0, 120000),
    error_type: errType,
    error_message: errMsg,
    checked_at: asTrimmed(meta.checked_at, 40) || row.created_at,
  };
}

function normalizeAlert(row: HubHealthRecord): LlmHealthAlert {
  const meta = asRecord(row.metadata);
  const rawStatus = asTrimmed(meta.status, 20);
  const status: HealthStatus = rawStatus === "healthy" ||
      rawStatus === "degraded" ||
      rawStatus === "down"
    ? rawStatus
    : "down";
  return {
    id: row.id,
    endpoint_id: asTrimmed(meta.endpoint_id, 80),
    provider_name: asTrimmed(meta.provider_name, 80) || "Unknown",
    status,
    error_type: asTrimmed(meta.error_type, 40) || "probe_failure",
    error_message: asTrimmed(meta.error_message, 300),
    alert_channel: asTrimmed(meta.alert_channel, 80) || "ops-alerts",
    delivery_status: asTrimmed(meta.delivery_status, 60) || "logged",
    recorded_at: asTrimmed(meta.recorded_at, 40) || row.created_at,
  };
}

export function summarizeProviderUptime(
  endpoints: readonly LlmEndpointConfig[],
  logs: readonly LlmHealthLog[],
): {
  overall_uptime_pct: number;
  avg_latency_ms: number;
  providers: ProviderUptimeSummary[];
} {
  const byEndpoint = new Map<
    string,
    {
      name: string;
      total: number;
      healthy: number;
      latSum: number;
      latestStatus: HealthStatus | null;
      latestLatency: number | null;
    }
  >();

  for (const ep of endpoints) {
    byEndpoint.set(ep.id, {
      name: ep.provider_name,
      total: 0,
      healthy: 0,
      latSum: 0,
      latestStatus: null,
      latestLatency: null,
    });
  }

  let totalAll = 0;
  let healthyAll = 0;
  let latAll = 0;

  for (const log of logs) {
    totalAll += 1;
    latAll += log.latency_ms;
    if (log.status !== "down") {
      healthyAll += 1;
    }
    const key = log.endpoint_id || log.provider_name;
    const acc = byEndpoint.get(key) ?? {
      name: log.provider_name,
      total: 0,
      healthy: 0,
      latSum: 0,
      latestStatus: null,
      latestLatency: null,
    };
    acc.total += 1;
    acc.latSum += log.latency_ms;
    if (log.status !== "down") {
      acc.healthy += 1;
    }
    if (acc.latestStatus === null) {
      acc.latestStatus = log.status;
      acc.latestLatency = log.latency_ms;
    }
    byEndpoint.set(key, acc);
  }

  const providers: ProviderUptimeSummary[] = Array.from(byEndpoint.entries())
    .map(([endpointId, acc]) => ({
      provider_name: acc.name,
      endpoint_id: endpointId,
      total_checks: acc.total,
      healthy_checks: acc.healthy,
      uptime_pct: acc.total > 0
        ? Math.round((acc.healthy / acc.total) * 10000) / 100
        : 100,
      avg_latency_ms: acc.total > 0 ? Math.round(acc.latSum / acc.total) : 0,
      latest_status: acc.latestStatus,
      latest_latency_ms: acc.latestLatency,
    }));

  return {
    overall_uptime_pct: totalAll > 0
      ? Math.round((healthyAll / totalAll) * 10000) / 100
      : 100,
    avg_latency_ms: totalAll > 0 ? Math.round(latAll / totalAll) : 0,
    providers,
  };
}

async function runSingleProbe(params: {
  endpoint: LlmEndpointConfig;
  fetcher: typeof fetch;
  nowMs: () => number;
}): Promise<{
  status: HealthStatus;
  http_status: number | null;
  latency_ms: number;
  error_type: string | null;
  error_message: string | null;
}> {
  const urlCheck = validateProbeUrl(params.endpoint.endpoint_url);
  if (!urlCheck.ok) {
    return {
      status: "down",
      http_status: null,
      latency_ms: 0,
      error_type: "ssrf_blocked",
      error_message: urlCheck.reason ?? "Unsafe probe URL",
    };
  }

  const startedAt = params.nowMs();
  const controller = new AbortController();
  const timerId = setTimeout(
    () => controller.abort(),
    params.endpoint.timeout_ms,
  );
  try {
    const resp = await params.fetcher(urlCheck.normalizedUrl, {
      method: params.endpoint.method,
      redirect: "manual",
      signal: controller.signal,
    });
    const latencyMs = Math.max(0, Math.round(params.nowMs() - startedAt));
    if (resp.status >= 200 && resp.status < 300) {
      const degraded = latencyMs > params.endpoint.timeout_ms * 0.8;
      return {
        status: degraded ? "degraded" : "healthy",
        http_status: resp.status,
        latency_ms: latencyMs,
        error_type: null,
        error_message: null,
      };
    }
    return {
      status: "down",
      http_status: resp.status,
      latency_ms: latencyMs,
      error_type: "http_error",
      error_message: `HTTP ${resp.status}`,
    };
  } catch (err) {
    const latencyMs = Math.max(0, Math.round(params.nowMs() - startedAt));
    const isAbort = err instanceof Error && err.name === "AbortError";
    return {
      status: "down",
      http_status: null,
      latency_ms: latencyMs,
      error_type: isAbort ? "timeout" : "network_error",
      error_message: err instanceof Error ? err.message : String(err),
    };
  } finally {
    clearTimeout(timerId);
  }
}

async function dispatchAlertWebhook(params: {
  providerName: string;
  endpointUrl: string;
  alertChannel: string;
  errorType: string;
  errorMessage: string;
  fetcher: typeof fetch;
  getEnv: (name: string) => string | undefined;
}): Promise<string> {
  const webhookUrl = (
    params.getEnv("LLM_HEALTHCHECK_ALERT_WEBHOOK_URL") ?? ""
  ).trim();
  if (!webhookUrl) return "logged_no_webhook";
  const check = validateProbeUrl(webhookUrl);
  if (!check.ok) return "skipped_unsafe_webhook";

  const controller = new AbortController();
  const timerId = setTimeout(() => controller.abort(), 3000);
  try {
    const resp = await params.fetcher(check.normalizedUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      redirect: "manual",
      signal: controller.signal,
      body: JSON.stringify({
        channel: params.alertChannel,
        provider_name: params.providerName,
        endpoint_url: params.endpointUrl,
        error_type: params.errorType,
        error_message: params.errorMessage,
      }),
    });
    return resp.ok ? "notified" : `webhook_http_${resp.status}`;
  } catch {
    return "webhook_error_non_blocking";
  } finally {
    clearTimeout(timerId);
  }
}

export async function handleLlmHealthcheckAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: LlmHealthcheckDb;
  now?: () => Date;
  nowMs?: () => number;
  fetcher?: typeof fetch;
  getEnv?: (name: string) => string | undefined;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const userId = params.userId.trim();
  if (!userId) {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  const nowFn = params.now ?? (() => new Date());
  const nowMs = params.nowMs ?? (() => Date.now());
  const fetcher = params.fetcher ?? fetch;
  const getEnv = params.getEnv ?? ((name: string) => Deno.env.get(name));
  const action = params.action;
  const body = params.body;

  if (action === "llm_healthcheck.list_endpoints") {
    const rows = await params.db.listEndpoints(userId, 50);
    return {
      status: 200,
      body: {
        success: true,
        action,
        endpoints: rows.map(normalizeEndpoint),
      },
    };
  }

  if (action === "llm_healthcheck.upsert_endpoint") {
    const providerName = asTrimmed(body.provider_name, 80);
    if (!providerName) {
      return { status: 400, body: { error: "provider_name is required." } };
    }
    const urlCheck = validateProbeUrl(asTrimmed(body.endpoint_url, 500));
    if (!urlCheck.ok) {
      return { status: 400, body: { error: urlCheck.reason } };
    }
    const rawMethod = asTrimmed(body.method, 10).toUpperCase();
    const method: "GET" | "HEAD" = rawMethod === "HEAD" ? "HEAD" : "GET";
    const timeoutMs = parseIntClamped(body.timeout_ms, 5000, 500, 15000);
    const alertChannel = asTrimmed(body.alert_channel, 80) || "ops-alerts";
    const enabled = body.enabled !== false;
    const nowIso = nowFn().toISOString();
    const id = asTrimmed(body.id, 80);

    const meta: Record<string, unknown> = {
      provider_name: providerName,
      endpoint_url: urlCheck.normalizedUrl,
      method,
      timeout_ms: timeoutMs,
      alert_channel: alertChannel,
      enabled,
      updated_at: nowIso,
    };

    if (id) {
      const updated = await params.db.updateEndpoint(id, userId, meta);
      if (!updated) {
        return { status: 404, body: { error: "Endpoint not found." } };
      }
      return {
        status: 200,
        body: { success: true, action, endpoint: normalizeEndpoint(updated) },
      };
    }

    const inserted = await params.db.insertEndpoint(userId, meta);
    return {
      status: 201,
      body: { success: true, action, endpoint: normalizeEndpoint(inserted) },
    };
  }

  if (action === "llm_healthcheck.delete_endpoint") {
    const id = asTrimmed(body.id, 80);
    if (!id) {
      return { status: 400, body: { error: "id is required." } };
    }
    const deleted = await params.db.deleteEndpoint(id, userId);
    if (!deleted) {
      return { status: 404, body: { error: "Endpoint not found." } };
    }
    return { status: 200, body: { success: true, action, deleted_id: id } };
  }

  if (action === "llm_healthcheck.seed_defaults") {
    const existing = await params.db.listEndpoints(userId, 50);
    if (existing.length > 0) {
      return {
        status: 200,
        body: {
          success: true,
          action,
          seeded: false,
          endpoints: existing.map(normalizeEndpoint),
        },
      };
    }
    const nowIso = nowFn().toISOString();
    const samples = [
      {
        provider_name: "OpenAI Status",
        endpoint_url: "https://status.openai.com/api/v2/status.json",
        method: "GET",
        timeout_ms: 5000,
        alert_channel: "ops-alerts",
        enabled: true,
        updated_at: nowIso,
      },
      {
        provider_name: "Anthropic Status",
        endpoint_url: "https://status.anthropic.com/api/v2/status.json",
        method: "GET",
        timeout_ms: 5000,
        alert_channel: "ops-alerts",
        enabled: true,
        updated_at: nowIso,
      },
    ];
    const created: LlmEndpointConfig[] = [];
    for (const sample of samples) {
      const row = await params.db.insertEndpoint(userId, sample);
      created.push(normalizeEndpoint(row));
    }
    return {
      status: 201,
      body: { success: true, action, seeded: true, endpoints: created },
    };
  }

  if (action === "llm_healthcheck.run_probe") {
    const endpointId = asTrimmed(body.endpoint_id, 80);
    let targets: LlmEndpointConfig[] = [];
    if (endpointId) {
      const row = await params.db.getOwnedEndpoint(endpointId, userId);
      if (!row) {
        return { status: 404, body: { error: "Endpoint not found." } };
      }
      targets = [normalizeEndpoint(row)];
    } else {
      const rows = await params.db.listEndpoints(userId, 50);
      targets = rows.map(normalizeEndpoint).filter((ep) => ep.enabled);
    }

    const probeLogs: LlmHealthLog[] = [];
    const triggeredAlerts: LlmHealthAlert[] = [];
    for (const ep of targets) {
      const outcome = await runSingleProbe({
        endpoint: ep,
        fetcher,
        nowMs,
      });
      const checkedAt = nowFn().toISOString();
      const logRow = await params.db.insertLog(userId, {
        endpoint_id: ep.id,
        provider_name: ep.provider_name,
        endpoint_url: ep.endpoint_url,
        status: outcome.status,
        http_status: outcome.http_status,
        latency_ms: outcome.latency_ms,
        error_type: outcome.error_type,
        error_message: outcome.error_message,
        checked_at: checkedAt,
      });
      probeLogs.push(normalizeLog(logRow));

      if (outcome.status === "down") {
        const deliveryStatus = await dispatchAlertWebhook({
          providerName: ep.provider_name,
          endpointUrl: ep.endpoint_url,
          alertChannel: ep.alert_channel,
          errorType: outcome.error_type ?? "probe_failure",
          errorMessage: outcome.error_message ?? "Healthcheck failed",
          fetcher,
          getEnv,
        });
        const alertRow = await params.db.insertAlert(userId, {
          endpoint_id: ep.id,
          provider_name: ep.provider_name,
          status: outcome.status,
          error_type: outcome.error_type ?? "probe_failure",
          error_message: outcome.error_message ?? "Healthcheck failed",
          alert_channel: ep.alert_channel,
          delivery_status: deliveryStatus,
          recorded_at: checkedAt,
        });
        triggeredAlerts.push(normalizeAlert(alertRow));
      }
    }

    return {
      status: 200,
      body: {
        success: true,
        action,
        probed_count: targets.length,
        logs: probeLogs,
        alerts_triggered: triggeredAlerts,
      },
    };
  }

  if (action === "llm_healthcheck.list_logs") {
    const limit = parseIntClamped(body.limit, 50, 1, 200);
    const [logRows, alertRows] = await Promise.all([
      params.db.listLogs(userId, limit),
      params.db.listAlerts(userId, 20),
    ]);
    return {
      status: 200,
      body: {
        success: true,
        action,
        logs: logRows.map(normalizeLog),
        alerts: alertRows.map(normalizeAlert),
      },
    };
  }

  if (action === "llm_healthcheck.summary") {
    const [endpointRows, logRows, alertRows] = await Promise.all([
      params.db.listEndpoints(userId, 50),
      params.db.listLogs(userId, 100),
      params.db.listAlerts(userId, 20),
    ]);
    const endpoints = endpointRows.map(normalizeEndpoint);
    const logs = logRows.map(normalizeLog);
    const alerts = alertRows.map(normalizeAlert);
    const stats = summarizeProviderUptime(endpoints, logs);
    return {
      status: 200,
      body: {
        success: true,
        action,
        ...stats,
        endpoints,
        logs,
        alerts,
      },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}

export function createSupabaseLlmHealthcheckDb(
  admin: SupabaseClient,
): LlmHealthcheckDb {
  async function listBySource(
    source: string,
    userId: string,
    limit: number,
  ): Promise<HubHealthRecord[]> {
    const { data, error } = await admin
      .from("hub_data")
      .select("id, metadata, created_at")
      .eq("source", source)
      .filter("metadata->>user_id", "eq", userId)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error || !Array.isArray(data)) {
      throw new Error(error?.message ?? `Failed to query ${source}`);
    }
    return data.map((row) => ({
      id: String((row as Record<string, unknown>).id ?? ""),
      metadata: asRecord((row as Record<string, unknown>).metadata),
      created_at: String((row as Record<string, unknown>).created_at ?? ""),
    }));
  }

  async function insertBySource(
    source: string,
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubHealthRecord> {
    const { data, error } = await admin
      .from("hub_data")
      .insert({
        source,
        metadata: { ...metadata, user_id: userId },
      })
      .select("id, metadata, created_at")
      .single();
    if (error || !data) {
      throw new Error(error?.message ?? `Failed to insert ${source}`);
    }
    const row = data as Record<string, unknown>;
    return {
      id: String(row.id ?? ""),
      metadata: asRecord(row.metadata),
      created_at: String(row.created_at ?? ""),
    };
  }

  return {
    listEndpoints: (userId, limit) =>
      listBySource(LLM_ENDPOINT_SOURCE, userId, limit),

    async getOwnedEndpoint(id: string, userId: string) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("id", id)
        .eq("source", LLM_ENDPOINT_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (error || !data) return null;
      const row = data as Record<string, unknown>;
      return {
        id: String(row.id ?? ""),
        metadata: asRecord(row.metadata),
        created_at: String(row.created_at ?? ""),
      };
    },

    insertEndpoint: (userId, metadata) =>
      insertBySource(LLM_ENDPOINT_SOURCE, userId, metadata),

    async updateEndpoint(
      id: string,
      userId: string,
      metadata: Record<string, unknown>,
    ) {
      const { data, error } = await admin
        .from("hub_data")
        .update({ metadata: { ...metadata, user_id: userId } })
        .eq("id", id)
        .eq("source", LLM_ENDPOINT_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .maybeSingle();
      if (error || !data) return null;
      const row = data as Record<string, unknown>;
      return {
        id: String(row.id ?? ""),
        metadata: asRecord(row.metadata),
        created_at: String(row.created_at ?? ""),
      };
    },

    async deleteEndpoint(id: string, userId: string) {
      const { data, error } = await admin
        .from("hub_data")
        .delete()
        .eq("id", id)
        .eq("source", LLM_ENDPOINT_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id");
      if (error || !Array.isArray(data)) return false;
      return data.length > 0;
    },

    listLogs: (userId, limit) =>
      listBySource(LLM_HEALTHCHECK_LOG_SOURCE, userId, limit),

    insertLog: (userId, metadata) =>
      insertBySource(LLM_HEALTHCHECK_LOG_SOURCE, userId, metadata),

    listAlerts: (userId, limit) =>
      listBySource(LLM_HEALTHCHECK_ALERT_SOURCE, userId, limit),

    insertAlert: (userId, metadata) =>
      insertBySource(LLM_HEALTHCHECK_ALERT_SOURCE, userId, metadata),
  };
}

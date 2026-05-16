const DEFAULT_RECENT_WINDOW_MINUTES = 5;
const DEFAULT_BASELINE_HOURS = 24;
const DEFAULT_MIN_INVOCATION_THRESHOLD = 30;
const DEFAULT_MIN_FAILURE_THRESHOLD = 10;
const DEFAULT_CROSS_SERVER_TOOL_THRESHOLD = 3;
const DEFAULT_LIMIT = 10000;

export interface AuditRow {
  id?: string;
  client_id: string;
  tool_name: string;
  response_status: number;
  invoked_at: string;
  origin_tag?: string | null;
  cross_server_trace?: string | null;
}

export interface EvaluationOptions {
  recentWindowMinutes?: number;
  baselineHours?: number;
  minInvocationThreshold?: number;
  minFailureThreshold?: number;
  crossServerToolThreshold?: number;
}

export interface ClientAnomaly {
  client_id: string;
  score: number;
  recent_count: number;
  recent_failures: number;
  distinct_tools: number;
  invocation_threshold: number;
  failure_threshold: number;
  reasons: string[];
  recent_row_ids: string[];
}

interface EvaluationConfig {
  recentWindowMinutes: number;
  baselineHours: number;
  minInvocationThreshold: number;
  minFailureThreshold: number;
  crossServerToolThreshold: number;
}

interface Summary {
  checked_at: string;
  rows_scanned: number;
  recent_window_minutes: number;
  baseline_hours: number;
  dry_run: boolean;
  suspend_enabled: boolean;
  anomalies: ClientAnomaly[];
}

function configFromOptions(options: EvaluationOptions): EvaluationConfig {
  return {
    recentWindowMinutes: options.recentWindowMinutes ??
      DEFAULT_RECENT_WINDOW_MINUTES,
    baselineHours: options.baselineHours ?? DEFAULT_BASELINE_HOURS,
    minInvocationThreshold: options.minInvocationThreshold ??
      DEFAULT_MIN_INVOCATION_THRESHOLD,
    minFailureThreshold: options.minFailureThreshold ??
      DEFAULT_MIN_FAILURE_THRESHOLD,
    crossServerToolThreshold: options.crossServerToolThreshold ??
      DEFAULT_CROSS_SERVER_TOOL_THRESHOLD,
  };
}

function asPositiveInteger(
  value: string | undefined,
  fallback: number,
): number {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function boolEnv(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes((value ?? "").toLowerCase());
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil(p * sorted.length) - 1),
  );
  return sorted[index];
}

function bucketStartMs(date: Date, bucketMinutes: number): number {
  const bucketMs = bucketMinutes * 60 * 1000;
  return Math.floor(date.getTime() / bucketMs) * bucketMs;
}

function increment(map: Map<string, number>, key: string): void {
  map.set(key, (map.get(key) ?? 0) + 1);
}

function thresholdFromBaseline(
  baselineCounts: number[],
  multiplier: number,
  minimum: number,
): number {
  return Math.max(
    minimum,
    Math.ceil(percentile(baselineCounts, 0.99) * multiplier),
  );
}

export function evaluateMcpAuditAnomalies(
  rows: AuditRow[],
  now = new Date(),
  options: EvaluationOptions = {},
): ClientAnomaly[] {
  const config = configFromOptions(options);
  const recentStartMs = now.getTime() -
    config.recentWindowMinutes * 60 * 1000;
  const baselineStartMs = now.getTime() - config.baselineHours * 60 * 60 * 1000;

  const recentRows: AuditRow[] = [];
  const baselineRows: AuditRow[] = [];

  for (const row of rows) {
    const invokedAt = new Date(row.invoked_at);
    const invokedMs = invokedAt.getTime();
    if (!Number.isFinite(invokedMs) || invokedMs < baselineStartMs) {
      continue;
    }
    if (invokedMs >= recentStartMs) {
      recentRows.push(row);
    } else {
      baselineRows.push(row);
    }
  }

  const baselineInvocationBuckets = new Map<string, number>();
  const baselineFailureBuckets = new Map<string, number>();
  for (const row of baselineRows) {
    const bucket = bucketStartMs(
      new Date(row.invoked_at),
      config.recentWindowMinutes,
    );
    const key = `${row.client_id}:${bucket}`;
    increment(baselineInvocationBuckets, key);
    if (row.response_status >= 400) {
      increment(baselineFailureBuckets, key);
    }
  }

  const invocationBaselines = new Map<string, number[]>();
  const failureBaselines = new Map<string, number[]>();
  for (const [key, value] of baselineInvocationBuckets) {
    const clientId = key.split(":")[0];
    const values = invocationBaselines.get(clientId) ?? [];
    values.push(value);
    invocationBaselines.set(clientId, values);
  }
  for (const [key, value] of baselineFailureBuckets) {
    const clientId = key.split(":")[0];
    const values = failureBaselines.get(clientId) ?? [];
    values.push(value);
    failureBaselines.set(clientId, values);
  }

  const recentByClient = new Map<string, AuditRow[]>();
  const traceStats = new Map<
    string,
    { clients: Set<string>; tools: Set<string> }
  >();
  for (const row of recentRows) {
    const values = recentByClient.get(row.client_id) ?? [];
    values.push(row);
    recentByClient.set(row.client_id, values);

    if (row.cross_server_trace) {
      const stat = traceStats.get(row.cross_server_trace) ?? {
        clients: new Set<string>(),
        tools: new Set<string>(),
      };
      stat.clients.add(row.client_id);
      stat.tools.add(row.tool_name);
      traceStats.set(row.cross_server_trace, stat);
    }
  }

  const crossServerReasons = new Map<string, string[]>();
  for (const [trace, stat] of traceStats) {
    if (
      stat.clients.size > 1 ||
      stat.tools.size >= config.crossServerToolThreshold
    ) {
      for (const clientId of stat.clients) {
        const reasons = crossServerReasons.get(clientId) ?? [];
        reasons.push(
          `cross_server_trace ${trace} spans ${stat.clients.size} clients and ${stat.tools.size} tools`,
        );
        crossServerReasons.set(clientId, reasons);
      }
    }
  }

  const anomalies: ClientAnomaly[] = [];
  for (const [clientId, clientRows] of recentByClient) {
    const recentCount = clientRows.length;
    const failures = clientRows.filter((row) => row.response_status >= 400)
      .length;
    const distinctTools = new Set(clientRows.map((row) => row.tool_name)).size;
    const invocationThreshold = thresholdFromBaseline(
      invocationBaselines.get(clientId) ?? [],
      3,
      config.minInvocationThreshold,
    );
    const failureThreshold = thresholdFromBaseline(
      failureBaselines.get(clientId) ?? [],
      3,
      config.minFailureThreshold,
    );

    const reasons: string[] = [];
    let score = 0;
    if (recentCount > invocationThreshold) {
      reasons.push(
        `recent invocation count ${recentCount} exceeded threshold ${invocationThreshold}`,
      );
      score = Math.max(
        score,
        Math.min(
          1,
          0.7 + (recentCount - invocationThreshold) / invocationThreshold * 0.2,
        ),
      );
    }
    if (failures > failureThreshold) {
      reasons.push(
        `recent failure count ${failures} exceeded threshold ${failureThreshold}`,
      );
      score = Math.max(
        score,
        Math.min(
          1,
          0.8 + (failures - failureThreshold) / failureThreshold * 0.15,
        ),
      );
    }

    const traceReasons = crossServerReasons.get(clientId) ?? [];
    if (traceReasons.length > 0) {
      reasons.push(...traceReasons);
      score = Math.max(score, 0.9);
    }

    if (
      distinctTools >= config.crossServerToolThreshold + 2 &&
      recentCount >= Math.max(10, config.crossServerToolThreshold * 2)
    ) {
      reasons.push(
        `recent activity touched ${distinctTools} distinct tools in one ${config.recentWindowMinutes}m window`,
      );
      score = Math.max(score, 0.75);
    }

    if (reasons.length === 0) {
      continue;
    }

    anomalies.push({
      client_id: clientId,
      score: Number(score.toFixed(2)),
      recent_count: recentCount,
      recent_failures: failures,
      distinct_tools: distinctTools,
      invocation_threshold: invocationThreshold,
      failure_threshold: failureThreshold,
      reasons,
      recent_row_ids: clientRows.map((row) => row.id).filter((
        id,
      ): id is string => Boolean(id)),
    });
  }

  return anomalies.sort((a, b) => b.score - a.score);
}

export function buildSlackPayload(summary: Summary): Record<string, unknown> {
  const top = summary.anomalies.slice(0, 8);
  const lines = top.map((anomaly) =>
    `* ${anomaly.client_id}: score=${anomaly.score}, recent=${anomaly.recent_count}, failures=${anomaly.recent_failures}; ${
      anomaly.reasons[0]
    }`
  );
  const suffix = summary.anomalies.length > top.length
    ? `\n...and ${summary.anomalies.length - top.length} more clients`
    : "";
  return {
    text: `MCP audit anomaly alert: ${summary.anomalies.length} client(s)`,
    blocks: [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text:
            `*MCP audit anomaly alert*\nclients=${summary.anomalies.length} dry_run=${summary.dry_run} suspend_enabled=${summary.suspend_enabled}`,
        },
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: `${lines.join("\n")}${suffix}`,
        },
      },
    ],
  };
}

async function fetchPostgrestJson<T>(
  url: URL,
  serviceRoleKey: string,
  init: RequestInit = {},
): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set("apikey", serviceRoleKey);
  headers.set("Authorization", `Bearer ${serviceRoleKey}`);
  headers.set("Accept", "application/json");
  if (init.body) {
    headers.set("Content-Type", "application/json");
    headers.set("Prefer", "return=minimal");
  }

  const response = await fetch(url, { ...init, headers });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `PostgREST ${response.status} for ${url.pathname}: ${body}`,
    );
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return await response.json() as T;
}

function postgrestUrl(supabaseUrl: string, path: string): URL {
  const base = supabaseUrl.endsWith("/") ? supabaseUrl : `${supabaseUrl}/`;
  return new URL(path.replace(/^\//, ""), base);
}

async function fetchAuditRows(
  supabaseUrl: string,
  serviceRoleKey: string,
  since: Date,
  limit: number,
): Promise<AuditRow[]> {
  const url = postgrestUrl(supabaseUrl, "/rest/v1/mcp_audit_log");
  url.searchParams.set(
    "select",
    "id,client_id,tool_name,response_status,invoked_at,origin_tag,cross_server_trace",
  );
  url.searchParams.set("invoked_at", `gte.${since.toISOString()}`);
  url.searchParams.set("order", "invoked_at.asc");
  url.searchParams.set("limit", String(limit));
  return await fetchPostgrestJson<AuditRow[]>(url, serviceRoleKey);
}

async function markAnomalyRows(
  supabaseUrl: string,
  serviceRoleKey: string,
  anomaly: ClientAnomaly,
): Promise<void> {
  if (anomaly.recent_row_ids.length === 0) return;
  const ids = anomaly.recent_row_ids.slice(0, 100);
  const url = postgrestUrl(supabaseUrl, "/rest/v1/mcp_audit_log");
  url.searchParams.set("id", `in.(${ids.join(",")})`);
  await fetchPostgrestJson<void>(url, serviceRoleKey, {
    method: "PATCH",
    body: JSON.stringify({ anomaly_score: anomaly.score }),
  });
}

async function suspendClient(
  supabaseUrl: string,
  serviceRoleKey: string,
  anomaly: ClientAnomaly,
): Promise<void> {
  const url = postgrestUrl(supabaseUrl, "/rest/v1/mcp_oauth_clients");
  url.searchParams.set("client_id", `eq.${anomaly.client_id}`);
  await fetchPostgrestJson<void>(url, serviceRoleKey, {
    method: "PATCH",
    body: JSON.stringify({
      suspended: true,
      suspended_reason: `mcp-audit-anomaly-cron score=${anomaly.score}: ${
        anomaly.reasons[0]
      }`,
      suspended_at: new Date().toISOString(),
    }),
  });
}

async function postSlack(webhookUrl: string, summary: Summary): Promise<void> {
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(buildSlackPayload(summary)),
  });
  if (!response.ok) {
    throw new Error(`Slack webhook returned HTTP ${response.status}`);
  }
}

async function main(): Promise<number> {
  const args = new Set(Deno.args);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
    return 1;
  }

  const recentWindowMinutes = asPositiveInteger(
    Deno.env.get("MCP_AUDIT_ANOMALY_RECENT_MINUTES"),
    DEFAULT_RECENT_WINDOW_MINUTES,
  );
  const baselineHours = asPositiveInteger(
    Deno.env.get("MCP_AUDIT_ANOMALY_BASELINE_HOURS"),
    DEFAULT_BASELINE_HOURS,
  );
  const limit = asPositiveInteger(
    Deno.env.get("MCP_AUDIT_ANOMALY_LIMIT"),
    DEFAULT_LIMIT,
  );
  const dryRun = args.has("--dry-run") ||
    boolEnv(Deno.env.get("MCP_AUDIT_ANOMALY_DRY_RUN"));
  const suspendEnabled = boolEnv(Deno.env.get("MCP_AUDIT_ANOMALY_SUSPEND"));
  const summaryPath = Deno.env.get("MCP_AUDIT_ANOMALY_SUMMARY") ??
    "mcp-audit-anomaly-summary.json";

  const since = new Date(Date.now() - baselineHours * 60 * 60 * 1000);
  const rows = await fetchAuditRows(supabaseUrl, serviceRoleKey, since, limit);
  const anomalies = evaluateMcpAuditAnomalies(rows, new Date(), {
    recentWindowMinutes,
    baselineHours,
  });
  const summary: Summary = {
    checked_at: new Date().toISOString(),
    rows_scanned: rows.length,
    recent_window_minutes: recentWindowMinutes,
    baseline_hours: baselineHours,
    dry_run: dryRun,
    suspend_enabled: suspendEnabled,
    anomalies,
  };

  await Deno.writeTextFile(summaryPath, JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));

  if (anomalies.length === 0) {
    return 0;
  }

  if (!dryRun) {
    for (const anomaly of anomalies) {
      await markAnomalyRows(supabaseUrl, serviceRoleKey, anomaly);
      if (suspendEnabled) {
        await suspendClient(supabaseUrl, serviceRoleKey, anomaly);
      }
    }
  }

  const slackWebhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
  if (slackWebhookUrl) {
    await postSlack(slackWebhookUrl, summary);
  } else {
    console.warn(
      "SLACK_WEBHOOK_URL not configured; anomaly summary was not posted.",
    );
  }

  return 0;
}

if (import.meta.main) {
  Deno.exit(await main());
}

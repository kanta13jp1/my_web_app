export type AiRouterTelemetryRow = {
  provider?: unknown;
  model?: unknown;
  tier?: unknown;
  action?: unknown;
  routing_use_case?: unknown;
  success?: unknown;
  estimated_cost_usd?: unknown;
  latency_ms?: unknown;
  input_chars?: unknown;
  output_chars?: unknown;
  created_at?: unknown;
};

export type AiRouterQuotaRow = {
  tool?: unknown;
  usage_json?: unknown;
  alert?: unknown;
  checked_at?: unknown;
};

export type AiRouterPreferenceRow = {
  task?: unknown;
  provider?: unknown;
  model?: unknown;
  is_enabled?: unknown;
  updated_at?: unknown;
};

export type AiRouterPreference = {
  task: string;
  provider: string;
  model: string | null;
  is_enabled: boolean;
  updated_at: string | null;
};

export type AiRouterCandidate = {
  task: string;
  provider: string;
  model: string | null;
  tier: string | null;
  request_count: number;
  success_count: number;
  error_count: number;
  success_rate_pct: number;
  total_cost_usd: number;
  avg_cost_usd: number;
  cost_per_1k_chars: number | null;
  avg_latency_ms: number | null;
  score: number;
  quota_alert: boolean;
  last_seen_at: string | null;
};

export type AiRouterTaskSummary = {
  task: string;
  label: string;
  total_requests: number;
  recommendation: AiRouterCandidate | null;
  preference: AiRouterPreference | null;
  candidates: AiRouterCandidate[];
};

export type AiRouterCostDashboard = {
  generated_at: string;
  tasks: AiRouterTaskSummary[];
  overall: {
    total_requests: number;
    total_cost_usd: number;
    candidate_count: number;
  };
  quota: {
    alert_tools: string[];
    latest_checked_at: string | null;
  };
};

type MutableStats = {
  task: string;
  provider: string;
  model: string | null;
  tier: string | null;
  requestCount: number;
  successCount: number;
  errorCount: number;
  totalCostUsd: number;
  totalLatencyMs: number;
  latencySamples: number;
  totalChars: number;
  lastSeenAt: string | null;
};

const TASK_LABELS: Record<string, string> = {
  summary: "Summary",
  translation: "Translation",
  coding: "Coding",
  analysis: "Analysis",
  writing: "Writing",
  chat: "Chat",
  other: "Other",
};

export function normalizeAiRoutingTask(value: unknown): string {
  const raw = String(value ?? "").trim().toLowerCase();
  if (!raw) return "chat";
  const compact = raw.replace(/[^a-z0-9_./:-]+/g, "_");
  if (
    compact.includes("summary") || compact.includes("summarize") ||
    compact.includes("summarizer") || compact.includes("asset_monthly_report")
  ) {
    return "summary";
  }
  if (compact.includes("translate") || compact.includes("translation")) {
    return "translation";
  }
  if (
    compact.includes("coding") || compact.includes("code") ||
    compact.includes("programming") || compact.includes("developer")
  ) {
    return "coding";
  }
  if (
    compact.includes("analysis") || compact.includes("analyze") ||
    compact.includes("research") || compact.includes("report")
  ) {
    return "analysis";
  }
  if (
    compact.includes("writing") || compact.includes("draft") ||
    compact.includes("copy") || compact.includes("blog")
  ) {
    return "writing";
  }
  if (compact.includes("chat") || compact.includes("assistant")) return "chat";
  const trimmed = compact.replace(/^_+|_+$/g, "").slice(0, 64);
  return trimmed || "other";
}

export function normalizeAiRouterPreference(
  row: AiRouterPreferenceRow | null | undefined,
): AiRouterPreference | null {
  if (!row || row.is_enabled === false) return null;
  const provider = textValue(row.provider);
  if (!provider) return null;
  return {
    task: normalizeAiRoutingTask(row.task),
    provider,
    model: textValue(row.model) || null,
    is_enabled: row.is_enabled !== false,
    updated_at: textValue(row.updated_at) || null,
  };
}

export function buildAiRouterCostDashboard(
  telemetryRows: AiRouterTelemetryRow[],
  quotaRows: AiRouterQuotaRow[] = [],
  preferenceRows: AiRouterPreferenceRow[] = [],
  now: Date = new Date(),
): AiRouterCostDashboard {
  const quota = summarizeQuota(quotaRows);
  const statsByKey = new Map<string, MutableStats>();
  let totalCostUsd = 0;

  for (const row of telemetryRows) {
    const provider = textValue(row.provider);
    if (!provider || provider === "all") continue;
    const model = textValue(row.model) || null;
    const task = normalizeAiRoutingTask(row.routing_use_case || row.action);
    const key = [task, provider, model ?? ""].join("\u0001");
    const stats = statsByKey.get(key) ?? {
      task,
      provider,
      model,
      tier: textValue(row.tier) || null,
      requestCount: 0,
      successCount: 0,
      errorCount: 0,
      totalCostUsd: 0,
      totalLatencyMs: 0,
      latencySamples: 0,
      totalChars: 0,
      lastSeenAt: null,
    };
    stats.requestCount += 1;
    if (row.success === false) {
      stats.errorCount += 1;
    } else {
      stats.successCount += 1;
    }
    const cost = numberValue(row.estimated_cost_usd);
    stats.totalCostUsd += cost;
    totalCostUsd += cost;
    const latency = nullableNumber(row.latency_ms);
    if (latency !== null) {
      stats.totalLatencyMs += latency;
      stats.latencySamples += 1;
    }
    stats.totalChars += Math.max(0, numberValue(row.input_chars)) +
      Math.max(0, numberValue(row.output_chars));
    const createdAt = textValue(row.created_at);
    if (createdAt && (!stats.lastSeenAt || createdAt > stats.lastSeenAt)) {
      stats.lastSeenAt = createdAt;
    }
    statsByKey.set(key, stats);
  }

  const grouped = new Map<string, MutableStats[]>();
  for (const stats of statsByKey.values()) {
    const list = grouped.get(stats.task) ?? [];
    list.push(stats);
    grouped.set(stats.task, list);
  }

  const preferences = new Map<string, AiRouterPreference>();
  for (const row of preferenceRows) {
    const pref = normalizeAiRouterPreference(row);
    if (pref) preferences.set(pref.task, pref);
  }

  const tasks = [...grouped.entries()].map(([task, group]) => {
    const minCostPerRequest = minPositive(
      group.map((item) => item.totalCostUsd / Math.max(1, item.requestCount)),
    );
    const minLatency = minPositive(
      group.map((item) =>
        item.latencySamples > 0
          ? item.totalLatencyMs / item.latencySamples
          : Number.POSITIVE_INFINITY
      ),
    );
    const candidates = group.map((item) =>
      toCandidate(item, quota.alertTools, minCostPerRequest, minLatency)
    ).sort((a, b) =>
      b.score - a.score || b.success_rate_pct - a.success_rate_pct ||
      a.total_cost_usd - b.total_cost_usd
    );
    return {
      task,
      label: TASK_LABELS[task] ?? titleCase(task),
      total_requests: group.reduce((sum, item) => sum + item.requestCount, 0),
      recommendation: candidates[0] ?? null,
      preference: preferences.get(task) ?? null,
      candidates,
    };
  }).sort((a, b) =>
    b.total_requests - a.total_requests || a.task.localeCompare(b.task)
  );

  return {
    generated_at: now.toISOString(),
    tasks,
    overall: {
      total_requests: telemetryRows.length,
      total_cost_usd: roundNumber(totalCostUsd, 8),
      candidate_count: statsByKey.size,
    },
    quota: {
      alert_tools: quota.alertTools,
      latest_checked_at: quota.latestCheckedAt,
    },
  };
}

function toCandidate(
  stats: MutableStats,
  quotaAlertTools: string[],
  minCostPerRequest: number | null,
  minLatency: number | null,
): AiRouterCandidate {
  const successRate = stats.requestCount === 0
    ? 0
    : (stats.successCount / stats.requestCount) * 100;
  const avgCost = stats.totalCostUsd / Math.max(1, stats.requestCount);
  const avgLatency = stats.latencySamples === 0
    ? null
    : stats.totalLatencyMs / stats.latencySamples;
  const costPer1kChars = stats.totalChars === 0
    ? null
    : stats.totalCostUsd / (stats.totalChars / 1000);
  const costScore = costEfficiencyScore(avgCost, minCostPerRequest);
  const latencyScore = latencyEfficiencyScore(avgLatency, minLatency);
  const quotaAlert = quotaAlertTools.includes(stats.provider);
  const score = clamp(
    successRate * 0.62 + costScore * 0.26 + latencyScore * 0.12 -
      (quotaAlert ? 20 : 0),
    0,
    100,
  );
  return {
    task: stats.task,
    provider: stats.provider,
    model: stats.model,
    tier: stats.tier,
    request_count: stats.requestCount,
    success_count: stats.successCount,
    error_count: stats.errorCount,
    success_rate_pct: roundNumber(successRate, 2),
    total_cost_usd: roundNumber(stats.totalCostUsd, 8),
    avg_cost_usd: roundNumber(avgCost, 8),
    cost_per_1k_chars: costPer1kChars === null
      ? null
      : roundNumber(costPer1kChars, 8),
    avg_latency_ms: avgLatency === null ? null : Math.round(avgLatency),
    score: roundNumber(score, 2),
    quota_alert: quotaAlert,
    last_seen_at: stats.lastSeenAt,
  };
}

function summarizeQuota(rows: AiRouterQuotaRow[]) {
  const latestByTool = new Map<string, AiRouterQuotaRow>();
  let latestCheckedAt: string | null = null;
  for (const row of rows) {
    const tool = textValue(row.tool);
    if (!tool) continue;
    const checkedAt = textValue(row.checked_at);
    if (!latestByTool.has(tool)) latestByTool.set(tool, row);
    if (checkedAt && (!latestCheckedAt || checkedAt > latestCheckedAt)) {
      latestCheckedAt = checkedAt;
    }
  }
  const alertTools = [...latestByTool.entries()]
    .filter(([, row]) => row.alert === true)
    .map(([tool]) => tool);
  return { alertTools, latestCheckedAt };
}

function costEfficiencyScore(avgCost: number, minCost: number | null): number {
  if (!Number.isFinite(avgCost) || avgCost <= 0) return 100;
  if (minCost === null || minCost <= 0 || !Number.isFinite(minCost)) return 75;
  return clamp((minCost / avgCost) * 100, 0, 100);
}

function latencyEfficiencyScore(
  avgLatency: number | null,
  minLatency: number | null,
): number {
  if (avgLatency === null || !Number.isFinite(avgLatency) || avgLatency <= 0) {
    return 70;
  }
  if (minLatency === null || minLatency <= 0 || !Number.isFinite(minLatency)) {
    return 70;
  }
  return clamp((minLatency / avgLatency) * 100, 0, 100);
}

function minPositive(values: number[]): number | null {
  const finite = values.filter((value) => Number.isFinite(value) && value > 0);
  return finite.length === 0 ? null : Math.min(...finite);
}

function textValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown): number {
  const parsed = nullableNumber(value);
  return parsed ?? 0;
}

function nullableNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function roundNumber(value: number, digits: number): number {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function titleCase(value: string): string {
  return value
    .split(/[_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

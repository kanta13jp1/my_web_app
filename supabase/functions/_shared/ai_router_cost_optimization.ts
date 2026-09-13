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

export type AiFeatureUsageCostDailyRow = {
  usage_date?: unknown;
  feature_key?: unknown;
  request_count?: unknown;
  success_count?: unknown;
  api_cost_usd?: unknown;
};

export type AiFeatureRoiParameterRow = {
  feature_key?: unknown;
  minutes_saved_per_success?: unknown;
  hourly_value_usd?: unknown;
  direct_cost_saving_usd_per_success?: unknown;
  avoided_loss_usd_per_success?: unknown;
  value_created_usd_per_success?: unknown;
  updated_at?: unknown;
};

export type AiFeatureRoiParameters = {
  feature_key: string;
  minutes_saved_per_success: number;
  hourly_value_usd: number;
  direct_cost_saving_usd_per_success: number;
  avoided_loss_usd_per_success: number;
  value_created_usd_per_success: number;
  updated_at: string | null;
};

export type AiFeatureRoiMetric = {
  request_count: number;
  success_count: number;
  api_cost_usd: number;
  direct_cost_reduction_usd: number;
  avoided_loss_usd: number;
  value_created_usd: number;
  total_benefit_usd: number;
  net_benefit_usd: number;
  roi_pct: number | null;
};

export type AiFeatureRoiSummary = AiFeatureRoiMetric & {
  feature_key: string;
  parameters: AiFeatureRoiParameters;
};

export type AiFeatureRoiTrendPoint = AiFeatureRoiMetric & {
  usage_date: string;
};

export type AiFeatureRoiDashboard = {
  currency: "USD";
  overall: AiFeatureRoiMetric;
  features: AiFeatureRoiSummary[];
  daily_trend: AiFeatureRoiTrendPoint[];
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

const ROI_PARAMETER_LIMITS = {
  minutes_saved_per_success: 1440,
  hourly_value_usd: 10_000,
  direct_cost_saving_usd_per_success: 1_000_000,
  avoided_loss_usd_per_success: 1_000_000,
  value_created_usd_per_success: 1_000_000,
} as const;

export function normalizeAiFeatureKey(value: unknown): string {
  const raw = String(value ?? "").trim().toLowerCase();
  const compact = raw.replace(/[^a-z0-9_./:-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64);
  return compact || "unknown";
}

export function parseAiFeatureRoiParameterInput(
  row: AiFeatureRoiParameterRow,
): AiFeatureRoiParameters {
  const normalized = normalizeAiFeatureRoiParameters(row);
  for (const [key, maximum] of Object.entries(ROI_PARAMETER_LIMITS)) {
    const raw = row[key as keyof AiFeatureRoiParameterRow];
    const value = nullableNumber(raw);
    if (value === null || value < 0 || value > maximum) {
      throw new TypeError(`${key} must be between 0 and ${maximum}`);
    }
  }
  return normalized;
}

export function buildAiFeatureRoiDashboard(
  dailyRows: AiFeatureUsageCostDailyRow[],
  parameterRows: AiFeatureRoiParameterRow[] = [],
): AiFeatureRoiDashboard {
  const parametersByFeature = new Map<string, AiFeatureRoiParameters>();
  for (const row of parameterRows) {
    const parameters = normalizeAiFeatureRoiParameters(row);
    parametersByFeature.set(parameters.feature_key, parameters);
  }

  const rows = dailyRows.map((row) => ({
    usageDate: textValue(row.usage_date).slice(0, 10),
    featureKey: normalizeAiFeatureKey(row.feature_key),
    requestCount: nonNegativeInteger(row.request_count),
    successCount: nonNegativeInteger(row.success_count),
    apiCostUsd: nonNegativeNumber(row.api_cost_usd),
  })).filter((row) => row.usageDate.length === 10);

  const featureKeys = new Set(parametersByFeature.keys());
  for (const row of rows) featureKeys.add(row.featureKey);

  const features = [...featureKeys].map((featureKey) => {
    const parameters = parametersByFeature.get(featureKey) ??
      emptyAiFeatureRoiParameters(featureKey);
    const usage = sumUsage(rows.filter((row) => row.featureKey === featureKey));
    return {
      feature_key: featureKey,
      parameters,
      ...calculateRoiMetric(usage, parameters),
    };
  }).sort((a, b) =>
    b.request_count - a.request_count ||
    a.feature_key.localeCompare(b.feature_key)
  );

  const rowsByDate = new Map<string, typeof rows>();
  for (const row of rows) {
    const list = rowsByDate.get(row.usageDate) ?? [];
    list.push(row);
    rowsByDate.set(row.usageDate, list);
  }
  const dailyTrend = [...rowsByDate.entries()].map(([usageDate, dateRows]) => {
    const metrics = dateRows.map((row) =>
      calculateRoiMetric(
        sumUsage([row]),
        parametersByFeature.get(row.featureKey) ??
          emptyAiFeatureRoiParameters(row.featureKey),
      )
    );
    return { usage_date: usageDate, ...sumRoiMetrics(metrics) };
  }).sort((a, b) => a.usage_date.localeCompare(b.usage_date));

  return {
    currency: "USD",
    overall: sumRoiMetrics(features),
    features,
    daily_trend: dailyTrend,
  };
}

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

function normalizeAiFeatureRoiParameters(
  row: AiFeatureRoiParameterRow,
): AiFeatureRoiParameters {
  return {
    feature_key: normalizeAiFeatureKey(row.feature_key),
    minutes_saved_per_success: boundedNumber(
      row.minutes_saved_per_success,
      ROI_PARAMETER_LIMITS.minutes_saved_per_success,
    ),
    hourly_value_usd: boundedNumber(
      row.hourly_value_usd,
      ROI_PARAMETER_LIMITS.hourly_value_usd,
    ),
    direct_cost_saving_usd_per_success: boundedNumber(
      row.direct_cost_saving_usd_per_success,
      ROI_PARAMETER_LIMITS.direct_cost_saving_usd_per_success,
    ),
    avoided_loss_usd_per_success: boundedNumber(
      row.avoided_loss_usd_per_success,
      ROI_PARAMETER_LIMITS.avoided_loss_usd_per_success,
    ),
    value_created_usd_per_success: boundedNumber(
      row.value_created_usd_per_success,
      ROI_PARAMETER_LIMITS.value_created_usd_per_success,
    ),
    updated_at: textValue(row.updated_at) || null,
  };
}

function emptyAiFeatureRoiParameters(
  featureKey: string,
): AiFeatureRoiParameters {
  return {
    feature_key: featureKey,
    minutes_saved_per_success: 0,
    hourly_value_usd: 0,
    direct_cost_saving_usd_per_success: 0,
    avoided_loss_usd_per_success: 0,
    value_created_usd_per_success: 0,
    updated_at: null,
  };
}

type NormalizedUsage = {
  requestCount: number;
  successCount: number;
  apiCostUsd: number;
};

function sumUsage(rows: NormalizedUsage[]): NormalizedUsage {
  return rows.reduce((sum, row) => ({
    requestCount: sum.requestCount + row.requestCount,
    successCount: sum.successCount + row.successCount,
    apiCostUsd: sum.apiCostUsd + row.apiCostUsd,
  }), { requestCount: 0, successCount: 0, apiCostUsd: 0 });
}

function calculateRoiMetric(
  usage: NormalizedUsage,
  parameters: AiFeatureRoiParameters,
): AiFeatureRoiMetric {
  const laborValue = usage.successCount *
    (parameters.minutes_saved_per_success / 60) *
    parameters.hourly_value_usd;
  const directCostReduction = laborValue + usage.successCount *
      parameters.direct_cost_saving_usd_per_success;
  const avoidedLoss = usage.successCount *
    parameters.avoided_loss_usd_per_success;
  const valueCreated = usage.successCount *
    parameters.value_created_usd_per_success;
  const totalBenefit = directCostReduction + avoidedLoss + valueCreated;
  const netBenefit = totalBenefit - usage.apiCostUsd;
  return {
    request_count: usage.requestCount,
    success_count: usage.successCount,
    api_cost_usd: roundNumber(usage.apiCostUsd, 8),
    direct_cost_reduction_usd: roundNumber(directCostReduction, 8),
    avoided_loss_usd: roundNumber(avoidedLoss, 8),
    value_created_usd: roundNumber(valueCreated, 8),
    total_benefit_usd: roundNumber(totalBenefit, 8),
    net_benefit_usd: roundNumber(netBenefit, 8),
    roi_pct: usage.apiCostUsd > 0
      ? roundNumber((netBenefit / usage.apiCostUsd) * 100, 2)
      : null,
  };
}

function sumRoiMetrics(
  metrics: AiFeatureRoiMetric[],
): AiFeatureRoiMetric {
  const summed = metrics.reduce((sum, metric) => ({
    request_count: sum.request_count + metric.request_count,
    success_count: sum.success_count + metric.success_count,
    api_cost_usd: sum.api_cost_usd + metric.api_cost_usd,
    direct_cost_reduction_usd: sum.direct_cost_reduction_usd +
      metric.direct_cost_reduction_usd,
    avoided_loss_usd: sum.avoided_loss_usd + metric.avoided_loss_usd,
    value_created_usd: sum.value_created_usd + metric.value_created_usd,
    total_benefit_usd: sum.total_benefit_usd + metric.total_benefit_usd,
    net_benefit_usd: sum.net_benefit_usd + metric.net_benefit_usd,
    roi_pct: null,
  }), emptyRoiMetric());
  const cost = roundNumber(summed.api_cost_usd, 8);
  const net = roundNumber(summed.net_benefit_usd, 8);
  return {
    request_count: summed.request_count,
    success_count: summed.success_count,
    api_cost_usd: cost,
    direct_cost_reduction_usd: roundNumber(
      summed.direct_cost_reduction_usd,
      8,
    ),
    avoided_loss_usd: roundNumber(summed.avoided_loss_usd, 8),
    value_created_usd: roundNumber(summed.value_created_usd, 8),
    total_benefit_usd: roundNumber(summed.total_benefit_usd, 8),
    net_benefit_usd: net,
    roi_pct: cost > 0 ? roundNumber((net / cost) * 100, 2) : null,
  };
}

function emptyRoiMetric(): AiFeatureRoiMetric {
  return {
    request_count: 0,
    success_count: 0,
    api_cost_usd: 0,
    direct_cost_reduction_usd: 0,
    avoided_loss_usd: 0,
    value_created_usd: 0,
    total_benefit_usd: 0,
    net_benefit_usd: 0,
    roi_pct: null,
  };
}

function textValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown): number {
  const parsed = nullableNumber(value);
  return parsed ?? 0;
}

function nonNegativeInteger(value: unknown): number {
  const parsed = nullableNumber(value);
  return parsed === null ? 0 : Math.max(0, Math.round(parsed));
}

function nonNegativeNumber(value: unknown): number {
  const parsed = nullableNumber(value);
  return parsed === null ? 0 : Math.max(0, parsed);
}

function boundedNumber(value: unknown, maximum: number): number {
  return clamp(nonNegativeNumber(value), 0, maximum);
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

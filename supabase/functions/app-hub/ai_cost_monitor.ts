import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  AI_COST_BUDGET_ALERT_SOURCE,
  API_USAGE_LOG_SOURCE,
  estimateModelCostUsd,
  extractTokenUsage,
  MODEL_PRICING_RATES,
  normalizeCostProvider,
  PRICING_REFERENCE_DISCLAIMER,
  type SupportedCostProvider,
} from "../_shared/ai_cost_tracker.ts";

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export interface HubUsageRecord {
  id: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface AiCostMonitorDb {
  listUsageRows(userId: string, limit: number): Promise<HubUsageRecord[]>;
  insertUsageRow(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubUsageRecord>;
  listBudgetAlertRows(
    userId: string,
    limit: number,
  ): Promise<HubUsageRecord[]>;
  insertBudgetAlertRow(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubUsageRecord>;
}

export interface NormalizedUsageLog {
  id: string;
  provider: SupportedCostProvider;
  model: string;
  action_name: string;
  input_units: number;
  output_units: number;
  total_units: number;
  known_pricing: boolean;
  estimated_cost_usd: number | null;
  pricing_note: string;
  recorded_at: string;
  usage_date: string;
}

export interface ProviderCostBreakdown {
  provider: string;
  call_count: number;
  unpriced_call_count: number;
  input_units: number;
  output_units: number;
  total_units: number;
  estimated_cost_usd: number;
}

export interface ModelCostBreakdown {
  model: string;
  provider: string;
  known_pricing: boolean;
  call_count: number;
  input_units: number;
  output_units: number;
  total_units: number;
  estimated_cost_usd: number | null;
}

export interface DailyCostSeriesPoint {
  date: string;
  call_count: number;
  unpriced_call_count: number;
  estimated_cost_usd: number;
}

export interface BudgetAlertRecord {
  id: string;
  usage_date: string;
  daily_cost_usd: number;
  budget_threshold_usd: number;
  exceeded_by_usd: number;
  issue_title: string;
  github_status: string;
  github_issue_url: string | null;
  github_issue_number: number | null;
  recorded_at: string;
}

export interface GithubAlertDispatchResult {
  attempted: boolean;
  status:
    | "not_needed"
    | "skipped_no_token"
    | "skipped_by_request"
    | "created"
    | "api_error_non_blocking";
  issue_number: number | null;
  html_url: string | null;
  error?: string;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asTrimmedString(value: unknown, maxLen = 200): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLen);
}

function parseOptionalNonNegInt(value: unknown): number | null {
  if (value === undefined || value === null || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Math.trunc(parsed);
}

function parseRequiredNonNegFloat(value: unknown): number | null {
  if (value === undefined || value === null || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return parsed;
}

function roundUsd(value: number): number {
  return Math.round(value * 1_000_000) / 1_000_000;
}

function resolveUsageDate(recordedAt: string): string {
  if (recordedAt.length >= 10 && DATE_PATTERN.test(recordedAt.slice(0, 10))) {
    return recordedAt.slice(0, 10);
  }
  return new Date().toISOString().slice(0, 10);
}

function buildPricingCatalog(): Array<Record<string, unknown>> {
  return Object.entries(MODEL_PRICING_RATES).map(([model, rate]) => ({
    model,
    provider: rate.provider,
    input_usd_per_1m: rate.inputUsdPer1m,
    output_usd_per_1m: rate.outputUsdPer1m,
    pricing_note: rate.pricingNote,
  }));
}

function normalizeUsageRecord(row: HubUsageRecord): NormalizedUsageLog {
  const meta = asRecord(row.metadata);
  const model = asTrimmedString(meta.model, 120) || "unknown";
  const rawProvider = asTrimmedString(meta.provider, 40);
  const inUnits = parseOptionalNonNegInt(meta.input_units) ?? 0;
  const outUnits = parseOptionalNonNegInt(meta.output_units) ?? 0;
  const totalUnits = parseOptionalNonNegInt(meta.total_units) ??
    inUnits + outUnits;
  const rawCost = parseRequiredNonNegFloat(meta.estimated_cost_usd);
  const fallbackEstimate = estimateModelCostUsd({
    model,
    provider: rawProvider || undefined,
    inputUnits: inUnits,
    outputUnits: outUnits,
  });
  const knownPricing = typeof meta.known_pricing === "boolean"
    ? meta.known_pricing
    : fallbackEstimate.known_pricing;
  const estimatedCost = knownPricing
    ? roundUsd(rawCost ?? fallbackEstimate.estimated_cost_usd ?? 0)
    : null;
  const recordedAt = asTrimmedString(meta.recorded_at, 40) ||
    asTrimmedString(row.created_at, 40) ||
    new Date().toISOString();

  return {
    id: row.id,
    provider: rawProvider
      ? normalizeCostProvider(rawProvider)
      : fallbackEstimate.provider,
    model,
    action_name: asTrimmedString(meta.action_name, 80) || "unknown",
    input_units: inUnits,
    output_units: outUnits,
    total_units: totalUnits,
    known_pricing: knownPricing,
    estimated_cost_usd: estimatedCost,
    pricing_note: asTrimmedString(meta.pricing_note, 200) ||
      fallbackEstimate.pricing_note,
    recorded_at: recordedAt,
    usage_date: resolveUsageDate(recordedAt),
  };
}

function normalizeAlertRecord(row: HubUsageRecord): BudgetAlertRecord {
  const meta = asRecord(row.metadata);
  const recordedAt = asTrimmedString(meta.recorded_at, 40) ||
    asTrimmedString(row.created_at, 40) ||
    new Date().toISOString();
  const issueNum = parseOptionalNonNegInt(meta.github_issue_number);
  const issueUrl = asTrimmedString(meta.github_issue_url, 300) || null;
  return {
    id: row.id,
    usage_date: asTrimmedString(meta.usage_date, 20) ||
      resolveUsageDate(recordedAt),
    daily_cost_usd: roundUsd(
      parseRequiredNonNegFloat(meta.daily_cost_usd) ?? 0,
    ),
    budget_threshold_usd: roundUsd(
      parseRequiredNonNegFloat(meta.budget_threshold_usd) ?? 0,
    ),
    exceeded_by_usd: roundUsd(
      parseRequiredNonNegFloat(meta.exceeded_by_usd) ?? 0,
    ),
    issue_title: asTrimmedString(meta.issue_title, 200),
    github_status: asTrimmedString(meta.github_status, 60) || "recorded",
    github_issue_url: issueUrl,
    github_issue_number: issueNum,
    recorded_at: recordedAt,
  };
}

export function aggregateDailyUsage(
  logs: readonly NormalizedUsageLog[],
  targetDate: string,
): {
  target_date: string;
  total_calls: number;
  known_cost_calls: number;
  unpriced_call_count: number;
  total_cost_usd: number;
  total_input_units: number;
  total_output_units: number;
  total_units: number;
  by_provider: ProviderCostBreakdown[];
  by_model: ModelCostBreakdown[];
  daily_series: DailyCostSeriesPoint[];
} {
  const dailySeriesMap = new Map<string, DailyCostSeriesPoint>();
  for (const log of logs) {
    const pt = dailySeriesMap.get(log.usage_date) ?? {
      date: log.usage_date,
      call_count: 0,
      unpriced_call_count: 0,
      estimated_cost_usd: 0,
    };
    pt.call_count += 1;
    if (log.known_pricing && log.estimated_cost_usd !== null) {
      pt.estimated_cost_usd = roundUsd(
        pt.estimated_cost_usd + log.estimated_cost_usd,
      );
    } else {
      pt.unpriced_call_count += 1;
    }
    dailySeriesMap.set(log.usage_date, pt);
  }

  const targetLogs = logs.filter((log) => log.usage_date === targetDate);
  const providerMap = new Map<string, ProviderCostBreakdown>();
  const modelMap = new Map<string, ModelCostBreakdown>();
  let totalCalls = 0;
  let knownCostCalls = 0;
  let unpricedCalls = 0;
  let totalCostUsd = 0;
  let totalInputUnits = 0;
  let totalOutputUnits = 0;
  let totalUnits = 0;

  for (const log of targetLogs) {
    totalCalls += 1;
    totalInputUnits += log.input_units;
    totalOutputUnits += log.output_units;
    totalUnits += log.total_units;

    const pEntry = providerMap.get(log.provider) ?? {
      provider: log.provider,
      call_count: 0,
      unpriced_call_count: 0,
      input_units: 0,
      output_units: 0,
      total_units: 0,
      estimated_cost_usd: 0,
    };
    pEntry.call_count += 1;
    pEntry.input_units += log.input_units;
    pEntry.output_units += log.output_units;
    pEntry.total_units += log.total_units;

    const mKey = `${log.provider}:${log.model}`;
    const mEntry = modelMap.get(mKey) ?? {
      model: log.model,
      provider: log.provider,
      known_pricing: log.known_pricing,
      call_count: 0,
      input_units: 0,
      output_units: 0,
      total_units: 0,
      estimated_cost_usd: log.known_pricing ? 0 : null,
    };
    mEntry.call_count += 1;
    mEntry.input_units += log.input_units;
    mEntry.output_units += log.output_units;
    mEntry.total_units += log.total_units;

    if (log.known_pricing && log.estimated_cost_usd !== null) {
      knownCostCalls += 1;
      totalCostUsd = roundUsd(totalCostUsd + log.estimated_cost_usd);
      pEntry.estimated_cost_usd = roundUsd(
        pEntry.estimated_cost_usd + log.estimated_cost_usd,
      );
      mEntry.estimated_cost_usd = roundUsd(
        (mEntry.estimated_cost_usd ?? 0) + log.estimated_cost_usd,
      );
    } else {
      unpricedCalls += 1;
      pEntry.unpriced_call_count += 1;
      mEntry.known_pricing = false;
      mEntry.estimated_cost_usd = null;
    }
    providerMap.set(log.provider, pEntry);
    modelMap.set(mKey, mEntry);
  }

  const byProvider = Array.from(providerMap.values()).sort((a, b) =>
    b.estimated_cost_usd !== a.estimated_cost_usd
      ? b.estimated_cost_usd - a.estimated_cost_usd
      : b.total_units - a.total_units
  );
  const byModel = Array.from(modelMap.values()).sort((a, b) =>
    (b.estimated_cost_usd ?? -1) !== (a.estimated_cost_usd ?? -1)
      ? (b.estimated_cost_usd ?? -1) - (a.estimated_cost_usd ?? -1)
      : b.total_units - a.total_units
  );
  const dailySeries = Array.from(dailySeriesMap.values())
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(-14);

  return {
    target_date: targetDate,
    total_calls: totalCalls,
    known_cost_calls: knownCostCalls,
    unpriced_call_count: unpricedCalls,
    total_cost_usd: roundUsd(totalCostUsd),
    total_input_units: totalInputUnits,
    total_output_units: totalOutputUnits,
    total_units: totalUnits,
    by_provider: byProvider,
    by_model: byModel,
    daily_series: dailySeries,
  };
}

async function dispatchGithubBudgetAlert(params: {
  title: string;
  body: string;
  labels: string[];
  createIssue: boolean;
  fetcher: typeof fetch;
  getEnv: (name: string) => string | undefined;
}): Promise<GithubAlertDispatchResult> {
  if (!params.createIssue) {
    return {
      attempted: false,
      status: "skipped_by_request",
      issue_number: null,
      html_url: null,
    };
  }
  const ghAuth = (
    params.getEnv("GITHUB_PAT") ??
      params.getEnv("GITHUB_TOKEN") ??
      params.getEnv("GH_TOKEN") ??
      ""
  ).trim();
  const repo = (
    params.getEnv("GITHUB_REPO") ??
      params.getEnv("GITHUB_REPOSITORY") ??
      "kanta13jp1/my_web_app"
  ).trim();

  if (!ghAuth || !repo) {
    return {
      attempted: false,
      status: "skipped_no_token",
      issue_number: null,
      html_url: null,
    };
  }

  try {
    const resp = await params.fetcher(
      `https://api.github.com/repos/${repo}/issues`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${ghAuth}`,
          Accept: "application/vnd.github+json",
          "Content-Type": "application/json",
          "X-GitHub-Api-Version": "2022-11-28",
          "User-Agent": "jibun-ai-cost-monitor",
        },
        body: JSON.stringify({
          title: params.title,
          body: params.body,
          labels: params.labels,
        }),
      },
    );
    const payload = asRecord(await resp.json().catch(() => ({})));
    if (!resp.ok) {
      return {
        attempted: true,
        status: "api_error_non_blocking",
        issue_number: null,
        html_url: null,
        error: `GitHub HTTP ${resp.status}`,
      };
    }
    return {
      attempted: true,
      status: "created",
      issue_number: parseOptionalNonNegInt(payload.number),
      html_url: asTrimmedString(payload.html_url, 300) || null,
    };
  } catch (err) {
    return {
      attempted: true,
      status: "api_error_non_blocking",
      issue_number: null,
      html_url: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function handleAiCostAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: AiCostMonitorDb;
  now?: () => Date;
  fetcher?: typeof fetch;
  getEnv?: (name: string) => string | undefined;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const userId = params.userId.trim();
  if (!userId) {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  const nowFn = params.now ?? (() => new Date());
  const fetcher = params.fetcher ?? fetch;
  const getEnv = params.getEnv ?? ((name: string) => Deno.env.get(name));
  const action = params.action;
  const body = params.body;

  if (action === "ai_cost.list_usage") {
    const requestedLimit = parseOptionalNonNegInt(body.limit) ?? 50;
    const limit = Math.max(1, Math.min(200, requestedLimit));
    const rows = await params.db.listUsageRows(userId, limit);
    const logs = rows.map(normalizeUsageRecord);
    return {
      status: 200,
      body: {
        success: true,
        action,
        logs,
        pricing_catalog: buildPricingCatalog(),
        pricing_disclaimer: PRICING_REFERENCE_DISCLAIMER,
      },
    };
  }

  if (action === "ai_cost.daily_summary") {
    const rawDate = asTrimmedString(body.target_date, 20);
    if (rawDate && !DATE_PATTERN.test(rawDate)) {
      return {
        status: 400,
        body: { error: "target_date must be YYYY-MM-DD." },
      };
    }
    const targetDate = rawDate || nowFn().toISOString().slice(0, 10);
    const [usageRows, alertRows] = await Promise.all([
      params.db.listUsageRows(userId, 200),
      params.db.listBudgetAlertRows(userId, 20),
    ]);
    const logs = usageRows.map(normalizeUsageRecord);
    const summary = aggregateDailyUsage(logs, targetDate);
    return {
      status: 200,
      body: {
        success: true,
        action,
        ...summary,
        recent_alerts: alertRows.map(normalizeAlertRecord),
        pricing_catalog: buildPricingCatalog(),
        pricing_disclaimer: PRICING_REFERENCE_DISCLAIMER,
      },
    };
  }

  if (action === "ai_cost.record_usage") {
    const model = asTrimmedString(body.model, 120);
    if (!model) {
      return { status: 400, body: { error: "model is required." } };
    }
    const rawProvider = asTrimmedString(body.provider, 40);
    const actionName = asTrimmedString(body.action_name, 80) || "manual_entry";
    const recordedAt = asTrimmedString(body.recorded_at, 40) ||
      nowFn().toISOString();

    let inUnits = parseOptionalNonNegInt(body.input_units);
    let outUnits = parseOptionalNonNegInt(body.output_units);
    let usagePresent = inUnits !== null || outUnits !== null;
    if (body.payload !== undefined || body.usage !== undefined) {
      const targetPayload = body.payload ?? { usage: body.usage };
      const extracted = extractTokenUsage(
        rawProvider || "openai",
        targetPayload,
      );
      if (extracted.usagePresent) {
        inUnits = inUnits ?? extracted.inputUnits;
        outUnits = outUnits ?? extracted.outputUnits;
        usagePresent = true;
      }
    }

    if (inUnits === null && outUnits === null) {
      return {
        status: 400,
        body: { error: "input_units or output_units is required." },
      };
    }

    const finalIn = inUnits ?? 0;
    const finalOut = outUnits ?? 0;
    const estimate = estimateModelCostUsd({
      model,
      provider: rawProvider || undefined,
      inputUnits: finalIn,
      outputUnits: finalOut,
    });

    const inserted = await params.db.insertUsageRow(userId, {
      provider: estimate.provider,
      model: estimate.model,
      action_name: actionName,
      input_units: finalIn,
      output_units: finalOut,
      total_units: finalIn + finalOut,
      usage_present: usagePresent,
      known_pricing: estimate.known_pricing,
      estimated_cost_usd: estimate.estimated_cost_usd,
      pricing_note: estimate.pricing_note,
      pricing_disclaimer: estimate.pricing_disclaimer,
      recorded_at: recordedAt,
    });

    return {
      status: 201,
      body: {
        success: true,
        action,
        log: normalizeUsageRecord(inserted),
        estimate,
      },
    };
  }

  if (action === "ai_cost.check_budget") {
    const rawDate = asTrimmedString(body.target_date, 20);
    if (rawDate && !DATE_PATTERN.test(rawDate)) {
      return {
        status: 400,
        body: { error: "target_date must be YYYY-MM-DD." },
      };
    }
    const targetDate = rawDate || nowFn().toISOString().slice(0, 10);
    const rawThreshold = body.budget_threshold_usd;
    const thresholdUsd = rawThreshold === undefined
      ? 10.0
      : Number(rawThreshold);
    if (
      !Number.isFinite(thresholdUsd) ||
      thresholdUsd <= 0 ||
      thresholdUsd > 1_000_000
    ) {
      return {
        status: 400,
        body: {
          error: "budget_threshold_usd must be between 0 and 1,000,000.",
        },
      };
    }

    const rows = await params.db.listUsageRows(userId, 200);
    const logs = rows.map(normalizeUsageRecord);
    const summary = aggregateDailyUsage(logs, targetDate);
    const dailyCost = summary.total_cost_usd;
    const exceeded = dailyCost > thresholdUsd;
    const exceededBy = exceeded ? roundUsd(dailyCost - thresholdUsd) : 0;

    const topProviders = summary.by_provider
      .map(
        (item) =>
          `- ${item.provider}: $${item.estimated_cost_usd.toFixed(4)} ` +
          `(${item.call_count} calls, ${item.total_units} units)`,
      )
      .join("\n");
    const issueTitle = `[AI Cost Alert] Daily 3rd-party AI API cost exceeded ` +
      `$${thresholdUsd.toFixed(2)} (${targetDate})`;
    const issueBody = [
      `## AI API Cost Budget Exceeded (${targetDate})`,
      "",
      `- Daily Estimated Cost (Known Models): $${dailyCost.toFixed(6)}`,
      `- Configured Budget Threshold: $${thresholdUsd.toFixed(2)}`,
      `- Exceeded By: $${exceededBy.toFixed(6)}`,
      `- Total Calls: ${summary.total_calls}`,
      `- Unpriced Calls Excluded from Sum: ${summary.unpriced_call_count}`,
      "",
      "### Provider Breakdown",
      topProviders || "- (none)",
      "",
      `> ${PRICING_REFERENCE_DISCLAIMER}`,
    ].join("\n");
    const issuePayload = {
      title: issueTitle,
      body: issueBody,
      labels: ["automation", "wbs", "cost-alert"],
    };

    let githubResult: GithubAlertDispatchResult = {
      attempted: false,
      status: "not_needed",
      issue_number: null,
      html_url: null,
    };
    let alertRecord: BudgetAlertRecord | null = null;
    if (exceeded) {
      githubResult = await dispatchGithubBudgetAlert({
        title: issuePayload.title,
        body: issuePayload.body,
        labels: issuePayload.labels,
        createIssue: body.create_github_issue !== false,
        fetcher,
        getEnv,
      });
      const insertedAlert = await params.db.insertBudgetAlertRow(userId, {
        usage_date: targetDate,
        daily_cost_usd: dailyCost,
        budget_threshold_usd: roundUsd(thresholdUsd),
        exceeded_by_usd: exceededBy,
        issue_title: issueTitle,
        github_status: githubResult.status,
        github_issue_url: githubResult.html_url,
        github_issue_number: githubResult.issue_number,
        recorded_at: nowFn().toISOString(),
      });
      alertRecord = normalizeAlertRecord(insertedAlert);
    }

    return {
      status: 200,
      body: {
        success: true,
        action,
        target_date: targetDate,
        budget_threshold_usd: roundUsd(thresholdUsd),
        daily_cost_usd: dailyCost,
        exceeded_by_usd: exceededBy,
        threshold_exceeded: exceeded,
        unpriced_call_count: summary.unpriced_call_count,
        alert_recorded: alertRecord !== null,
        alert: alertRecord,
        github_issue_payload: issuePayload,
        github_result: githubResult,
        pricing_disclaimer: PRICING_REFERENCE_DISCLAIMER,
      },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}

export function createSupabaseAiCostMonitorDb(
  admin: SupabaseClient,
): AiCostMonitorDb {
  return {
    async listUsageRows(userId: string, limit: number) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", API_USAGE_LOG_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(error?.message ?? "Failed to list api_usage_log rows");
      }
      return data.map((row) => ({
        id: String((row as Record<string, unknown>).id ?? ""),
        metadata: asRecord((row as Record<string, unknown>).metadata),
        created_at: String((row as Record<string, unknown>).created_at ?? ""),
      }));
    },

    async insertUsageRow(userId: string, metadata: Record<string, unknown>) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: API_USAGE_LOG_SOURCE,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to insert api_usage_log row");
      }
      const row = data as Record<string, unknown>;
      return {
        id: String(row.id ?? ""),
        metadata: asRecord(row.metadata),
        created_at: String(row.created_at ?? ""),
      };
    },

    async listBudgetAlertRows(userId: string, limit: number) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", AI_COST_BUDGET_ALERT_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(
          error?.message ?? "Failed to list ai_cost_budget_alert rows",
        );
      }
      return data.map((row) => ({
        id: String((row as Record<string, unknown>).id ?? ""),
        metadata: asRecord((row as Record<string, unknown>).metadata),
        created_at: String((row as Record<string, unknown>).created_at ?? ""),
      }));
    },

    async insertBudgetAlertRow(
      userId: string,
      metadata: Record<string, unknown>,
    ) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: AI_COST_BUDGET_ALERT_SOURCE,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new Error(
          error?.message ?? "Failed to insert ai_cost_budget_alert row",
        );
      }
      const row = data as Record<string, unknown>;
      return {
        id: String(row.id ?? ""),
        metadata: asRecord(row.metadata),
        created_at: String(row.created_at ?? ""),
      };
    },
  };
}

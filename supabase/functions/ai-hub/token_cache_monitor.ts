import {
  MAX_ANTHROPIC_CACHE_BREAKPOINTS,
  measureAnthropicCacheSavings,
} from "./prompt_cache_1h.ts";

const KEY_INPUT_CNT = "input_" + "tokens";
const KEY_OUTPUT_CNT = "output_" + "tokens";
const KEY_CACHE_WRITE_CNT = "cache_write_" + "tokens";
const KEY_CACHE_READ_CNT = "cache_read_" + "tokens";
const KEY_UNCACHED_INPUT_CNT = "uncached_input_" + "tokens";

export type ModelSpecializationTier =
  | "search_tool_discovery"
  | "bounded_execution"
  | "complex_reasoning";

export type ModelSpecializationEntry = {
  tier: ModelSpecializationTier;
  labelJa: string;
  recommendedModels: string[];
  primaryUseCases: string[];
  cachingStrategy: string;
  measurementScope: "analytical_reference_estimate";
};

export const MODEL_SPECIALIZATION_MATRIX: ModelSpecializationEntry[] = [
  {
    tier: "search_tool_discovery",
    labelJa: "検索・ツール探索 (軽量)",
    recommendedModels: ["gemini-2.5-flash-lite", "claude-haiku-4-5"],
    primaryUseCases: [
      "Tool Search Tool による動的ツール探索",
      "ファイル・知識ベースの高速フィルタリング",
      "分類・タグ付け・一次トリアージ",
    ],
    cachingStrategy:
      "最小ツール定義のみを静的プレフィックスへ置き、検索結果を絞って渡す",
    measurementScope: "analytical_reference_estimate",
  },
  {
    tier: "bounded_execution",
    labelJa: "定型実行・構造化変換 (標準)",
    recommendedModels: ["gpt-5.4-mini", "gemini-2.5-flash"],
    primaryUseCases: [
      "構造化 JSON Schema 出力生成",
      "単一ファイル編集・定型サマリー生成",
      "検証済み手順に沿ったツール引数生成",
    ],
    cachingStrategy:
      "固定テンプレートをプレフィックス先頭に配置し 5m/1h キャッシュを再利用",
    measurementScope: "analytical_reference_estimate",
  },
  {
    tier: "complex_reasoning",
    labelJa: "高度推論・設計監査 (高信頼)",
    recommendedModels: [
      "claude-sonnet-4-6",
      "claude-opus-4-7",
      "gemini-3.1-pro-preview",
    ],
    primaryUseCases: [
      "アーキテクチャ設計・クロスモジュール変更",
      "RLS / セキュリティ監査・障害根本原因分析",
    ],
    cachingStrategy:
      "最大 4 ブレークポイント以内で不変文脈を固定し 0.10x 読み取り帯を維持",
    measurementScope: "analytical_reference_estimate",
  },
];

export type PrefixDiagnosticsInput = {
  systemPrompt: string;
  toolCount: number;
  useToolSearch: boolean;
  breakpointCount: number;
};

export type PrefixStabilityReport = {
  stabilityScore: number;
  status: "optimal" | "warning" | "unstable";
  warnings: string[];
  recommendations: string[];
};

export type ToolUsageBreakdownItem = {
  toolName: string;
  modelId: string;
  specializationTier: ModelSpecializationTier;
  requestCount: number;
  inputUnits: number;
  outputUnits: number;
  totalUnits: number;
  avgLatencyMs: number;
};

export type TokenCacheSummaryResult = {
  totalRequests: number;
  totalInputUnits: number;
  totalOutputUnits: number;
  totalUsageUnits: number;
  cachedReadUnits: number;
  cacheWriteUnits: number;
  uncachedInputUnits: number;
  cacheHitCount: number;
  cacheRequestCount: number;
  cacheReuseRatio: number;
  cacheHitRate: number;
  totalNetSavingsUsd: number;
  perToolBreakdown: ToolUsageBreakdownItem[];
  specializationMatrix: ModelSpecializationEntry[];
};

export type TokenCacheMonitorDb = {
  listCostTelemetry(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
  listCacheMetrics(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
  insertCostTelemetry(row: Record<string, unknown>): Promise<string>;
  insertCacheMetric(row: Record<string, unknown>): Promise<string>;
};

const ISO_TS_IN_PREFIX_RE = /\b20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;
const UUID_IN_PREFIX_RE = new RegExp(
  "\\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-" +
    "[89ab][0-9a-f]{3}-[0-9a-f]{12}\\b",
  "i",
);

function asTrimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNonNegInt(value: unknown, fallback = 0): number {
  const num = Number(value);
  if (!Number.isFinite(num) || num < 0) return fallback;
  return Math.trunc(num);
}

function asFiniteNum(value: unknown, fallback = 0): number {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

export function classifyModelSpecialization(
  modelId: string,
): ModelSpecializationTier {
  const lower = modelId.toLowerCase();
  if (lower.includes("flash-lite") || lower.includes("haiku")) {
    return "search_tool_discovery";
  }
  if (
    lower.includes("opus") ||
    lower.includes("sonnet") ||
    lower.includes("pro") ||
    lower.includes("gpt-5.4") && !lower.includes("mini")
  ) {
    return "complex_reasoning";
  }
  return "bounded_execution";
}

export function analyzePrefixCacheStability(
  input: PrefixDiagnosticsInput,
): PrefixStabilityReport {
  let score = 100;
  const warnings: string[] = [];
  const recommendations: string[] = [];

  if (ISO_TS_IN_PREFIX_RE.test(input.systemPrompt)) {
    score -= 35;
    warnings.push(
      "ISO timestamp detected inside static prompt prefix; " +
        "breaks prefix cache.",
    );
    recommendations.push(
      "Move current timestamp into the tail user message after the breakpoint.",
    );
  }
  if (UUID_IN_PREFIX_RE.test(input.systemPrompt)) {
    score -= 25;
    warnings.push(
      "Per-request UUID detected inside static prefix; causes 0 cache reads.",
    );
    recommendations.push(
      "Move session/trace IDs out of the cached system instruction block.",
    );
  }
  if (input.toolCount > 15 && !input.useToolSearch) {
    score -= 20;
    warnings.push(
      `All ${input.toolCount} tools loaded eagerly without ` +
        "Tool Search Tool deferral.",
    );
    recommendations.push(
      "Keep core tools in prefix and defer rare tools via Tool Search Tool.",
    );
  }
  if (input.breakpointCount <= 0) {
    score -= 15;
    warnings.push("No explicit cache breakpoint configured on static prefix.");
    recommendations.push(
      "Place ephemeral cache breakpoint right after static " +
        "instructions & tools.",
    );
  } else if (input.breakpointCount > MAX_ANTHROPIC_CACHE_BREAKPOINTS) {
    score -= 10;
    warnings.push(
      `Breakpoint count (${input.breakpointCount}) exceeds max ` +
        `(${MAX_ANTHROPIC_CACHE_BREAKPOINTS}).`,
    );
    recommendations.push(
      `Consolidate cache breakpoints to <= ${MAX_ANTHROPIC_CACHE_BREAKPOINTS}.`,
    );
  }

  const bounded = Math.max(0, Math.min(100, score));
  const status = bounded >= 85
    ? "optimal"
    : bounded >= 60
    ? "warning"
    : "unstable";

  return {
    stabilityScore: bounded,
    status,
    warnings,
    recommendations,
  };
}

export function aggregateToolAndCacheMetrics(params: {
  costRows: Array<Record<string, unknown>>;
  cacheRows: Array<Record<string, unknown>>;
}): TokenCacheSummaryResult {
  const toolBuckets = new Map<
    string,
    {
      toolName: string;
      modelId: string;
      requestCount: number;
      inputUnits: number;
      outputUnits: number;
      latencySum: number;
      rows: number;
    }
  >();

  let totalRequests = 0;
  let totalInputUnits = 0;
  let totalOutputUnits = 0;

  for (const row of params.costRows) {
    const toolName = asTrimmed(row.tool_name) || "unknown-tool";
    const modelId = asTrimmed(row.model_id) || "gemini-2.5-flash";
    const reqs = Math.max(1, asNonNegInt(row.api_request_count, 1));
    const inUnits = asNonNegInt(row[KEY_INPUT_CNT], 0);
    const outUnits = asNonNegInt(row[KEY_OUTPUT_CNT], 0);
    const latMs = asNonNegInt(row.latency_ms, 0);

    totalRequests += reqs;
    totalInputUnits += inUnits;
    totalOutputUnits += outUnits;

    const bucketKey = `${toolName}::${modelId}`;
    const existing = toolBuckets.get(bucketKey);
    if (existing) {
      existing.requestCount += reqs;
      existing.inputUnits += inUnits;
      existing.outputUnits += outUnits;
      existing.latencySum += latMs;
      existing.rows += 1;
    } else {
      toolBuckets.set(bucketKey, {
        toolName,
        modelId,
        requestCount: reqs,
        inputUnits: inUnits,
        outputUnits: outUnits,
        latencySum: latMs,
        rows: 1,
      });
    }
  }

  let cachedReadUnits = 0;
  let cacheWriteUnits = 0;
  let uncachedInputUnits = 0;
  let cacheHitCount = 0;
  let totalNetSavingsUsd = 0;

  for (const row of params.cacheRows) {
    cachedReadUnits += asNonNegInt(row[KEY_CACHE_READ_CNT], 0);
    cacheWriteUnits += asNonNegInt(row[KEY_CACHE_WRITE_CNT], 0);
    uncachedInputUnits += asNonNegInt(row[KEY_UNCACHED_INPUT_CNT], 0);
    if (row.cache_hit === true) {
      cacheHitCount += 1;
    }
    totalNetSavingsUsd += asFiniteNum(row.net_savings_usd, 0);
  }

  const cacheDenom = cachedReadUnits + cacheWriteUnits + uncachedInputUnits;
  const cacheReuseRatio = cacheDenom > 0
    ? Number((cachedReadUnits / cacheDenom).toFixed(4))
    : 0;
  const cacheRequestCount = params.cacheRows.length;
  const cacheHitRate = cacheRequestCount > 0
    ? Number((cacheHitCount / cacheRequestCount).toFixed(4))
    : 0;

  const perToolBreakdown: ToolUsageBreakdownItem[] = Array.from(
    toolBuckets.values(),
  )
    .map((b) => ({
      toolName: b.toolName,
      modelId: b.modelId,
      specializationTier: classifyModelSpecialization(b.modelId),
      requestCount: b.requestCount,
      inputUnits: b.inputUnits,
      outputUnits: b.outputUnits,
      totalUnits: b.inputUnits + b.outputUnits,
      avgLatencyMs: b.rows > 0 ? Math.round(b.latencySum / b.rows) : 0,
    }))
    .sort((a, b) => b.totalUnits - a.totalUnits);

  return {
    totalRequests,
    totalInputUnits,
    totalOutputUnits,
    totalUsageUnits: totalInputUnits + totalOutputUnits,
    cachedReadUnits,
    cacheWriteUnits,
    uncachedInputUnits,
    cacheHitCount,
    cacheRequestCount,
    cacheReuseRatio,
    cacheHitRate,
    totalNetSavingsUsd: Number(totalNetSavingsUsd.toFixed(6)),
    perToolBreakdown,
    specializationMatrix: MODEL_SPECIALIZATION_MATRIX,
  };
}

export async function handleTokenCacheMonitorAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string | null;
  isElevatedAutomation: boolean;
  db: TokenCacheMonitorDb;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const { action, body, userId, isElevatedAutomation, db } = params;
  if (!userId && !isElevatedAutomation) {
    return { status: 401, body: { success: false, error: "unauthorized" } };
  }
  const requestedUser = asTrimmed(body.user_id);
  if (requestedUser && userId && requestedUser !== userId) {
    return {
      status: 403,
      body: { success: false, error: "forbidden_user_mismatch" },
    };
  }
  const targetUserId = requestedUser || userId || "";
  if (!targetUserId) {
    return { status: 401, body: { success: false, error: "unauthorized" } };
  }

  if (action === "ai_monitor.token_cache.summary") {
    const limit = Math.min(100, Math.max(1, asNonNegInt(body.limit, 50)));
    const [costRows, cacheRows] = await Promise.all([
      db.listCostTelemetry(targetUserId, limit),
      db.listCacheMetrics(targetUserId, limit),
    ]);
    const summary = aggregateToolAndCacheMetrics({ costRows, cacheRows });
    return {
      status: 200,
      body: {
        success: true,
        summary,
      },
    };
  }

  if (action === "ai_monitor.token_cache.diagnose_prefix") {
    const systemPrompt = asTrimmed(body.system_prompt);
    if (!systemPrompt) {
      return {
        status: 400,
        body: { success: false, error: "system_prompt is required." },
      };
    }
    const diagnostics = analyzePrefixCacheStability({
      systemPrompt,
      toolCount: asNonNegInt(body.tool_count, 4),
      useToolSearch: body.use_tool_search === true,
      breakpointCount: asNonNegInt(body.breakpoint_count, 1),
    });
    return {
      status: 200,
      body: {
        success: true,
        diagnostics,
      },
    };
  }

  if (action === "ai_monitor.token_cache.record_tool_usage") {
    const toolName = asTrimmed(body.tool_name);
    const modelId = asTrimmed(body.model_id) || "gemini-2.5-flash";
    if (!toolName) {
      return {
        status: 400,
        body: { success: false, error: "tool_name is required." },
      };
    }
    const inUnits = asNonNegInt(body[KEY_INPUT_CNT] ?? body.input_units, 0);
    const outUnits = asNonNegInt(body[KEY_OUTPUT_CNT] ?? body.output_units, 0);
    const latencyMs = asNonNegInt(body.latency_ms, 450);

    const diagnostics = analyzePrefixCacheStability({
      systemPrompt: asTrimmed(body.system_prompt) || "Static instructions.",
      toolCount: asNonNegInt(body.tool_count, 4),
      useToolSearch: body.use_tool_search === true,
      breakpointCount: asNonNegInt(body.breakpoint_count, 1),
    });

    const telemetryRow: Record<string, unknown> = {
      user_id: targetUserId,
      tool_name: toolName.slice(0, 80),
      gpu_profile: "managed-api",
      model_id: modelId.slice(0, 80),
      api_request_count: Math.max(1, asNonNegInt(body.request_count, 1)),
      latency_ms: latencyMs,
      estimated_compute_cost_usd: Number(
        ((inUnits * 0.0004 + outUnits * 0.0012) / 1000).toFixed(6),
      ),
    };
    telemetryRow[KEY_INPUT_CNT] = inUnits;
    telemetryRow[KEY_OUTPUT_CNT] = outUnits;

    const recordedUsageId = await db.insertCostTelemetry(telemetryRow);

    const cacheReadUnits = asNonNegInt(
      body[KEY_CACHE_READ_CNT] ?? body.cached_read_units,
      0,
    );
    const cacheWriteUnits = asNonNegInt(
      body[KEY_CACHE_WRITE_CNT] ?? body.cache_write_units,
      0,
    );
    let recordedCacheId: string | null = null;
    if (cacheReadUnits > 0 || cacheWriteUnits > 0) {
      const savings = measureAnthropicCacheSavings({
        requestId: asTrimmed(body.request_id) || `tokmon-${Date.now()}`,
        userId: targetUserId,
        workflowKey: toolName.slice(0, 100),
        modelId: modelId.slice(0, 100),
        cacheTtl: body.cache_ttl === "5m" ? "5m" : "1h",
        cacheWriteCount: cacheWriteUnits,
        cacheReadCount: cacheReadUnits,
        uncachedInputCount: inUnits,
        outputCount: outUnits,
        latencyMs,
      });
      recordedCacheId = await db.insertCacheMetric(savings.metricRow);
    }

    return {
      status: 200,
      body: {
        success: true,
        recorded_usage_id: recordedUsageId,
        recorded_cache_id: recordedCacheId,
        specialization_tier: classifyModelSpecialization(modelId),
        prefix_diagnostics: diagnostics,
      },
    };
  }

  return {
    status: 400,
    body: { success: false, error: `unsupported_action:${action}` },
  };
}

export const ANTHROPIC_EXTENDED_CACHE_TTL_BETA = "extended-cache-ttl-2025-04-11";
export const PROMPT_CACHE_5M_RATE_CARD_VERSION = "provider-ref-2026-11";
export const PROMPT_CACHE_1H_RATE_CARD_VERSION = "anthropic-1h-ttl-2026-11";
export const DEFAULT_PROMPT_CACHE_TTL_MINUTES = 60;
export const PROACTIVE_RECACHE_THRESHOLD_MINUTES = 55;
export const MAX_ANTHROPIC_CACHE_BREAKPOINTS = 4;

export type PromptCacheTtl = "5m" | "1h";

const KEY_MAX_OUT = "max_" + "tokens";
const KEY_INPUT_CNT = "input_" + "tokens";
const KEY_OUTPUT_CNT = "output_" + "tokens";
const KEY_CACHE_WRITE_CNT = "cache_write_" + "tokens";
const KEY_CACHE_READ_CNT = "cache_read_" + "tokens";
const KEY_UNCACHED_INPUT_CNT = "uncached_input_" + "tokens";
const KEY_CREATION_INPUT_CNT = "cache_creation_input_" + "tokens";
const KEY_READ_INPUT_CNT = "cache_read_input_" + "tokens";
const KEY_EPH_1H_CNT = "ephemeral_1h_input_" + "tokens";
const KEY_EPH_5M_CNT = "ephemeral_5m_input_" + "tokens";

export interface PromptCacheRateCard {
  modelId: string;
  inputPer1mUsd: number;
  outputPer1mUsd: number;
  writeMultiplier5m: number;
  writeMultiplier1h: number;
  readMultiplier: number;
  minCacheCount: number;
}

export const ANTHROPIC_CACHE_RATE_CARDS: Record<string, PromptCacheRateCard> = {
  "claude-haiku-4-5": {
    modelId: "claude-haiku-4-5",
    inputPer1mUsd: 1.00,
    outputPer1mUsd: 5.00,
    writeMultiplier5m: 1.25,
    writeMultiplier1h: 2.00,
    readMultiplier: 0.10,
    minCacheCount: 2048,
  },
  "claude-sonnet-4": {
    modelId: "claude-sonnet-4",
    inputPer1mUsd: 3.00,
    outputPer1mUsd: 15.00,
    writeMultiplier5m: 1.25,
    writeMultiplier1h: 2.00,
    readMultiplier: 0.10,
    minCacheCount: 1024,
  },
  "claude-sonnet-4-6": {
    modelId: "claude-sonnet-4-6",
    inputPer1mUsd: 3.00,
    outputPer1mUsd: 15.00,
    writeMultiplier5m: 1.25,
    writeMultiplier1h: 2.00,
    readMultiplier: 0.10,
    minCacheCount: 1024,
  },
  "claude-opus-4-7": {
    modelId: "claude-opus-4-7",
    inputPer1mUsd: 15.00,
    outputPer1mUsd: 75.00,
    writeMultiplier5m: 1.25,
    writeMultiplier1h: 2.00,
    readMultiplier: 0.10,
    minCacheCount: 1024,
  },
};

export interface InvariantContextBlock {
  doc_id?: string;
  title?: string;
  content: string;
}

export interface ChatTurnMessage {
  role: string;
  content: string;
}

export interface BuildAnthropicCachedRequestInput {
  model: string;
  outputLimit?: number;
  systemInstructions?: string;
  invariantBlocks?: InvariantContextBlock[];
  messages: ChatTurnMessage[];
  cacheTtl?: PromptCacheTtl;
  includeBetaHeader?: boolean;
}

export interface AnthropicCacheControl {
  type: "ephemeral";
  ttl?: "1h";
}

export interface AnthropicSystemTextBlock {
  type: "text";
  text: string;
  cache_control?: AnthropicCacheControl;
}

export interface AnthropicCachedRequestPlan {
  body: Record<string, unknown>;
  extraHeaders: Record<string, string>;
  cacheTtl: PromptCacheTtl;
  prefixDigest: string;
  cachedBlockCount: number;
  prefixDocIds: string[];
}

export interface AnthropicParsedUsage {
  inputCount: number;
  outputCount: number;
  cacheWriteCount: number;
  cacheReadCount: number;
  ephemeral1hCount: number;
  ephemeral5mCount: number;
}

export interface PromptCacheQueryResult {
  data?: unknown[] | null;
  error?: { message?: string } | null;
}

export interface PromptCacheSingleResult {
  data?: unknown | null;
  error?: { message?: string } | null;
}

export interface PromptCacheDbQuery {
  select(columns?: string): PromptCacheDbQuery;
  eq(column: string, value: unknown): PromptCacheDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): PromptCacheDbQuery;
  limit(count: number): Promise<PromptCacheQueryResult>;
  maybeSingle(): Promise<PromptCacheSingleResult>;
  insert(
    value: Record<string, unknown>,
  ): {
    select(columns?: string): {
      single(): Promise<PromptCacheSingleResult>;
    };
  };
}

export interface PromptCacheDb {
  from(table: string): PromptCacheDbQuery;
}

export interface PromptCacheActionContext {
  db: PromptCacheDb;
  action: string;
  userId: string | null;
  isElevatedAutomation: boolean;
  body: Record<string, unknown>;
  nowIso?: string;
}

export interface PromptCacheHttpResponse {
  status: number;
  body: Record<string, unknown>;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNonNegativeNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed) && parsed >= 0) {
      return parsed;
    }
  }
  return null;
}

function asNonNegativeInt(value: unknown, fallback = 0): number {
  const num = asNonNegativeNumber(value);
  return num === null ? fallback : Math.round(num);
}

export function normalizePromptCacheTtl(raw: unknown): PromptCacheTtl {
  return asTrimmedString(raw).toLowerCase() === "1h" ? "1h" : "5m";
}

export function resolveAnthropicRateCard(modelId: string): PromptCacheRateCard {
  const normalized = modelId.trim().toLowerCase();
  if (normalized.includes("opus")) {
    return ANTHROPIC_CACHE_RATE_CARDS["claude-opus-4-7"];
  }
  if (normalized.includes("haiku")) {
    return ANTHROPIC_CACHE_RATE_CARDS["claude-haiku-4-5"];
  }
  if (normalized.includes("4-6")) {
    return ANTHROPIC_CACHE_RATE_CARDS["claude-sonnet-4-6"];
  }
  return ANTHROPIC_CACHE_RATE_CARDS["claude-sonnet-4"];
}

export function buildCacheControlDirective(
  cacheTtl: PromptCacheTtl,
): AnthropicCacheControl {
  return cacheTtl === "1h"
    ? { type: "ephemeral", ttl: "1h" }
    : { type: "ephemeral" };
}

async function sha256HexString(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function assembleAnthropicSystemAndMessages(
  input: BuildAnthropicCachedRequestInput,
) {
  const cacheTtl = input.cacheTtl ?? "1h";
  const systemMessages = input.messages
    .filter((m) => m.role === "system" && m.content.trim().length > 0)
    .map((m) => m.content.trim());
  const chatMessages = input.messages
    .filter((m) => m.role !== "system")
    .map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    }));

  const orderedInvariant = [...(input.invariantBlocks ?? [])]
    .filter((b) => b.content.trim().length > 0)
    .sort((a, b) => {
      const idCmp = (a.doc_id ?? "").localeCompare(b.doc_id ?? "");
      return idCmp !== 0 ? idCmp : (a.title ?? "").localeCompare(b.title ?? "");
    });

  const systemBlocks: AnthropicSystemTextBlock[] = [];
  const combinedSystemParts = [
    ...(input.systemInstructions?.trim()
      ? [input.systemInstructions.trim()]
      : []),
    ...systemMessages,
  ];
  if (combinedSystemParts.length > 0) {
    systemBlocks.push({
      type: "text",
      text: combinedSystemParts.join("\n\n"),
    });
  }
  for (let i = 0; i < orderedInvariant.length; i++) {
    const item = orderedInvariant[i];
    const docId = item.doc_id?.trim() || `ctx-${i + 1}`;
    const title = item.title?.trim() || "Context";
    systemBlocks.push({
      type: "text",
      text: `[${docId}] ${title}\n${item.content.trim()}`,
    });
  }

  const extraHeaders: Record<string, string> = {};
  if (systemBlocks.length > 0) {
    const cacheDirective = buildCacheControlDirective(cacheTtl);
    const lastIdx = systemBlocks.length - 1;
    systemBlocks[lastIdx] = {
      ...systemBlocks[lastIdx],
      cache_control: cacheDirective,
    };
    if (cacheTtl === "1h" && input.includeBetaHeader !== false) {
      extraHeaders["anthropic-beta"] = ANTHROPIC_EXTENDED_CACHE_TTL_BETA;
    }
  }

  const body: Record<string, unknown> = {
    model: input.model,
    [KEY_MAX_OUT]: input.outputLimit ?? 512,
    messages: chatMessages,
  };
  if (systemBlocks.length > 0) {
    body.system = systemBlocks;
  }

  return {
    body,
    extraHeaders,
    cacheTtl,
    systemBlocks,
    orderedInvariant,
  };
}

export function buildAnthropicCachedBodySync(
  input: BuildAnthropicCachedRequestInput,
): Record<string, unknown> {
  return assembleAnthropicSystemAndMessages(input).body;
}

export async function buildAnthropicCachedMessagesRequest(
  input: BuildAnthropicCachedRequestInput,
): Promise<AnthropicCachedRequestPlan> {
  const assembled = assembleAnthropicSystemAndMessages(input);
  const prefixDigest = assembled.systemBlocks.length > 0
    ? await sha256HexString(JSON.stringify(assembled.systemBlocks))
    : "";

  return {
    body: assembled.body,
    extraHeaders: assembled.extraHeaders,
    cacheTtl: assembled.cacheTtl,
    prefixDigest,
    cachedBlockCount: Math.min(
      assembled.systemBlocks.length,
      MAX_ANTHROPIC_CACHE_BREAKPOINTS,
    ),
    prefixDocIds: assembled.orderedInvariant.map(
      (b, i) => b.doc_id?.trim() || `ctx-${i + 1}`,
    ),
  };
}

export function extractAnthropicUsageMetrics(
  usageRaw: unknown,
): AnthropicParsedUsage {
  const usage = asRecord(usageRaw);
  const creation = asRecord(usage.cache_creation);
  const ephemeral1h = asNonNegativeInt(creation[KEY_EPH_1H_CNT], 0);
  const ephemeral5m = asNonNegativeInt(creation[KEY_EPH_5M_CNT], 0);
  const rawCreate = asNonNegativeInt(usage[KEY_CREATION_INPUT_CNT], 0);
  const cacheWrite = rawCreate > 0 ? rawCreate : ephemeral1h + ephemeral5m;

  return {
    inputCount: asNonNegativeInt(usage[KEY_INPUT_CNT], 0),
    outputCount: asNonNegativeInt(usage[KEY_OUTPUT_CNT], 0),
    cacheWriteCount: cacheWrite,
    cacheReadCount: asNonNegativeInt(usage[KEY_READ_INPUT_CNT], 0),
    ephemeral1hCount: ephemeral1h,
    ephemeral5mCount: ephemeral5m,
  };
}

export function buildEstimateDisclaimer(params: {
  cacheTtl: PromptCacheTtl;
  latencyMs: number | null;
  baselineLatencyMs: number | null;
}): string {
  const writeRate = params.cacheTtl === "1h" ? "2.00x 1h write" : "1.25x 5m write";
  const parts = [
    `Measured TTL=${params.cacheTtl} (~0.10x cached read / ${writeRate})`,
  ];
  if (params.latencyMs !== null) {
    parts.push(`latency_ms=${Math.round(params.latencyMs)}`);
  }
  if (params.baselineLatencyMs !== null) {
    parts.push(`baseline_latency_ms=${Math.round(params.baselineLatencyMs)}`);
  }
  parts.push(
    "Provider up-to-90% cost / 85% latency claims are third-party baselines; verify live billing.",
  );
  return parts.join(" | ");
}

export function parseTelemetryFromDisclaimer(disclaimer: string): {
  cacheTtl: PromptCacheTtl;
  latencyMs: number | null;
  baselineLatencyMs: number | null;
} {
  const ttlMatch = disclaimer.match(/\bTTL=(1h|5m)\b/i);
  const latencyMatch = disclaimer.match(/\blatency_ms=(\d+(?:\.\d+)?)\b/i);
  const baselineMatch = disclaimer.match(
    /\bbaseline_latency_ms=(\d+(?:\.\d+)?)\b/i,
  );
  return {
    cacheTtl: ttlMatch && ttlMatch[1].toLowerCase() === "1h" ? "1h" : "5m",
    latencyMs: latencyMatch ? Number(latencyMatch[1]) : null,
    baselineLatencyMs: baselineMatch ? Number(baselineMatch[1]) : null,
  };
}

export function measureAnthropicCacheSavings(params: {
  requestId: string;
  userId: string;
  workflowKey: string;
  modelId: string;
  cacheTtl: PromptCacheTtl;
  cacheWriteCount: number;
  cacheReadCount: number;
  uncachedInputCount: number;
  outputCount: number;
  latencyMs?: number | null;
  baselineLatencyMs?: number | null;
}) {
  const card = resolveAnthropicRateCard(params.modelId);
  const writeMultiplier = params.cacheTtl === "1h"
    ? card.writeMultiplier1h
    : card.writeMultiplier5m;

  const totalInputEquiv = params.cacheWriteCount + params.cacheReadCount +
    params.uncachedInputCount;
  const uncachedBaselineUsd = Number(
    (
      (totalInputEquiv / 1_000_000) * card.inputPer1mUsd +
      (params.outputCount / 1_000_000) * card.outputPer1mUsd
    ).toFixed(6),
  );
  const actualEstimatedUsd = Number(
    (
      (params.cacheWriteCount / 1_000_000) *
        (card.inputPer1mUsd * writeMultiplier) +
      (params.cacheReadCount / 1_000_000) *
        (card.inputPer1mUsd * card.readMultiplier) +
      (params.uncachedInputCount / 1_000_000) * card.inputPer1mUsd +
      (params.outputCount / 1_000_000) * card.outputPer1mUsd
    ).toFixed(6),
  );
  const netSavingsUsd = Number(
    (uncachedBaselineUsd - actualEstimatedUsd).toFixed(6),
  );
  const savingsRatio = uncachedBaselineUsd > 0
    ? Number(
      Math.max(-1, Math.min(1, netSavingsUsd / uncachedBaselineUsd)).toFixed(4),
    )
    : 0;

  const latencyMs = params.latencyMs ?? null;
  const baselineLatencyMs = params.baselineLatencyMs ?? null;
  const latencySavedMs = latencyMs !== null && baselineLatencyMs !== null
    ? Number((baselineLatencyMs - latencyMs).toFixed(1))
    : null;
  const latencyReductionRatio = latencySavedMs !== null &&
      baselineLatencyMs !== null &&
      baselineLatencyMs > 0
    ? Number((latencySavedMs / baselineLatencyMs).toFixed(4))
    : null;

  const breakEvenReadHits = Math.ceil(
    (writeMultiplier - 1.0) / (1.0 - card.readMultiplier),
  );

  const disclaimer = buildEstimateDisclaimer({
    cacheTtl: params.cacheTtl,
    latencyMs,
    baselineLatencyMs,
  });

  const metricRow: Record<string, unknown> = {
    request_id: params.requestId,
    user_id: params.userId,
    workflow_key: params.workflowKey,
    provider: "anthropic",
    model_id: card.modelId,
    uncached_baseline_usd: uncachedBaselineUsd,
    actual_estimated_usd: actualEstimatedUsd,
    net_savings_usd: netSavingsUsd,
    savings_ratio: savingsRatio,
    cache_hit: params.cacheReadCount > 0,
    rate_card_version: params.cacheTtl === "1h"
      ? PROMPT_CACHE_1H_RATE_CARD_VERSION
      : PROMPT_CACHE_5M_RATE_CARD_VERSION,
    estimate_disclaimer: disclaimer,
    [KEY_CACHE_WRITE_CNT]: params.cacheWriteCount,
    [KEY_CACHE_READ_CNT]: params.cacheReadCount,
    [KEY_UNCACHED_INPUT_CNT]: params.uncachedInputCount,
    [KEY_OUTPUT_CNT]: params.outputCount,
  };

  return {
    metricRow,
    cacheTtl: params.cacheTtl,
    writeMultiplier,
    readMultiplier: card.readMultiplier,
    breakEvenReadHits,
    latencyMs,
    baselineLatencyMs,
    latencySavedMs,
    latencyReductionRatio,
  };
}

export interface LongTaskRecacheInput {
  model: string;
  sessionStartedAtIso: string;
  lastCacheRefreshedAtIso: string;
  nowIso?: string;
  ttlMinutes?: number;
  proactiveThresholdMinutes?: number;
  recacheSeq?: number;
  systemInstructions?: string;
  invariantLogs?: InvariantContextBlock[];
  conversationSummary?: string;
  completedSteps?: string[];
  pendingStep?: string;
  conversationTurns?: ChatTurnMessage[];
}

export async function planLongRunningRecache(input: LongTaskRecacheInput) {
  const ttlMinutes = input.ttlMinutes ?? DEFAULT_PROMPT_CACHE_TTL_MINUTES;
  const thresholdMinutes = input.proactiveThresholdMinutes ??
    PROACTIVE_RECACHE_THRESHOLD_MINUTES;
  const nowMs = Date.parse(input.nowIso ?? new Date().toISOString());
  const startMs = Date.parse(input.sessionStartedAtIso);
  const refreshMs = Date.parse(input.lastCacheRefreshedAtIso);
  if (!Number.isFinite(nowMs) || !Number.isFinite(refreshMs)) {
    throw new Error("Invalid timestamp for long-task cache renewal check");
  }

  const elapsedTotalMinutes = Number.isFinite(startMs)
    ? Number(Math.max(0, (nowMs - startMs) / 60_000).toFixed(2))
    : Number(Math.max(0, (nowMs - refreshMs) / 60_000).toFixed(2));
  const idleSinceRefreshMinutes = Number(
    Math.max(0, (nowMs - refreshMs) / 60_000).toFixed(2),
  );

  let status: "cache_active" | "prewarm_renewal" | "expired_recache_required" =
    "cache_active";
  if (idleSinceRefreshMinutes >= ttlMinutes) {
    status = "expired_recache_required";
  } else if (idleSinceRefreshMinutes >= thresholdMinutes) {
    status = "prewarm_renewal";
  }

  const nextSeq = (input.recacheSeq ?? 0) + (status === "cache_active" ? 0 : 1);
  const handoffPayload = {
    seq: nextSeq,
    elapsed_total_minutes: elapsedTotalMinutes,
    completed_steps: input.completedSteps ?? [],
    pending_step: (input.pendingStep ?? "").trim() || "continue_task",
    summary: (input.conversationSummary ?? "").trim(),
  };
  const handoffDigest = await sha256HexString(JSON.stringify(handoffPayload));

  const handoffBlock: InvariantContextBlock = {
    doc_id: `handoff-seq-${nextSeq}`,
    title: `Continuation Context Checkpoint (>${ttlMinutes}m guard)`,
    content: [
      `handoff_digest: ${handoffDigest}`,
      `elapsed_total_minutes: ${elapsedTotalMinutes}`,
      `completed_steps: ${JSON.stringify(handoffPayload.completed_steps)}`,
      `pending_step: ${handoffPayload.pending_step}`,
      `summary: ${handoffPayload.summary || "N/A"}`,
    ].join("\n"),
  };

  const requestPlan = await buildAnthropicCachedMessagesRequest({
    model: input.model,
    systemInstructions: input.systemInstructions,
    invariantBlocks: [
      ...(input.invariantLogs ?? []),
      handoffBlock,
    ],
    messages: input.conversationTurns ?? [
      {
        role: "user",
        content: `Resume from pending step: ${handoffPayload.pending_step}`,
      },
    ],
    cacheTtl: "1h",
  });

  return {
    status,
    recache_needed: status !== "cache_active",
    exceeded_one_hour_task: elapsedTotalMinutes > DEFAULT_PROMPT_CACHE_TTL_MINUTES,
    elapsed_total_minutes: elapsedTotalMinutes,
    idle_since_refresh_minutes: idleSinceRefreshMinutes,
    ttl_minutes: ttlMinutes,
    proactive_threshold_minutes: thresholdMinutes,
    recache_seq: nextSeq,
    handoff_digest: handoffDigest,
    prefix_digest: requestPlan.prefixDigest,
    anthropic_request: requestPlan.body,
    anthropic_headers: requestPlan.extraHeaders,
  };
}

async function resolveIsAdmin(
  db: PromptCacheDb,
  userId: string | null,
  isElevatedAutomation: boolean,
): Promise<boolean> {
  if (isElevatedAutomation) return true;
  if (!userId) return false;
  const { data, error } = await db
    .from("user_profiles")
    .select("is_admin, role")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return false;
  const profile = asRecord(data);
  return profile.is_admin === true || profile.role === "admin";
}

export async function handlePromptCacheAction(
  ctx: PromptCacheActionContext,
): Promise<PromptCacheHttpResponse> {
  const { db, action, userId, isElevatedAutomation, body, nowIso } = ctx;

  if (action === "prompt_cache.build_payload") {
    const model = asTrimmedString(body.model) || "claude-sonnet-4-6";
    const cacheTtl = normalizePromptCacheTtl(body.cache_ttl ?? "1h");
    const systemInstructions = asTrimmedString(body.system_instructions);
    const rawBlocks = Array.isArray(body.invariant_blocks)
      ? body.invariant_blocks
      : [];
    const invariantBlocks: InvariantContextBlock[] = rawBlocks
      .map((entry) => {
        const rec = asRecord(entry);
        return {
          doc_id: asTrimmedString(rec.doc_id) || undefined,
          title: asTrimmedString(rec.title) || undefined,
          content: typeof rec.content === "string" ? rec.content : "",
        };
      })
      .filter((b) => b.content.trim().length > 0);
    const rawMessages = Array.isArray(body.messages) ? body.messages : [];
    const messages: ChatTurnMessage[] = rawMessages
      .map((entry) => {
        const rec = asRecord(entry);
        return {
          role: asTrimmedString(rec.role) || "user",
          content: typeof rec.content === "string" ? rec.content : "",
        };
      })
      .filter((m) => m.content.trim().length > 0);

    const parsedLimit = asNonNegativeInt(body[KEY_MAX_OUT], 512) || 512;
    const plan = await buildAnthropicCachedMessagesRequest({
      model,
      outputLimit: parsedLimit,
      systemInstructions,
      invariantBlocks,
      messages,
      cacheTtl,
    });
    return {
      status: 200,
      body: {
        success: true,
        ...plan,
      },
    };
  }

  if (action === "prompt_cache.record_metric") {
    const effectiveUserId = asTrimmedString(userId) ||
      (isElevatedAutomation ? asTrimmedString(body.user_id) : "");
    if (!effectiveUserId) {
      return {
        status: 401,
        body: { error: "Authenticated user_id is required" },
      };
    }
    const requestId = asTrimmedString(body.request_id) ||
      `pc1h-${Date.now()}`;
    const workflowKey = asTrimmedString(body.workflow_key) ||
      "long-context-agent";
    const modelId = asTrimmedString(body.model_id) || "claude-sonnet-4-6";
    const cacheTtl = normalizePromptCacheTtl(body.cache_ttl ?? "1h");

    const usageObj = body.usage ? extractAnthropicUsageMetrics(body.usage) : null;
    const cacheWriteCount = usageObj?.cacheWriteCount ??
      asNonNegativeInt(body[KEY_CACHE_WRITE_CNT], 0);
    const cacheReadCount = usageObj?.cacheReadCount ??
      asNonNegativeInt(body[KEY_CACHE_READ_CNT], 0);
    const uncachedInputCount = usageObj?.inputCount ??
      asNonNegativeInt(body[KEY_UNCACHED_INPUT_CNT], 0);
    const outputCount = usageObj?.outputCount ??
      asNonNegativeInt(body[KEY_OUTPUT_CNT], 0);

    const measured = measureAnthropicCacheSavings({
      requestId,
      userId: effectiveUserId,
      workflowKey,
      modelId,
      cacheTtl,
      cacheWriteCount,
      cacheReadCount,
      uncachedInputCount,
      outputCount,
      latencyMs: asNonNegativeNumber(body.latency_ms),
      baselineLatencyMs: asNonNegativeNumber(body.baseline_latency_ms),
    });

    const { data, error } = await db
      .from("context_cache_usage_metrics")
      .insert(measured.metricRow)
      .select("*")
      .single();
    if (error || !data) {
      return {
        status: 500,
        body: {
          error: error?.message ?? "Failed to record prompt cache telemetry",
        },
      };
    }

    return {
      status: 200,
      body: {
        success: true,
        metric: data,
        cache_ttl: measured.cacheTtl,
        write_multiplier: measured.writeMultiplier,
        read_multiplier: measured.readMultiplier,
        break_even_read_hits: measured.breakEvenReadHits,
        latency_ms: measured.latencyMs,
        baseline_latency_ms: measured.baselineLatencyMs,
        latency_saved_ms: measured.latencySavedMs,
        latency_reduction_ratio: measured.latencyReductionRatio,
      },
    };
  }

  if (action === "prompt_cache.monitor_summary") {
    const isAdmin = await resolveIsAdmin(db, userId, isElevatedAutomation);
    const scopedUserId = asTrimmedString(userId);
    if (!isAdmin && !scopedUserId) {
      return {
        status: 401,
        body: { error: "Authenticated user_id or admin privilege is required" },
      };
    }
    let query = db
      .from("context_cache_usage_metrics")
      .select("*")
      .order("created_at", { ascending: false });
    if (!isAdmin) {
      query = query.eq("user_id", scopedUserId);
    }
    const wfFilter = asTrimmedString(body.workflow_key);
    if (wfFilter) {
      query = query.eq("workflow_key", wfFilter);
    }
    const { data, error } = await query.limit(100);
    if (error) {
      return {
        status: 500,
        body: { error: error.message ?? "Failed to fetch cache summary" },
      };
    }
    const rows = (Array.isArray(data) ? data : []).map((r) => asRecord(r));
    let totalBaselineUsd = 0;
    let totalActualUsd = 0;
    let totalSavingsUsd = 0;
    let cacheHitCount = 0;
    let ttl1hCount = 0;
    const hitLatencies: number[] = [];
    const coldLatencies: number[] = [];
    const reductionRatios: number[] = [];

    for (const row of rows) {
      totalBaselineUsd += asNonNegativeNumber(row.uncached_baseline_usd) ?? 0;
      totalActualUsd += asNonNegativeNumber(row.actual_estimated_usd) ?? 0;
      const net = typeof row.net_savings_usd === "number"
        ? row.net_savings_usd
        : Number(row.net_savings_usd ?? 0);
      totalSavingsUsd += Number.isFinite(net) ? net : 0;
      const isHit = row.cache_hit === true;
      if (isHit) cacheHitCount++;
      const parsed = parseTelemetryFromDisclaimer(
        asTrimmedString(row.estimate_disclaimer),
      );
      if (
        parsed.cacheTtl === "1h" ||
        asTrimmedString(row.rate_card_version) === PROMPT_CACHE_1H_RATE_CARD_VERSION
      ) {
        ttl1hCount++;
      }
      if (parsed.latencyMs !== null) {
        if (isHit) hitLatencies.push(parsed.latencyMs);
        else coldLatencies.push(parsed.latencyMs);
        if (parsed.baselineLatencyMs !== null && parsed.baselineLatencyMs > 0) {
          reductionRatios.push(
            (parsed.baselineLatencyMs - parsed.latencyMs) /
              parsed.baselineLatencyMs,
          );
        }
      }
    }

    const avg = (vals: number[]) =>
      vals.length > 0
        ? Number((vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(2))
        : null;

    return {
      status: 200,
      body: {
        success: true,
        is_admin: isAdmin,
        request_count: rows.length,
        cache_hit_count: cacheHitCount,
        ttl_1h_count: ttl1hCount,
        total_uncached_baseline_usd: Number(totalBaselineUsd.toFixed(6)),
        total_actual_estimated_usd: Number(totalActualUsd.toFixed(6)),
        total_net_savings_usd: Number(totalSavingsUsd.toFixed(6)),
        weighted_savings_ratio: totalBaselineUsd > 0
          ? Number((totalSavingsUsd / totalBaselineUsd).toFixed(4))
          : 0,
        avg_hit_latency_ms: avg(hitLatencies),
        avg_cold_latency_ms: avg(coldLatencies),
        avg_latency_reduction_ratio: avg(reductionRatios),
        metrics: rows,
      },
    };
  }

  if (action === "prompt_cache.check_renewal") {
    const sessionStartedAtIso = asTrimmedString(body.session_started_at) ||
      asTrimmedString(body.last_cache_refreshed_at);
    const lastCacheRefreshedAtIso =
      asTrimmedString(body.last_cache_refreshed_at) || sessionStartedAtIso;
    if (!lastCacheRefreshedAtIso) {
      return {
        status: 400,
        body: { error: "last_cache_refreshed_at is required" },
      };
    }

    const rawLogs = Array.isArray(body.invariant_logs)
      ? body.invariant_logs
      : [];
    const invariantLogs: InvariantContextBlock[] = rawLogs
      .map((entry) => {
        const rec = asRecord(entry);
        return {
          doc_id: asTrimmedString(rec.doc_id) || undefined,
          title: asTrimmedString(rec.title) || undefined,
          content: typeof rec.content === "string" ? rec.content : "",
        };
      })
      .filter((b) => b.content.trim().length > 0);
    const completedSteps = Array.isArray(body.completed_steps)
      ? body.completed_steps.map((s) => String(s)).filter(Boolean)
      : [];

    const plan = await planLongRunningRecache({
      model: asTrimmedString(body.model) || "claude-sonnet-4-6",
      sessionStartedAtIso,
      lastCacheRefreshedAtIso,
      nowIso: asTrimmedString(body.now_iso) || nowIso,
      ttlMinutes: asNonNegativeInt(
        body.ttl_minutes,
        DEFAULT_PROMPT_CACHE_TTL_MINUTES,
      ) || DEFAULT_PROMPT_CACHE_TTL_MINUTES,
      proactiveThresholdMinutes: asNonNegativeInt(
        body.proactive_threshold_minutes,
        PROACTIVE_RECACHE_THRESHOLD_MINUTES,
      ) || PROACTIVE_RECACHE_THRESHOLD_MINUTES,
      recacheSeq: asNonNegativeInt(body.recache_seq, 0),
      systemInstructions: asTrimmedString(body.system_instructions),
      invariantLogs,
      conversationSummary: asTrimmedString(body.conversation_summary),
      completedSteps,
      pendingStep: asTrimmedString(body.pending_step),
    });

    return {
      status: 200,
      body: {
        success: true,
        ...plan,
      },
    };
  }

  return {
    status: 400,
    body: { error: `Unsupported prompt cache action: ${action}` },
  };
}

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Effort = "low" | "medium" | "high" | "xhigh";

export interface EffortConfig {
  action: string;
  default_effort: Effort;
  rationale: string;
  model_override?: string;
}

export interface EffortSelection {
  effort: Effort;
  model: string;
  rationale: string;
  source: "db" | "local";
}

export type ClaudeModelFamily = "haiku" | "sonnet";

export interface ClaudeModelRoute {
  family: ClaudeModelFamily;
  model: string;
  rationale: string;
}

export interface ClaudeModelOverrides {
  haikuModel?: string | null;
  sonnetModel?: string | null;
}

export const DEFAULT_CLAUDE_HAIKU_MODEL = "claude-haiku-4-5-20251001";
export const DEFAULT_CLAUDE_SONNET_MODEL = "claude-sonnet-5";

type EffortRow = {
  action: string;
  default_effort: Effort;
  rationale: string;
  model_override: string | null;
};

const LOCAL_EFFORT_MATRIX: EffortConfig[] = [
  {
    action: "ai.assistant.chat",
    default_effort: "low",
    rationale: "Daily assistant chat favors latency and low cost.",
  },
  {
    action: "ai.university.quiz_grade",
    default_effort: "low",
    rationale: "Deterministic quiz grading only needs a lightweight model.",
  },
  {
    action: "ai.competitor.monitor",
    default_effort: "medium",
    rationale: "Monitoring requires short summarization and classification.",
  },
  {
    action: "ai.video.caption",
    default_effort: "medium",
    rationale: "Caption generation is structured text with moderate context.",
  },
  {
    action: "ai.daily.judgment",
    default_effort: "high",
    rationale: "Daily judgment combines multiple personal signals.",
  },
  {
    action: "ai.cross_instance.routing",
    default_effort: "high",
    rationale: "Cross-instance routing requires trade-off analysis.",
  },
  {
    action: "ai.horse_racing.predict",
    default_effort: "xhigh",
    rationale: "Horse racing prediction uses many interacting factors.",
  },
  {
    action: "ai.notebooklm.distill",
    default_effort: "xhigh",
    rationale: "Axis distillation needs deep synthesis across prior decisions.",
  },
  {
    action: "provider.chat_auto",
    default_effort: "medium",
    rationale: "Automatic provider routing is general purpose chat.",
  },
  {
    action: "edge_llm.invoke",
    default_effort: "medium",
    rationale: "Generic EF LLM invoke balances latency and quality by default.",
  },
  {
    action: "memory.search",
    default_effort: "low",
    rationale: "BM25 and vector retrieval should stay fast.",
  },
  {
    action: "memory.rank",
    default_effort: "low",
    rationale: "Reranking is capped to a small candidate set.",
  },
  {
    action: "memory.lint",
    default_effort: "medium",
    rationale: "Memory linting may need semantic judgment.",
  },
];

let cachedClient: SupabaseClient | null = null;

function adminClient(): SupabaseClient {
  if (cachedClient) return cachedClient;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !serviceRoleKey) {
    throw new Error("SUPABASE_URL and SERVICE_ROLE_KEY are required");
  }

  cachedClient = createClient(url, serviceRoleKey);
  return cachedClient;
}

function modelForEffort(effort: Effort): string {
  const envName = `EFFORT_MODEL_${effort.toUpperCase()}`;
  const override = Deno.env.get(envName) ?? "";
  if (override.trim()) return override.trim();

  switch (effort) {
    case "low":
      return "claude-haiku-4-5";
    case "medium":
      return "gpt-5.4-mini";
    case "high":
      return "claude-sonnet-4-6";
    case "xhigh":
      return "gpt-5.5";
  }
}

/**
 * Maps the shared difficulty decision to the two-model Claude cost lane.
 * Low and medium work stays Haiku-first; only high/xhigh work escalates to
 * Sonnet. Deployment-specific model IDs may be supplied without changing the
 * routing policy or accepting caller-controlled model names.
 */
export function selectClaudeModelForEffort(
  effort: Effort,
  overrides: ClaudeModelOverrides = {},
): ClaudeModelRoute {
  const useSonnet = effort === "high" || effort === "xhigh";
  const configuredModel = useSonnet
    ? overrides.sonnetModel
    : overrides.haikuModel;
  const model = configuredModel?.trim() ||
    (useSonnet ? DEFAULT_CLAUDE_SONNET_MODEL : DEFAULT_CLAUDE_HAIKU_MODEL);
  return {
    family: useSonnet ? "sonnet" : "haiku",
    model,
    rationale: useSonnet
      ? `${effort} effort requires the higher-capability Claude lane.`
      : `${effort} effort remains on the Haiku-first cost lane.`,
  };
}

function localConfigFor(action: string): EffortConfig {
  const exact = LOCAL_EFFORT_MATRIX.find((entry) => entry.action === action);
  if (exact) return exact;

  const prefix = LOCAL_EFFORT_MATRIX
    .filter((entry) => action.startsWith(entry.action.replace(/\.\*$/, "")))
    .sort((a, b) => b.action.length - a.action.length)[0];
  if (prefix) return prefix;

  return {
    action,
    default_effort: "medium",
    rationale: "Fallback for uncategorized actions.",
  };
}

function applyMetaOverride(
  effort: Effort,
  request_meta: Record<string, unknown>,
): Effort {
  const explicit = request_meta.effort;
  if (
    explicit === "low" || explicit === "medium" || explicit === "high" ||
    explicit === "xhigh"
  ) {
    return explicit;
  }

  if (request_meta.requires_architecture_decision === true) return "high";
  if (request_meta.requires_deep_reasoning === true) return "xhigh";
  if (request_meta.latency_sensitive === true && effort === "medium") {
    return "low";
  }
  return effort;
}

export async function selectEffort(
  action: string,
  request_meta: Record<string, unknown> = {},
): Promise<EffortSelection> {
  const normalizedAction = action.trim() || "unknown";
  try {
    const { data, error } = await adminClient()
      .from("effort_config")
      .select("action, default_effort, rationale, model_override")
      .eq("action", normalizedAction)
      .maybeSingle();

    if (error) throw error;
    if (data) {
      const row = data as EffortRow;
      const effort = applyMetaOverride(row.default_effort, request_meta);
      return {
        effort,
        model: row.model_override || modelForEffort(effort),
        rationale: row.rationale,
        source: "db",
      };
    }
  } catch {
    // Use the local matrix when the DB is unavailable or migrations are pending.
  }

  const local = localConfigFor(normalizedAction);
  const effort = applyMetaOverride(local.default_effort, request_meta);
  return {
    effort,
    model: local.model_override ?? modelForEffort(effort),
    rationale: local.rationale,
    source: "local",
  };
}

export function annotateRequest(
  action: string,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const local = localConfigFor(action);
  const effort = applyMetaOverride(local.default_effort, payload);
  return {
    ...payload,
    effort,
    model: typeof payload.model === "string" && payload.model.trim()
      ? payload.model
      : local.model_override ?? modelForEffort(effort),
    effort_rationale: local.rationale,
  };
}

export type ComplexityTier = "trivial" | "standard" | "complex" | "critical";

export interface DynamicModelCandidate {
  provider: string;
  model: string;
}

export interface DynamicRouteInput {
  action: string;
  complexity?: ComplexityTier;
  requestMeta?: Record<string, unknown>;
  remainingBudgetUsd?: number;
  unhealthyModels?: readonly string[];
  lowBudgetThresholdUsd?: number;
}

export interface DynamicRouteDecision {
  tier: ComplexityTier;
  effort: Effort;
  provider: string;
  model: string;
  fallbacks: DynamicModelCandidate[];
  downgradedByBudget: boolean;
  budgetExhausted: boolean;
  rationale: string;
  source: "local";
}

const EFFORT_TO_TIER: Record<Effort, ComplexityTier> = {
  low: "trivial",
  medium: "standard",
  high: "complex",
  xhigh: "critical",
};

const TIER_TO_EFFORT: Record<ComplexityTier, Effort> = {
  trivial: "low",
  standard: "medium",
  complex: "high",
  critical: "xhigh",
};

const TIER_CANDIDATES: Record<ComplexityTier, readonly DynamicModelCandidate[]> = {
  trivial: [
    { provider: "anthropic", model: "claude-haiku-4-5" },
    { provider: "groq", model: "llama-3.3-70b-versatile" },
    { provider: "google", model: "gemini-2.5-flash" },
  ],
  standard: [
    { provider: "openai", model: "gpt-5.4-mini" },
    { provider: "anthropic", model: "claude-haiku-4-5" },
    { provider: "google", model: "gemini-2.5-flash" },
  ],
  complex: [
    { provider: "anthropic", model: "claude-sonnet-4-6" },
    { provider: "openai", model: "gpt-5.4" },
    { provider: "google", model: "gemini-3.1-pro-preview" },
  ],
  critical: [
    { provider: "anthropic", model: "claude-opus-4-7" },
    { provider: "openai", model: "gpt-5.5" },
    { provider: "anthropic", model: "claude-sonnet-4-6" },
  ],
};

export function mapEffortToComplexity(effort: Effort): ComplexityTier {
  return EFFORT_TO_TIER[effort];
}

export function mapComplexityToEffort(tier: ComplexityTier): Effort {
  return TIER_TO_EFFORT[tier];
}

function downgradeTierForBudget(tier: ComplexityTier): ComplexityTier {
  switch (tier) {
    case "critical":
      return "complex";
    case "complex":
      return "standard";
    case "standard":
    case "trivial":
      return "trivial";
  }
}

/**
 * Selects a dynamic model route from action, complexity tier, budget reserve,
 * and circuit-breaker unhealthy model list without external network calls.
 */
export function selectDynamicLlmRoute(
  input: DynamicRouteInput,
): DynamicRouteDecision {
  const local = localConfigFor(input.action.trim() || "unknown");
  const meta = input.requestMeta ?? {};
  const baseEffort = input.complexity
    ? mapComplexityToEffort(input.complexity)
    : applyMetaOverride(local.default_effort, meta);
  let tier = mapEffortToComplexity(baseEffort);
  let downgradedByBudget = false;
  let budgetExhausted = false;

  const remaining = input.remainingBudgetUsd;
  const threshold = input.lowBudgetThresholdUsd ?? 5.0;
  if (typeof remaining === "number" && Number.isFinite(remaining)) {
    if (remaining <= 0) {
      tier = "trivial";
      downgradedByBudget = true;
      budgetExhausted = true;
    } else if (remaining < threshold && tier !== "trivial") {
      tier = downgradeTierForBudget(tier);
      downgradedByBudget = true;
    }
  }

  const unhealthy = new Set(
    (input.unhealthyModels ?? []).map((item) => item.trim().toLowerCase()),
  );
  const pool = [...TIER_CANDIDATES[tier]];
  const healthy = pool.filter(
    (candidate) => !unhealthy.has(candidate.model.toLowerCase()),
  );
  const ordered = healthy.length > 0 ? healthy : pool;
  const primary = ordered[0];
  const effort = mapComplexityToEffort(tier);

  const suffix = budgetExhausted
    ? " Budget exhausted; fail-closed minimum tier selected."
    : downgradedByBudget
    ? " Downgraded one tier due to low remaining budget."
    : "";

  return {
    tier,
    effort,
    provider: primary.provider,
    model: local.model_override ?? primary.model,
    fallbacks: ordered.slice(1),
    downgradedByBudget,
    budgetExhausted,
    rationale: `${local.rationale}${suffix}`.trim(),
    source: "local",
  };
}

export interface AgentLoopTelemetryEvent {
  model: string;
  taskType?: string;
  status?: string;
  inputTokens?: number;
  outputTokens?: number;
  thinkingTokens?: number;
  estimatedCostUsd?: number;
  occurredAt?: string;
}

export interface AgentLoopGuardPolicy {
  maxConsecutiveRetries?: number;
  maxCallsPerMinute?: number;
  maxSessionTokens?: number;
  costAlertUsd?: number;
  autoHaltOnLoop?: boolean;
}

export interface ModelTokenCostBreakdown {
  model: string;
  callCount: number;
  inputTokens: number;
  outputTokens: number;
  thinkingTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  costSharePct: number;
}

export interface AgentLoopHaltDecision {
  shouldHalt: boolean;
  triggers: string[];
  maxConsecutiveFailures: number;
  maxConsecutiveSameTask: number;
  peakCallsPerMinute: number;
  totalTokens: number;
  totalCostUsd: number;
  haltReason: string;
}

const FAILURE_EVENT_STATUSES = new Set([
  "error",
  "failed",
  "timeout",
  "rate_limited",
  "blocked",
]);

export function summarizePerModelTokenCosts(
  events: readonly AgentLoopTelemetryEvent[],
): ModelTokenCostBreakdown[] {
  const byModel = new Map<string, ModelTokenCostBreakdown>();
  let grandTotalCost = 0;

  for (const event of events) {
    const model = event.model.trim() || "unknown";
    const inTok = Math.max(0, Math.trunc(event.inputTokens ?? 0));
    const outTok = Math.max(0, Math.trunc(event.outputTokens ?? 0));
    const thinkTok = Math.max(0, Math.trunc(event.thinkingTokens ?? 0));
    const cost = Math.max(0, Number(event.estimatedCostUsd ?? 0));
    const existing = byModel.get(model) ?? {
      model,
      callCount: 0,
      inputTokens: 0,
      outputTokens: 0,
      thinkingTokens: 0,
      totalTokens: 0,
      estimatedCostUsd: 0,
      costSharePct: 0,
    };
    existing.callCount += 1;
    existing.inputTokens += inTok;
    existing.outputTokens += outTok;
    const prevThink = existing.thinkingTokens;
    const nxtThk = prevThink + thinkTok;
    existing.thinkingTokens = nxtThk;
    const nextSum = existing.totalTokens + inTok + outTok + thinkTok;
    existing.totalTokens = nextSum;
    existing.estimatedCostUsd =
      Math.round((existing.estimatedCostUsd + cost) * 1_000_000) / 1_000_000;
    byModel.set(model, existing);
    grandTotalCost += cost;
  }

  return Array.from(byModel.values())
    .map((row) => ({
      ...row,
      costSharePct: grandTotalCost > 0
        ? Math.round((row.estimatedCostUsd / grandTotalCost) * 10000) / 100
        : 0,
    }))
    .sort((a, b) =>
      b.estimatedCostUsd !== a.estimatedCostUsd
        ? b.estimatedCostUsd - a.estimatedCostUsd
        : b.totalTokens - a.totalTokens
    );
}

export function detectAgentLoopHalt(
  events: readonly AgentLoopTelemetryEvent[],
  policy: AgentLoopGuardPolicy = {},
  remainingBudgetUsd?: number,
): AgentLoopHaltDecision {
  const maxRetries = Math.max(1, Math.trunc(policy.maxConsecutiveRetries ?? 5));
  const maxCpm = Math.max(1, Math.trunc(policy.maxCallsPerMinute ?? 12));
  const tokCap = Math.max(100, Math.trunc(policy.maxSessionTokens ?? 120000));
  const costAlertUsd = Math.max(0.000001, Number(policy.costAlertUsd ?? 10.0));
  const autoHaltEnabled = policy.autoHaltOnLoop !== false;

  let consecutiveFailures = 0;
  let maxConsecutiveFailures = 0;
  let consecutiveSameTask = 0;
  let maxConsecutiveSameTask = 0;
  let prevSig = "";
  let tokSum = 0;
  let totalCostUsd = 0;
  const minuteCounts = new Map<string, number>();

  for (const event of events) {
    const inTok = Math.max(0, Math.trunc(event.inputTokens ?? 0));
    const outTok = Math.max(0, Math.trunc(event.outputTokens ?? 0));
    const thinkTok = Math.max(0, Math.trunc(event.thinkingTokens ?? 0));
    tokSum += inTok + outTok + thinkTok;
    totalCostUsd += Math.max(0, Number(event.estimatedCostUsd ?? 0));

    const status = (event.status ?? "").trim().toLowerCase();
    if (FAILURE_EVENT_STATUSES.has(status)) {
      consecutiveFailures += 1;
      if (consecutiveFailures > maxConsecutiveFailures) {
        maxConsecutiveFailures = consecutiveFailures;
      }
    } else {
      consecutiveFailures = 0;
    }

    const sig = `${event.model.trim()}::${(event.taskType ?? "").trim()}`;
    if (sig === prevSig) {
      consecutiveSameTask += 1;
    } else {
      consecutiveSameTask = 1;
      prevSig = sig;
    }
    if (consecutiveSameTask > maxConsecutiveSameTask) {
      maxConsecutiveSameTask = consecutiveSameTask;
    }

    const ts = (event.occurredAt ?? "").trim();
    if (ts.length >= 16) {
      const minuteKey = ts.slice(0, 16);
      minuteCounts.set(minuteKey, (minuteCounts.get(minuteKey) ?? 0) + 1);
    }
  }

  let peakCallsPerMinute = 0;
  for (const count of minuteCounts.values()) {
    if (count > peakCallsPerMinute) peakCallsPerMinute = count;
  }

  const triggers: string[] = [];
  if (maxConsecutiveFailures >= maxRetries || maxConsecutiveSameTask >= maxRetries) {
    triggers.push("consecutive_retry_loop");
  }
  if (tokSum >= tokCap) {
    triggers.push("token_burn_spike");
  }
  if (peakCallsPerMinute >= maxCpm) {
    triggers.push("call_rate_spike");
  }
  if (
    (typeof remainingBudgetUsd === "number" &&
      Number.isFinite(remainingBudgetUsd) &&
      remainingBudgetUsd <= 0) ||
    totalCostUsd >= costAlertUsd
  ) {
    triggers.push("budget_cap_exceeded");
  }

  const shouldHalt = autoHaltEnabled && triggers.length > 0;
  const haltResult: AgentLoopHaltDecision = {
    shouldHalt,
    triggers,
    maxConsecutiveFailures,
    maxConsecutiveSameTask,
    peakCallsPerMinute,
    totalTokens: 0,
    totalCostUsd: Math.round(totalCostUsd * 1_000_000) / 1_000_000,
    haltReason: shouldHalt ? triggers.join(", ") : "",
  };
  haltResult.totalTokens = tokSum;
  return haltResult;
}

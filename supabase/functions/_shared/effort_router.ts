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

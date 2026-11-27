export const API_USAGE_LOG_SOURCE = "api_usage_log";
export const AI_COST_BUDGET_ALERT_SOURCE = "ai_cost_budget_alert";

export const PRICING_REFERENCE_DISCLAIMER =
  "参考単価(USD/1M単位)に基づく概算見積りです。" +
  "キャッシュ割引・段階課金(>200k)・公式改定により実請求と異なる場合があります。";

export type SupportedCostProvider =
  | "gemini"
  | "openai"
  | "anthropic"
  | "deepseek"
  | "unknown";

export interface ModelPricingRate {
  provider: SupportedCostProvider;
  inputUsdPer1m: number;
  outputUsdPer1m: number;
  pricingNote: string;
}

export const MODEL_PRICING_RATES: Record<string, ModelPricingRate> = {
  "gemini-4-hydrogen": {
    provider: "gemini",
    inputUsdPer1m: 1.50,
    outputUsdPer1m: 7.50,
    pricingNote: "Google Gemini 4 Hydrogen paid tier reference",
  },
  "gemini-4-neon": {
    provider: "gemini",
    inputUsdPer1m: 3.00,
    outputUsdPer1m: 15.00,
    pricingNote: "Google Gemini 4 Neon paid tier reference",
  },
  "gemini-2.5-flash": {
    provider: "gemini",
    inputUsdPer1m: 0.30,
    outputUsdPer1m: 2.50,
    pricingNote: "Google Gemini 2.5 Flash paid tier reference",
  },
  "gemini-2.5-pro": {
    provider: "gemini",
    inputUsdPer1m: 1.25,
    outputUsdPer1m: 10.00,
    pricingNote: "Google Gemini 2.5 Pro <=200k reference",
  },
  "gpt-4o-mini": {
    provider: "openai",
    inputUsdPer1m: 0.15,
    outputUsdPer1m: 0.60,
    pricingNote: "OpenAI GPT-4o mini Standard API reference",
  },
  "gpt-4o": {
    provider: "openai",
    inputUsdPer1m: 2.50,
    outputUsdPer1m: 10.00,
    pricingNote: "OpenAI GPT-4o Standard API reference",
  },
  "claude-haiku-4-5-20251001": {
    provider: "anthropic",
    inputUsdPer1m: 1.00,
    outputUsdPer1m: 5.00,
    pricingNote: "Anthropic Claude Haiku 4.5 API reference",
  },
  "claude-haiku-4-5": {
    provider: "anthropic",
    inputUsdPer1m: 1.00,
    outputUsdPer1m: 5.00,
    pricingNote: "Anthropic Claude Haiku 4.5 API reference",
  },
  "claude-sonnet-4-5": {
    provider: "anthropic",
    inputUsdPer1m: 3.00,
    outputUsdPer1m: 15.00,
    pricingNote: "Anthropic Claude Sonnet 4.5 API reference",
  },
  "deepseek-v4-flash": {
    provider: "deepseek",
    inputUsdPer1m: 0.14,
    outputUsdPer1m: 0.28,
    pricingNote: "DeepSeek V4 Flash standard reference",
  },
};

export interface ExtractedTokenUsage {
  provider: SupportedCostProvider;
  inputUnits: number;
  outputUnits: number;
  totalUnits: number;
  usagePresent: boolean;
}

export interface ModelCostEstimate {
  model: string;
  provider: SupportedCostProvider;
  known_pricing: boolean;
  estimated_cost_usd: number | null;
  input_usd_per_1m: number | null;
  output_usd_per_1m: number | null;
  pricing_note: string;
  pricing_disclaimer: string;
}

export interface UsageLogInsertClient {
  from(table: string): {
    insert(values: Record<string, unknown>): {
      select(columns: string): {
        single(): PromiseLike<{
          data: unknown;
          error?: { message?: string } | null;
        }>;
      };
    };
  };
}

export interface RecordUsageLogResult {
  recorded: boolean;
  id: string | null;
  estimate: ModelCostEstimate;
  reason?: string;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function readNonNegInt(
  record: Record<string, unknown> | null,
  keys: readonly string[],
): number | null {
  if (!record) return null;
  for (const key of keys) {
    const raw = record[key];
    if (typeof raw === "number" && Number.isFinite(raw) && raw >= 0) {
      return Math.trunc(raw);
    }
    if (typeof raw === "string" && raw.trim() !== "") {
      const parsed = Number(raw);
      if (Number.isFinite(parsed) && parsed >= 0) {
        return Math.trunc(parsed);
      }
    }
  }
  return null;
}

export function normalizeCostProvider(
  rawProvider: string,
): SupportedCostProvider {
  const normalized = rawProvider.trim().toLowerCase();
  if (normalized === "google" || normalized === "gemini") return "gemini";
  if (normalized === "openai") return "openai";
  if (normalized === "anthropic") return "anthropic";
  if (normalized === "deepseek") return "deepseek";
  return "unknown";
}

export function inferCostProviderFromModel(
  model: string,
): SupportedCostProvider {
  const key = model.trim().toLowerCase();
  const rate = MODEL_PRICING_RATES[key];
  if (rate) return rate.provider;
  if (key.startsWith("gemini") || key.startsWith("gemma")) return "gemini";
  if (key.startsWith("gpt") || key.startsWith("o1") || key.startsWith("o3")) {
    return "openai";
  }
  if (key.startsWith("claude")) return "anthropic";
  if (key.startsWith("deepseek")) return "deepseek";
  return "unknown";
}

export function extractTokenUsage(
  rawProvider: string,
  payload: unknown,
): ExtractedTokenUsage {
  const provider = normalizeCostProvider(rawProvider);
  const root = asRecord(payload);
  if (!root) {
    return {
      provider,
      inputUnits: 0,
      outputUnits: 0,
      totalUnits: 0,
      usagePresent: false,
    };
  }

  if (provider === "gemini") {
    const meta = asRecord(root.usageMetadata);
    const inCnt = readNonNegInt(meta, [
      "promptTokenCount",
      "prompt_token_count",
    ]);
    const candCnt = readNonNegInt(meta, [
      "candidatesTokenCount",
      "candidates_token_count",
    ]);
    const thinkCnt = readNonNegInt(meta, [
      "thoughtsTokenCount",
      "thoughts_token_count",
    ]);
    const totalCnt = readNonNegInt(meta, [
      "totalTokenCount",
      "total_token_count",
    ]);

    if (
      inCnt === null &&
      candCnt === null &&
      thinkCnt === null &&
      totalCnt === null
    ) {
      return {
        provider,
        inputUnits: 0,
        outputUnits: 0,
        totalUnits: 0,
        usagePresent: false,
      };
    }

    const inputUnits = inCnt ?? 0;
    let outputUnits = (candCnt ?? 0) + (thinkCnt ?? 0);
    if (
      candCnt === null &&
      thinkCnt === null &&
      totalCnt !== null &&
      inCnt !== null
    ) {
      outputUnits = Math.max(0, totalCnt - inCnt);
    }
    const totalUnits = totalCnt ?? inputUnits + outputUnits;
    return {
      provider,
      inputUnits,
      outputUnits,
      totalUnits,
      usagePresent: true,
    };
  }

  const usage = asRecord(root.usage);
  if (provider === "anthropic") {
    const baseIn = readNonNegInt(usage, ["input_tokens"]);
    const cacheWrite = readNonNegInt(usage, ["cache_creation_input_tokens"]);
    const cacheRead = readNonNegInt(usage, ["cache_read_input_tokens"]);
    const outCnt = readNonNegInt(usage, ["output_tokens"]);
    const totalCnt = readNonNegInt(usage, ["total_tokens"]);

    if (
      baseIn === null &&
      cacheWrite === null &&
      cacheRead === null &&
      outCnt === null
    ) {
      return {
        provider,
        inputUnits: 0,
        outputUnits: 0,
        totalUnits: 0,
        usagePresent: false,
      };
    }

    const inputUnits = (baseIn ?? 0) + (cacheWrite ?? 0) + (cacheRead ?? 0);
    const outputUnits = outCnt ?? 0;
    const totalUnits = totalCnt ?? inputUnits + outputUnits;
    return {
      provider,
      inputUnits,
      outputUnits,
      totalUnits,
      usagePresent: true,
    };
  }

  const inCnt = readNonNegInt(usage, ["prompt_tokens", "input_tokens"]);
  const outCnt = readNonNegInt(usage, ["completion_tokens", "output_tokens"]);
  const totalCnt = readNonNegInt(usage, ["total_tokens"]);
  if (inCnt === null && outCnt === null && totalCnt === null) {
    return {
      provider,
      inputUnits: 0,
      outputUnits: 0,
      totalUnits: 0,
      usagePresent: false,
    };
  }
  const inputUnits = inCnt ?? 0;
  const outputUnits = outCnt ?? 0;
  const totalUnits = totalCnt ?? inputUnits + outputUnits;
  return {
    provider,
    inputUnits,
    outputUnits,
    totalUnits,
    usagePresent: true,
  };
}

export function estimateModelCostUsd(params: {
  model: string;
  provider?: string;
  inputUnits: number;
  outputUnits: number;
}): ModelCostEstimate {
  const modelKey = params.model.trim().toLowerCase();
  const rate = MODEL_PRICING_RATES[modelKey] ?? null;
  const normalizedInputProvider = params.provider
    ? normalizeCostProvider(params.provider)
    : "unknown";
  const resolvedProvider = rate?.provider ??
    (normalizedInputProvider !== "unknown"
      ? normalizedInputProvider
      : inferCostProviderFromModel(modelKey));

  if (!rate) {
    return {
      model: modelKey || "unknown",
      provider: resolvedProvider,
      known_pricing: false,
      estimated_cost_usd: null,
      input_usd_per_1m: null,
      output_usd_per_1m: null,
      pricing_note: "価格未登録モデル (0 USD へ暗黙変換しません)",
      pricing_disclaimer: PRICING_REFERENCE_DISCLAIMER,
    };
  }

  const inUnits = Number.isFinite(params.inputUnits) && params.inputUnits > 0
    ? Math.trunc(params.inputUnits)
    : 0;
  const outUnits = Number.isFinite(params.outputUnits) && params.outputUnits > 0
    ? Math.trunc(params.outputUnits)
    : 0;
  const rawCost = (inUnits / 1_000_000) * rate.inputUsdPer1m +
    (outUnits / 1_000_000) * rate.outputUsdPer1m;
  const roundedCost = Math.round(rawCost * 1_000_000) / 1_000_000;

  return {
    model: modelKey,
    provider: resolvedProvider,
    known_pricing: true,
    estimated_cost_usd: roundedCost,
    input_usd_per_1m: rate.inputUsdPer1m,
    output_usd_per_1m: rate.outputUsdPer1m,
    pricing_note: rate.pricingNote,
    pricing_disclaimer: PRICING_REFERENCE_DISCLAIMER,
  };
}

export async function recordApiUsageLog(params: {
  client: UsageLogInsertClient | null | undefined;
  userId: string;
  provider: string;
  model: string;
  actionName: string;
  usage: ExtractedTokenUsage;
  recordedAt?: string;
}): Promise<RecordUsageLogResult> {
  const estimate = estimateModelCostUsd({
    model: params.model,
    provider: params.provider,
    inputUnits: params.usage.inputUnits,
    outputUnits: params.usage.outputUnits,
  });

  const userId = params.userId.trim();
  if (!params.client || !userId) {
    return {
      recorded: false,
      id: null,
      estimate,
      reason: "missing_client_or_user",
    };
  }

  const nowIso = params.recordedAt ?? new Date().toISOString();
  try {
    const { data, error } = await params.client
      .from("hub_data")
      .insert({
        source: API_USAGE_LOG_SOURCE,
        metadata: {
          user_id: userId,
          provider: estimate.provider,
          model: estimate.model,
          action_name: params.actionName.trim() || "unknown",
          input_units: params.usage.inputUnits,
          output_units: params.usage.outputUnits,
          total_units: params.usage.totalUnits,
          usage_present: params.usage.usagePresent,
          known_pricing: estimate.known_pricing,
          estimated_cost_usd: estimate.estimated_cost_usd,
          pricing_note: estimate.pricing_note,
          pricing_disclaimer: estimate.pricing_disclaimer,
          recorded_at: nowIso,
        },
      })
      .select("id")
      .single();

    if (error || !data || typeof data !== "object") {
      return {
        recorded: false,
        id: null,
        estimate,
        reason: error?.message ?? "insert_failed",
      };
    }

    const row = data as Record<string, unknown>;
    return {
      recorded: true,
      id: typeof row.id === "string" ? row.id : String(row.id ?? ""),
      estimate,
    };
  } catch (err) {
    return {
      recorded: false,
      id: null,
      estimate,
      reason: err instanceof Error ? err.message : String(err),
    };
  }
}

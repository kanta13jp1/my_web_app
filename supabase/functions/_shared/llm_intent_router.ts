export const GROQ_CHAT_COMPLETIONS_URL =
  "https://api.groq.com/openai/v1/chat/completions";
export const DEFAULT_GROQ_ROUTER_MODEL = "llama-3.3-70b-versatile";
export const DETERMINISTIC_FALLBACK_MODEL = "deterministic-rules-v1";
export const DEFAULT_ROUTER_BUDGET_MS = 500;

export type RouterIntent =
  | "deep_reasoning"
  | "memory_recall"
  | "finance_ledger"
  | "coding_debug"
  | "task_planning"
  | "quick_qa"
  | "general_chat";

export type RouterProvider = "groq" | "deterministic_fallback";

export const INTENT_TARGET_AGENT_MAP = {
  deep_reasoning: "reasoning_specialist",
  memory_recall: "memory_retriever",
  finance_ledger: "finance_analyst",
  coding_debug: "code_architect",
  task_planning: "planner_agent",
  quick_qa: "fast_responder",
  general_chat: "fast_responder",
} as const satisfies Record<RouterIntent, string>;

export const INTENT_TARGET_HANDLER_MAP = {
  deep_reasoning: "claude-sonnet-5",
  memory_recall: "memory-hub",
  finance_ledger: "core-hub",
  coding_debug: "claude-sonnet-5",
  task_planning: "app-hub",
  quick_qa: "groq-llama-3.3-70b",
  general_chat: "groq-llama-3.3-70b",
} as const satisfies Record<RouterIntent, string>;

export const ROUTER_PROVIDER_LABELS = {
  groq: "Groq LPU Router",
  deterministic_fallback: "Deterministic Fail-Open Fallback",
} as const satisfies Record<RouterProvider, string>;

export interface LlmIntentRouteResult {
  intent: RouterIntent;
  targetAgent: string;
  targetHandler: string;
  confidence: number;
  latencyMs: number;
  withinSla500ms: boolean;
  provider: RouterProvider;
  model: string;
  fallbackUsed: boolean;
  fallbackReason: string | null;
  rationale: string;
}

export interface RouteIntentOptions {
  input: string;
  groqApiKey?: string | null;
  model?: string;
  budgetMs?: number;
  fetchImpl?: typeof fetch;
  nowMs?: () => number;
}

const VALID_INTENTS = new Set<RouterIntent>([
  "deep_reasoning",
  "memory_recall",
  "finance_ledger",
  "coding_debug",
  "task_planning",
  "quick_qa",
  "general_chat",
]);

export function isRouterIntent(value: unknown): value is RouterIntent {
  return typeof value === "string" && VALID_INTENTS.has(value as RouterIntent);
}

function clampConfidence(value: unknown, fallbackValue: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallbackValue;
  }
  return Math.max(0, Math.min(1, Math.round(value * 1000) / 1000));
}

export function classifyIntentDeterministic(input: string): {
  intent: RouterIntent;
  confidence: number;
  rationale: string;
} {
  const normalized = input.trim().toLowerCase();
  if (!normalized) {
    return {
      intent: "general_chat",
      confidence: 0.5,
      rationale: "Empty input routed to general_chat.",
    };
  }

  const financeRe = new RegExp(
    [
      "receipt",
      "expense",
      "budget",
      "balance",
      "ledger",
      "invoice",
      "payment",
      "家計",
      "収支",
      "資産",
      "残高",
      "レシート",
      "支出",
      "振込",
      "予算",
    ].join("|"),
  );
  if (financeRe.test(normalized)) {
    return {
      intent: "finance_ledger",
      confidence: 0.88,
      rationale: "Matched finance/ledger domain keywords.",
    };
  }

  const memoryRe = new RegExp(
    [
      "remember",
      "recall",
      "memory",
      "previous",
      "history",
      "last time",
      "ノート",
      "記憶",
      "思い出",
      "履歴",
      "前回",
      "過去",
    ].join("|"),
  );
  if (memoryRe.test(normalized)) {
    return {
      intent: "memory_recall",
      confidence: 0.86,
      rationale: "Matched long-term memory recall keywords.",
    };
  }

  const codingRe = new RegExp(
    [
      "stacktrace",
      "exception",
      "typescript",
      "flutter",
      "dart",
      "sql",
      "bug",
      "error",
      "refactor",
      "debug",
      "コード",
      "バグ",
      "エラー",
      "実装",
      "テスト",
      "修正",
    ].join("|"),
  );
  if (codingRe.test(normalized)) {
    return {
      intent: "coding_debug",
      confidence: 0.87,
      rationale: "Matched coding/debugging keywords.",
    };
  }

  const planningRe = new RegExp(
    [
      "schedule",
      "roadmap",
      "plan",
      "wbs",
      "milestone",
      "task",
      "todo",
      "deadline",
      "計画",
      "予定",
      "タスク",
      "期限",
      "ロードマップ",
      "手順",
    ].join("|"),
  );
  if (planningRe.test(normalized)) {
    return {
      intent: "task_planning",
      confidence: 0.84,
      rationale: "Matched task planning keywords.",
    };
  }

  const reasoningRe = new RegExp(
    [
      "architecture",
      "trade-?off",
      "analyze",
      "comparison",
      "proof",
      "deep dive",
      "設計",
      "比較",
      "分析",
      "推論",
      "検証",
      "戦略",
    ].join("|"),
  );
  if (reasoningRe.test(normalized) || normalized.length >= 160) {
    return {
      intent: "deep_reasoning",
      confidence: 0.82,
      rationale: "Matched complex reasoning keywords or long prompt.",
    };
  }

  if (
    normalized.length <= 48 &&
    /(\?|what is|how to|define|意味|とは|教えて|何)/.test(normalized)
  ) {
    return {
      intent: "quick_qa",
      confidence: 0.8,
      rationale: "Short question routed to fast Q&A.",
    };
  }

  return {
    intent: "general_chat",
    confidence: 0.7,
    rationale: "Defaulted to general_chat.",
  };
}

export function parseRouterJsonPayload(rawContent: string): {
  intent: RouterIntent;
  confidence: number;
  rationale: string;
} | null {
  const trimmed = rawContent.trim();
  if (!trimmed) return null;

  const unwrapped = trimmed
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  try {
    const parsed = JSON.parse(unwrapped) as Record<string, unknown>;
    if (!parsed || typeof parsed !== "object") return null;
    if (!isRouterIntent(parsed.intent)) return null;
    const rationale = typeof parsed.rationale === "string" &&
        parsed.rationale.trim().length > 0
      ? parsed.rationale.trim().slice(0, 240)
      : `Classified as ${parsed.intent} by Groq router.`;
    return {
      intent: parsed.intent,
      confidence: clampConfidence(parsed.confidence, 0.85),
      rationale,
    };
  } catch {
    return null;
  }
}

function buildFallbackResult(
  input: string,
  latencyMs: number,
  fallbackReason: string,
): LlmIntentRouteResult {
  const decision = classifyIntentDeterministic(input);
  const roundedLatency = Math.max(0, Math.round(latencyMs));
  return {
    intent: decision.intent,
    targetAgent: INTENT_TARGET_AGENT_MAP[decision.intent],
    targetHandler: INTENT_TARGET_HANDLER_MAP[decision.intent],
    confidence: decision.confidence,
    latencyMs: roundedLatency,
    withinSla500ms: roundedLatency <= DEFAULT_ROUTER_BUDGET_MS,
    provider: "deterministic_fallback",
    model: DETERMINISTIC_FALLBACK_MODEL,
    fallbackUsed: true,
    fallbackReason,
    rationale: decision.rationale,
  };
}

function getEnvGroqApiKey(): string | null {
  try {
    const value = Deno.env.get("GROQ_API_KEY");
    return value && value.trim().length > 0 ? value.trim() : null;
  } catch {
    return null;
  }
}

export async function routeIntentWithGroq(
  options: RouteIntentOptions,
): Promise<LlmIntentRouteResult> {
  const now = options.nowMs ?? (() => performance.now());
  const startedAt = now();
  const budgetMs = Math.max(
    50,
    Math.min(
      DEFAULT_ROUTER_BUDGET_MS,
      options.budgetMs ?? DEFAULT_ROUTER_BUDGET_MS,
    ),
  );
  const model = options.model?.trim() || DEFAULT_GROQ_ROUTER_MODEL;
  const trimmedInput = options.input.trim();

  if (!trimmedInput) {
    return buildFallbackResult("", now() - startedAt, "empty_input");
  }

  const apiKey = options.groqApiKey !== undefined
    ? options.groqApiKey?.trim() || null
    : getEnvGroqApiKey();

  if (!apiKey) {
    return buildFallbackResult(
      trimmedInput,
      now() - startedAt,
      "missing_groq_api_key",
    );
  }

  const fetcher = options.fetchImpl ?? fetch;
  const controller = new AbortController();
  const timerId = setTimeout(() => controller.abort(), budgetMs);

  try {
    const systemPrompt = [
      "You are an ultra-low-latency intent router.",
      "Classify the user prompt into exactly one intent from:",
      "deep_reasoning, memory_recall, finance_ledger, coding_debug,",
      "task_planning, quick_qa, general_chat.",
      'Return strict JSON only:',
      '{"intent":"<key>","confidence":0.0-1.0,"rationale":"<short reason>"}.',
    ].join(" ");

    const response = await fetcher(GROQ_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_tokens: 160,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: trimmedInput.slice(0, 1200) },
        ],
      }),
      signal: controller.signal,
    });

    const elapsedMs = Math.max(0, Math.round(now() - startedAt));
    if (elapsedMs > budgetMs) {
      return buildFallbackResult(
        trimmedInput,
        elapsedMs,
        "latency_budget_exceeded",
      );
    }

    if (!response.ok) {
      return buildFallbackResult(
        trimmedInput,
        elapsedMs,
        `http_${response.status}`,
      );
    }

    const payload = await response.json() as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const rawContent = payload?.choices?.[0]?.message?.content ?? "";
    const parsed = parseRouterJsonPayload(rawContent);
    if (!parsed) {
      return buildFallbackResult(
        trimmedInput,
        elapsedMs,
        "invalid_json_response",
      );
    }

    return {
      intent: parsed.intent,
      targetAgent: INTENT_TARGET_AGENT_MAP[parsed.intent],
      targetHandler: INTENT_TARGET_HANDLER_MAP[parsed.intent],
      confidence: parsed.confidence,
      latencyMs: elapsedMs,
      withinSla500ms: elapsedMs <= DEFAULT_ROUTER_BUDGET_MS,
      provider: "groq",
      model,
      fallbackUsed: false,
      fallbackReason: null,
      rationale: parsed.rationale,
    };
  } catch (error) {
    const elapsedMs = Math.max(0, Math.round(now() - startedAt));
    const isAbort = error instanceof DOMException &&
      error.name === "AbortError";
    return buildFallbackResult(
      trimmedInput,
      elapsedMs,
      isAbort ? "timeout_budget_exceeded" : "network_error",
    );
  } finally {
    clearTimeout(timerId);
  }
}

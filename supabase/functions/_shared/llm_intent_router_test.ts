import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  classifyIntentDeterministic,
  DEFAULT_GROQ_ROUTER_MODEL,
  INTENT_TARGET_AGENT_MAP,
  INTENT_TARGET_HANDLER_MAP,
  parseRouterJsonPayload,
  routeIntentWithGroq,
} from "./llm_intent_router.ts";

Deno.test(
  "routeIntentWithGroq falls back when GROQ_API_KEY is absent",
  async () => {
    let fetchCalled = false;
    const result = await routeIntentWithGroq({
      input: "今月のレシート支出と残高を確認したい",
      groqApiKey: null,
      fetchImpl: () => {
        fetchCalled = true;
        return Promise.resolve(new Response("{}", { status: 200 }));
      },
      nowMs: () => 1000,
    });

    assertEquals(fetchCalled, false);
    assertEquals(result.intent, "finance_ledger");
    assertEquals(result.targetAgent, INTENT_TARGET_AGENT_MAP.finance_ledger);
    assertEquals(
      result.targetHandler,
      INTENT_TARGET_HANDLER_MAP.finance_ledger,
    );
    assertEquals(result.provider, "deterministic_fallback");
    assertEquals(result.fallbackUsed, true);
    assertEquals(result.fallbackReason, "missing_groq_api_key");
    assertEquals(result.withinSla500ms, true);
  },
);

Deno.test(
  "routeIntentWithGroq routes Groq JSON within 500ms SLA",
  async () => {
    const ticks = [100, 245];
    let idx = 0;
    let capturedAuth = "";
    let capturedModel = "";

    const result = await routeIntentWithGroq({
      input: "Compare microservices vs modular monolith trade-offs",
      groqApiKey: "test-key-placeholder",
      nowMs: () => ticks[Math.min(idx++, ticks.length - 1)],
      fetchImpl: (_input, init) => {
        const headers = init?.headers as Record<string, string>;
        capturedAuth = headers.Authorization;
        const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
        capturedModel = String(body.model);
        const content = JSON.stringify({
          intent: "deep_reasoning",
          confidence: 0.94,
          rationale: "Requires architectural trade-off reasoning.",
        });
        return Promise.resolve(
          new Response(
            JSON.stringify({
              choices: [{ message: { content } }],
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          ),
        );
      },
    });

    assertEquals(capturedAuth, "Bearer test-key-placeholder");
    assertEquals(capturedModel, DEFAULT_GROQ_ROUTER_MODEL);
    assertEquals(result.intent, "deep_reasoning");
    assertEquals(result.targetAgent, "reasoning_specialist");
    assertEquals(result.targetHandler, "claude-sonnet-5");
    assertEquals(result.provider, "groq");
    assertEquals(result.fallbackUsed, false);
    assertEquals(result.fallbackReason, null);
    assertEquals(result.latencyMs, 145);
    assertEquals(result.withinSla500ms, true);
  },
);

Deno.test(
  "routeIntentWithGroq fails open when latency exceeds 500ms",
  async () => {
    const ticks = [1000, 1620];
    let idx = 0;

    const result = await routeIntentWithGroq({
      input: "前回の会議ノートを思い出して",
      groqApiKey: "test-key-placeholder",
      nowMs: () => ticks[Math.min(idx++, ticks.length - 1)],
      fetchImpl: () =>
        Promise.resolve(
          new Response(
            JSON.stringify({
              choices: [
                {
                  message: {
                    content: '{"intent":"memory_recall","confidence":0.9}',
                  },
                },
              ],
            }),
            { status: 200 },
          ),
        ),
    });

    assertEquals(result.intent, "memory_recall");
    assertEquals(result.provider, "deterministic_fallback");
    assertEquals(result.fallbackUsed, true);
    assertEquals(result.fallbackReason, "latency_budget_exceeded");
    assertEquals(result.latencyMs, 620);
    assertEquals(result.withinSla500ms, false);
  },
);

Deno.test(
  "routeIntentWithGroq fails open on timeout and HTTP errors",
  async () => {
    const timeoutResult = await routeIntentWithGroq({
      input: "FlutterのNullPointerエラーを直して",
      groqApiKey: "test-key-placeholder",
      nowMs: () => 50,
      fetchImpl: () =>
        Promise.reject(new DOMException("Aborted", "AbortError")),
    });

    assertEquals(timeoutResult.intent, "coding_debug");
    assertEquals(timeoutResult.fallbackUsed, true);
    assertEquals(timeoutResult.fallbackReason, "timeout_budget_exceeded");

    const httpErrorResult = await routeIntentWithGroq({
      input: "来週のWBSタスク計画を立てて",
      groqApiKey: "test-key-placeholder",
      nowMs: () => 50,
      fetchImpl: () =>
        Promise.resolve(new Response("rate limited", { status: 429 })),
    });

    assertEquals(httpErrorResult.intent, "task_planning");
    assertEquals(httpErrorResult.fallbackUsed, true);
    assertEquals(httpErrorResult.fallbackReason, "http_429");
  },
);

Deno.test(
  "parseRouterJsonPayload unwraps fences and rejects bad intents",
  () => {
    const fenced = [
      "```json",
      '{"intent":"quick_qa","confidence":1.4,"rationale":"Short question"}',
      "```",
    ].join("\n");
    const valid = parseRouterJsonPayload(fenced);
    assertExists(valid);
    assertEquals(valid.intent, "quick_qa");
    assertEquals(valid.confidence, 1);

    const invalid = parseRouterJsonPayload('{"intent":"unknown_intent"}');
    assertEquals(invalid, null);

    const qa = classifyIntentDeterministic("Supabaseとは何?");
    assertEquals(qa.intent, "quick_qa");
  },
);

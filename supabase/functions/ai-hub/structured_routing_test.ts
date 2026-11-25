import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeSchemaComplexityScore,
  handleStructuredRoutingAction,
  routeLlmTaskByComplexity,
  type SavedRoutingPreference,
  type StructuredRoutingStore,
  validateAgainstJsonSchema,
} from "./structured_routing.ts";

function createInMemoryStore(
  initial: SavedRoutingPreference[] = [],
): {
  store: StructuredRoutingStore;
  upsertCount: () => number;
  getAll: () => SavedRoutingPreference[];
} {
  const rows = [...initial];
  let upserts = 0;

  const store: StructuredRoutingStore = {
    getTaskPreference(_userId: string, task: string) {
      const found = rows.find((item) => item.task === task) ?? null;
      return Promise.resolve(found);
    },
    listTaskPreferences(_userId: string) {
      return Promise.resolve([...rows]);
    },
    upsertTaskPreference(params) {
      upserts += 1;
      const saved: SavedRoutingPreference = {
        task: params.task,
        provider: params.provider,
        model: params.model,
        is_enabled: true,
        source: params.source,
        updated_at: "2026-11-25T10:00:00.000Z",
      };
      const existingIdx = rows.findIndex((item) => item.task === params.task);
      if (existingIdx >= 0) {
        rows[existingIdx] = saved;
      } else {
        rows.push(saved);
      }
      return Promise.resolve(saved);
    },
  };

  return {
    store,
    upsertCount: () => upserts,
    getAll: () => [...rows],
  };
}

Deno.test("routes lightweight classification to flash-lite", () => {
  const decision = routeLlmTaskByComplexity({
    taskType: "classification",
    prompt: "Classify this invoice category into food or utilities.",
  });
  assertEquals(decision.tier, "trivial");
  assertEquals(decision.modelClass, "lightweight");
  assertEquals(decision.provider, "google_flash_lite");
  assertEquals(decision.model, "gemini-2.5-flash-lite");
  assertEquals(decision.effort, "low");
});

Deno.test("routes complex analysis to advanced claude-sonnet-4-6", () => {
  const decision = routeLlmTaskByComplexity({
    taskType: "analysis",
    prompt: "Compare design tradeoffs and multi-step reasoning impacts.",
    requiresReasoning: true,
  });
  assertEquals(decision.tier, "complex");
  assertEquals(decision.modelClass, "advanced");
  assertEquals(decision.provider, "anthropic");
  assertEquals(decision.model, "claude-sonnet-4-6");
  assertEquals(decision.effort, "high");
});

Deno.test("routeLlmTaskByComplexity applies saved manual override", () => {
  const decision = routeLlmTaskByComplexity({
    taskType: "summary",
    prompt: "Summarize daily expenses.",
    savedPreference: {
      task: "summary",
      provider: "groq",
      model: "llama-3.3-70b-versatile",
      is_enabled: true,
      source: "manual",
    },
  });
  assertEquals(decision.tier, "standard");
  assertEquals(decision.provider, "groq");
  assertEquals(decision.model, "llama-3.3-70b-versatile");
  assertEquals(decision.preferenceApplied, true);
  assertEquals(decision.recommendedProvider, "openai");
});

Deno.test("validateAgainstJsonSchema checks strict schema & fences", () => {
  const schema = {
    type: "object",
    additionalProperties: false,
    required: ["category", "confidence", "tags"],
    properties: {
      category: { type: "string", enum: ["food", "travel", "software"] },
      confidence: { type: "number", minimum: 0, maximum: 1 },
      tags: {
        type: "array",
        minItems: 1,
        items: { type: "string", minLength: 2 },
      },
    },
  };

  const valid = validateAgainstJsonSchema(
    '```json\n{"category":"software","confidence":0.92,"tags":["saas"]}\n```',
    schema,
  );
  assertEquals(valid.valid, true);
  assertEquals(valid.issues.length, 0);

  const rejected = validateAgainstJsonSchema(
    '{"category":"unknown","confidence":1.4,"extra":true}',
    schema,
  );
  assertEquals(rejected.valid, false);
  assertEquals(rejected.normalizedJson, null);
  assertEquals(rejected.issues.length >= 3, true);
});

Deno.test("rejects unauthenticated and mismatched user_id", async () => {
  const mem = createInMemoryStore();
  const unauth = await handleStructuredRoutingAction({
    action: "ai_router.structured.route",
    body: { task_type: "classification" },
    userId: null,
    isElevatedAutomation: false,
    store: mem.store,
  });
  assertEquals(unauth.status, 401);

  const mismatch = await handleStructuredRoutingAction({
    action: "ai_router.structured.list_preferences",
    body: { user_id: "user-other" },
    userId: "user-1",
    isElevatedAutomation: false,
    store: mem.store,
  });
  assertEquals(mismatch.status, 403);
});

Deno.test("validate_and_save fails closed and saves valid JSON", async () => {
  const mem = createInMemoryStore();
  const schema = {
    type: "object",
    additionalProperties: false,
    required: ["intent"],
    properties: {
      intent: { type: "string", enum: ["billing", "support"] },
    },
  };

  const invalidRes = await handleStructuredRoutingAction({
    action: "ai_router.structured.validate_and_save",
    body: {
      task_type: "classification",
      raw_output: '{"intent":"invalid"}',
      response_schema: schema,
    },
    userId: "user-1",
    isElevatedAutomation: false,
    store: mem.store,
  });
  assertEquals(invalidRes.status, 422);
  assertEquals(invalidRes.body.saved, false);
  assertEquals(mem.upsertCount(), 0);

  const validRes = await handleStructuredRoutingAction({
    action: "ai_router.structured.validate_and_save",
    body: {
      task_type: "classification",
      raw_output: '{"intent":"billing"}',
      response_schema: schema,
    },
    userId: "user-1",
    isElevatedAutomation: false,
    store: mem.store,
  });
  assertEquals(validRes.status, 200);
  assertEquals(validRes.body.saved, true);
  assertEquals(mem.upsertCount(), 1);
  assertEquals(mem.getAll()[0]?.provider, "google_flash_lite");
});

Deno.test("computeSchemaComplexityScore reflects nested properties", () => {
  const simpleScore = computeSchemaComplexityScore({
    type: "object",
    properties: { label: { type: "string" } },
  });
  assertEquals(simpleScore, 1);
});

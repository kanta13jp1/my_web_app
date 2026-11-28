import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyProviderGenerationOptions,
  applyStructuredGenerationOptions,
  GEMINI_MAX_THINKING_BUDGET,
  GEMINI_MIN_THINKING_BUDGET,
  GEMINI_OUTPUT_TOKEN_RESERVE,
} from "./provider_generation_options.ts";

Deno.test("gemini caps thinking budget so output tokens are reserved", () => {
  const body = applyProviderGenerationOptions(
    "google",
    { contents: [] },
    { maxTokens: 24000 },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.maxOutputTokens, 24000);
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(
    thinkingConfig.thinkingBudget,
    24000 - GEMINI_OUTPUT_TOKEN_RESERVE,
  );
});

Deno.test("gemini flash-lite also gets a thinking budget", () => {
  const body = applyProviderGenerationOptions(
    "google_flash_lite",
    { contents: [] },
    { maxTokens: 20000 },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(
    thinkingConfig.thinkingBudget,
    20000 - GEMINI_OUTPUT_TOKEN_RESERVE,
  );
});

Deno.test(
  "gemini clamps the thinking budget to the valid minimum for the 8192 cap " +
    "(regression: production maxTokens=8192 produced 192 -> 400)",
  () => {
    // index.ts の normalizeMaxTokens は maxTokens を 8192 上限へクランプするため、
    // 資産要約のような大きな要求は常に 8192 で届く。旧実装は 8192-8000=192 を
    // thinkingBudget に渡し Gemini の 400 ("192 invalid, choose 512-24576") を招いた。
    const body = applyProviderGenerationOptions(
      "google_flash_lite",
      { contents: [] },
      { maxTokens: 8192 },
    );
    const generationConfig = body.generationConfig as Record<string, unknown>;
    assertEquals(generationConfig.maxOutputTokens, 8192);
    const thinkingConfig = generationConfig.thinkingConfig as Record<
      string,
      unknown
    >;
    assertEquals(thinkingConfig.thinkingBudget, GEMINI_MIN_THINKING_BUDGET);
  },
);

Deno.test("gemini never exceeds the maximum thinking budget", () => {
  const body = applyProviderGenerationOptions(
    "google",
    { contents: [] },
    {
      maxTokens: GEMINI_MAX_THINKING_BUDGET + GEMINI_OUTPUT_TOKEN_RESERVE + 100,
    },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(thinkingConfig.thinkingBudget, GEMINI_MAX_THINKING_BUDGET);
});

Deno.test("gemini does not set a thinking budget for tiny max tokens", () => {
  const body = applyProviderGenerationOptions(
    "google",
    { contents: [] },
    { maxTokens: GEMINI_MIN_THINKING_BUDGET },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.maxOutputTokens, GEMINI_MIN_THINKING_BUDGET);
  assertEquals(generationConfig.thinkingConfig, undefined);
});

Deno.test("gemini respects a caller-provided thinkingConfig", () => {
  const body = applyProviderGenerationOptions(
    "google",
    {
      contents: [],
      generationConfig: { thinkingConfig: { thinkingBudget: 1234 } },
    },
    { maxTokens: 24000 },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  // 明示指定は上書きしない。
  assertEquals(thinkingConfig.thinkingBudget, 1234);
  assertEquals(generationConfig.maxOutputTokens, 24000);
});

Deno.test("openai uses max_completion_tokens without thinking budget", () => {
  const body = applyProviderGenerationOptions(
    "openai",
    { model: "gpt-5", max_tokens: 512 },
    { maxTokens: 24000 },
  );
  assertEquals(body.max_completion_tokens, 24000);
  assertEquals(body.max_tokens, undefined);
  assertEquals(body.generationConfig, undefined);
});

Deno.test("non-gemini providers fall back to max_tokens", () => {
  const body = applyProviderGenerationOptions(
    "groq",
    { model: "llama" },
    { maxTokens: 2048 },
  );
  assertEquals(body.max_tokens, 2048);
  assertEquals(body.generationConfig, undefined);
});

Deno.test("gemini applies responseSchema without maxTokens", () => {
  const body = applyStructuredGenerationOptions(
    "google_flash_lite",
    { contents: [] },
    {
      responseMimeType: "application/json",
      responseSchema: {
        $schema: "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        additionalProperties: false,
        properties: {
          tier: { type: "string", enum: ["trivial", "standard"] },
          tags: {
            type: "array",
            items: { type: "string" },
          },
        },
        required: ["tier"],
      },
    },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.responseMimeType, "application/json");
  const schema = generationConfig.responseSchema as Record<string, unknown>;
  assertEquals(schema.$schema, undefined);
  assertEquals(schema.additionalProperties, undefined);
  assertEquals(schema.type, "object");
});

Deno.test("openai emits strict json_schema and strips $schema", () => {
  const body = applyStructuredGenerationOptions(
    "openai",
    applyProviderGenerationOptions(
      "openai",
      { model: "gpt-5.4-mini" },
      { maxTokens: 4096 },
    ),
    {
      schemaName: "route_summary",
      responseSchema: {
        $schema: "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          summary: { type: "string" },
        },
        required: ["summary"],
      },
    },
  );
  assertEquals(body.max_completion_tokens, 4096);
  const responseFormat = body.response_format as Record<string, unknown>;
  assertEquals(responseFormat.type, "json_schema");
  const jsonSchema = responseFormat.json_schema as Record<string, unknown>;
  assertEquals(jsonSchema.name, "route_summary");
  assertEquals(jsonSchema.strict, true);
  const inner = jsonSchema.schema as Record<string, unknown>;
  assertEquals(inner.$schema, undefined);
  assertEquals(inner.additionalProperties, false);
});

Deno.test("anthropic skips response_format while keeping max_tokens", () => {
  const body = applyStructuredGenerationOptions(
    "anthropic",
    applyProviderGenerationOptions(
      "anthropic",
      { model: "claude-sonnet-4-6" },
      { maxTokens: 1024 },
    ),
    {
      responseMimeType: "application/json",
      responseSchema: {
        type: "object",
        properties: { ok: { type: "boolean" } },
      },
    },
  );
  assertEquals(body.max_tokens, 1024);
  assertEquals(body.response_format, undefined);
});

Deno.test("gemini-4 strips temperature and low maxOutputTokens while setting thinkingLevel LOW", () => {
  const body = applyProviderGenerationOptions(
    "google",
    {
      contents: [{ parts: [{ text: "hello" }] }],
      generationConfig: {
        temperature: 0.7,
        topP: 0.9,
        topK: 40,
        maxOutputTokens: 1024,
      },
    },
    { maxTokens: 4096, model: "gemini-4-hydrogen" },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.temperature, undefined);
  assertEquals(generationConfig.topP, undefined);
  assertEquals(generationConfig.topK, undefined);
  assertEquals(generationConfig.maxOutputTokens, undefined);
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(thinkingConfig.thinkingLevel, "LOW");
});

Deno.test("gemini-4 preserves caller thinkingConfig and keeps maxOutputTokens >= 65536", () => {
  const body = applyProviderGenerationOptions(
    "google_flash_lite",
    {
      contents: [{ parts: [{ text: "hello" }] }],
      generationConfig: {
        thinkingConfig: { thinkingLevel: "HIGH" },
      },
    },
    { maxTokens: 65536, model: "gemini-4-hydrogen" },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.maxOutputTokens, 65536);
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(thinkingConfig.thinkingLevel, "HIGH");
});

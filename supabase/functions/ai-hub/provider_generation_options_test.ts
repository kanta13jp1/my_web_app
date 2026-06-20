import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyProviderGenerationOptions,
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

Deno.test("openai uses max_completion_tokens and never a thinking budget", () => {
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

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyProviderGenerationOptions,
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

Deno.test("gemini does not set a thinking budget for small max tokens", () => {
  const body = applyProviderGenerationOptions(
    "google",
    { contents: [] },
    { maxTokens: GEMINI_OUTPUT_TOKEN_RESERVE },
  );
  const generationConfig = body.generationConfig as Record<string, unknown>;
  assertEquals(generationConfig.maxOutputTokens, GEMINI_OUTPUT_TOKEN_RESERVE);
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

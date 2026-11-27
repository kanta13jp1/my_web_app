import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateJsonWithGeminiFirst } from "./gemini_json_client.ts";

Deno.test("generateJsonWithGeminiFirst uses Gemini first, disables thinking for 2.5-flash, and skips thought parts", async () => {
  const calledUrls: string[] = [];
  let sentBody: Record<string, unknown> = {};

  const parsed = await generateJsonWithGeminiFirst({
    systemPrompt: "Return JSON only.",
    userPrompt: "Analyze test input",
    geminiApiKey: "gemini-key",
    openAiApiKey: "openai-key",
    fetchImpl: (input, init) => {
      calledUrls.push(String(input));
      sentBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    { text: "internal reasoning", thought: true },
                    { text: '{"summary":"ok","count":1}' },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  assertEquals(calledUrls.length, 1);
  assertStringIncludes(calledUrls[0], "generativelanguage.googleapis.com");
  assertEquals(calledUrls[0].includes("api.openai.com"), false);
  const generationConfig = sentBody.generationConfig as Record<string, unknown>;
  const thinkingConfig = generationConfig.thinkingConfig as Record<
    string,
    unknown
  >;
  assertEquals(thinkingConfig.thinkingBudget, 0);
  assertEquals(parsed, { summary: "ok", count: 1 });
});

Deno.test("generateJsonWithGeminiFirst falls back to OpenAI only when Gemini fails", async () => {
  const calledUrls: string[] = [];

  const parsed = await generateJsonWithGeminiFirst({
    systemPrompt: "Return JSON only.",
    userPrompt: "Analyze test input",
    geminiApiKey: "gemini-key",
    openAiApiKey: "openai-key",
    fetchImpl: (input) => {
      const url = String(input);
      calledUrls.push(url);
      if (url.includes("generativelanguage.googleapis.com")) {
        return Promise.resolve(new Response("rate limited", { status: 429 }));
      }
      return Promise.resolve(
        new Response(
          JSON.stringify({
            choices: [
              { message: { content: '{"summary":"fallback-ok"}' } },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  assertEquals(calledUrls.length, 2);
  assertStringIncludes(calledUrls[0], "generativelanguage.googleapis.com");
  assertEquals(calledUrls[1], "https://api.openai.com/v1/chat/completions");
  assertEquals(parsed, { summary: "fallback-ok" });
});

Deno.test("generateJsonWithGeminiFirst omits thinkingConfig for non-2.5-flash models", async () => {
  let sentBody: Record<string, unknown> = {};

  const parsed = await generateJsonWithGeminiFirst({
    systemPrompt: "Return JSON only.",
    userPrompt: "Analyze test input",
    geminiApiKey: "gemini-key",
    geminiModel: "gemini-2.5-pro",
    fetchImpl: (_input, init) => {
      sentBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [
              { content: { parts: [{ text: '{"ok":true}' }] } },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  const generationConfig = sentBody.generationConfig as Record<string, unknown>;
  assertEquals("thinkingConfig" in generationConfig, false);
  assertEquals(parsed, { ok: true });
});

Deno.test("generateJsonWithGeminiFirst returns null without throwing when all providers fail or keys are missing", async () => {
  const missingResult = await generateJsonWithGeminiFirst({
    systemPrompt: "Return JSON only.",
    userPrompt: "Analyze test input",
  });
  assertEquals(missingResult, null);

  const failedResult = await generateJsonWithGeminiFirst({
    systemPrompt: "Return JSON only.",
    userPrompt: "Analyze test input",
    geminiApiKey: "gemini-key",
    openAiApiKey: "openai-key",
    fetchImpl: () => Promise.resolve(new Response("error", { status: 503 })),
  });
  assertEquals(failedResult, null);
});

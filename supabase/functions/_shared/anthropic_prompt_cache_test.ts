import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  anthropicPromptCacheEnabled,
  buildAnthropicMessagesBody,
} from "./anthropic_prompt_cache.ts";
import { calculateApiCost } from "./task_budget.ts";

Deno.test("prompt caching is on by default and has a system-wide off switch", () => {
  assertEquals(anthropicPromptCacheEnabled(undefined), true);
  assertEquals(anthropicPromptCacheEnabled(""), true);
  for (const value of ["0", "false", "OFF", " disabled ", "no"]) {
    assertFalse(anthropicPromptCacheEnabled(value));
  }
});

Deno.test("Anthropic body separates static system content and caches its final block", () => {
  const body = buildAnthropicMessagesBody(
    [
      { role: "system", content: "Stable policy" },
      { role: "system", content: "Stable examples" },
      { role: "user", content: "Dynamic request" },
    ],
    "claude-haiku-4-5-20251001",
    { maxTokens: 256 },
  );

  assertEquals(body.messages, [{ role: "user", content: "Dynamic request" }]);
  assertEquals(body.system, [
    { type: "text", text: "Stable policy" },
    {
      type: "text",
      text: "Stable examples",
      cache_control: { type: "ephemeral" },
    },
  ]);
  assertEquals(body.max_tokens, 256);
});

Deno.test("disabling caching preserves the system prompt but omits cache_control", () => {
  const body = buildAnthropicMessagesBody(
    [
      { role: "system", content: "Stable policy" },
      { role: "user", content: "Dynamic request" },
    ],
    "claude-sonnet-5",
    { cacheSystem: false },
  );

  assertEquals(body.system, [{ type: "text", text: "Stable policy" }]);
  assertEquals(body.messages, [{ role: "user", content: "Dynamic request" }]);
});

Deno.test("five-minute cache reads and writes are included in Anthropic cost", () => {
  assertEquals(
    calculateApiCost("claude-haiku-4-5-20251001", 0, 0, {
      cacheReadInputTokens: 1_000_000,
      cacheCreationInputTokens: 1_000_000,
    }),
    1.35,
  );
});

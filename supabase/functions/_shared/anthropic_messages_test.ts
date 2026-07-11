import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  appendSystemEntry,
  attachCacheDiagnostics,
  buildAnthropicMessagesBody,
  extractAnthropicUsage,
  extractCacheMissReason,
  supportsMidConversationSystem,
} from "./anthropic_messages.ts";

Deno.test("buildAnthropicMessagesBody splits system into cached top-level blocks", () => {
  const body = buildAnthropicMessagesBody(
    [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", content: "hello" },
    ],
    "claude-haiku-4-5-20251001",
    { maxTokens: 256 },
  );
  assertEquals(body.model, "claude-haiku-4-5-20251001");
  assertEquals(body.max_tokens, 256);
  assertEquals(body.messages, [{ role: "user", content: "hello" }]);
  assertEquals(body.system, [{
    type: "text",
    text: "You are a helpful assistant.",
    cache_control: { type: "ephemeral" },
  }]);
});

Deno.test("buildAnthropicMessagesBody omits system when absent and puts breakpoint on last block", () => {
  const noSystem = buildAnthropicMessagesBody(
    [{ role: "user", content: "hi" }],
    "claude-haiku-4-5-20251001",
  );
  assertStrictEquals("system" in noSystem, false);
  assertEquals(noSystem.max_tokens, 512);

  const twoSystems = buildAnthropicMessagesBody(
    [
      { role: "system", content: "stable core" },
      { role: "system", content: "second block" },
      { role: "user", content: "hi" },
    ],
    "claude-haiku-4-5-20251001",
  );
  const blocks = twoSystems.system as Array<Record<string, unknown>>;
  assertEquals(blocks.length, 2);
  assertStrictEquals("cache_control" in blocks[0], false);
  assertEquals(blocks[1].cache_control, { type: "ephemeral" });
});

Deno.test("attachCacheDiagnostics adds previous_message_id (null on first turn)", () => {
  const body = attachCacheDiagnostics({ model: "m" }, null);
  assertEquals(body.diagnostics, { previous_message_id: null });
  const second = attachCacheDiagnostics({ model: "m" }, "msg_123");
  assertEquals(second.diagnostics, { previous_message_id: "msg_123" });
});

Deno.test("extractAnthropicUsage reads token and cache metrics", () => {
  const usage = extractAnthropicUsage({
    usage: {
      input_tokens: 100,
      output_tokens: 20,
      cache_read_input_tokens: 80,
      cache_creation_input_tokens: 0,
    },
  });
  assertEquals(usage, {
    input_tokens: 100,
    output_tokens: 20,
    cache_read_input_tokens: 80,
    cache_creation_input_tokens: 0,
  });
  assertStrictEquals(extractAnthropicUsage({}), null);
  assertStrictEquals(extractAnthropicUsage(null), null);
});

Deno.test("extractCacheMissReason reads diagnostics", () => {
  assertEquals(
    extractCacheMissReason({
      diagnostics: { cache_miss_reason: "prefix_diverged_at_system" },
    }),
    "prefix_diverged_at_system",
  );
  assertStrictEquals(extractCacheMissReason({ diagnostics: {} }), null);
  assertStrictEquals(extractCacheMissReason({}), null);
});

Deno.test("supportsMidConversationSystem gates to Opus 4.8", () => {
  assertStrictEquals(supportsMidConversationSystem("claude-opus-4-8"), true);
  assertStrictEquals(supportsMidConversationSystem("claude-opus-4-7"), false);
  assertStrictEquals(
    supportsMidConversationSystem("claude-haiku-4-5-20251001"),
    false,
  );
});

Deno.test("appendSystemEntry uses system role on Opus 4.8", () => {
  const result = appendSystemEntry(
    [{ role: "user", content: "question" }],
    "Terse mode enabled.",
    "claude-opus-4-8",
  );
  assertEquals(result[result.length - 1], {
    role: "system",
    content: "Terse mode enabled.",
  });
});

Deno.test("appendSystemEntry falls back to system-reminder on unsupported models", () => {
  const result = appendSystemEntry(
    [{ role: "user", content: "question" }],
    "Terse mode enabled.",
    "claude-sonnet-4-6",
  );
  assertEquals(result.length, 1);
  assertEquals(
    result[0].content,
    "question\n\n<system-reminder>\nTerse mode enabled.\n</system-reminder>",
  );

  const afterAssistant = appendSystemEntry(
    [
      { role: "user", content: "q" },
      { role: "assistant", content: "a" },
    ],
    "New constraint.",
    "claude-sonnet-4-6",
  );
  assertEquals(afterAssistant.length, 3);
  assertEquals(afterAssistant[2].role, "user");
});

Deno.test("appendSystemEntry ignores empty instructions", () => {
  const messages = [{ role: "user", content: "q" }];
  assertStrictEquals(
    appendSystemEntry(messages, "   ", "claude-opus-4-8"),
    messages,
  );
});

import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  generateLandingTrialSuggestion,
  hashLandingTrialClient,
  LandingTrialInputError,
  normalizeLandingTrialPrompt,
  parseLandingTrialSuggestion,
  resolveLandingTrialClientAddress,
} from "./landing_trial.ts";

Deno.test("landing trial prompt is compacted and bounded", () => {
  assertEquals(
    normalizeLandingTrialPrompt("  仕事が多い\n  最初の一手を決めたい  "),
    "仕事が多い 最初の一手を決めたい",
  );
  assertThrows(
    () => normalizeLandingTrialPrompt(""),
    LandingTrialInputError,
    "prompt is required",
  );
  assertThrows(
    () => normalizeLandingTrialPrompt("あ".repeat(281)),
    LandingTrialInputError,
    "280 characters or fewer",
  );
});

Deno.test("landing trial response accepts fenced JSON and removes URLs", () => {
  assertEquals(
    parseLandingTrialSuggestion(
      '```json\n{"action":"案件を1つ開く","reason":"確認先を決めると進みます https://example.com"}\n```',
    ),
    {
      action: "案件を1つ開く",
      reason: "確認先を決めると進みます",
    },
  );
});

Deno.test("landing trial response rejects incomplete output", () => {
  assertThrows(
    () => parseLandingTrialSuggestion('{"action":"1件開く"}'),
    Error,
    "incomplete",
  );
});

Deno.test("landing trial client address prefers trusted proxy headers", () => {
  assertEquals(
    resolveLandingTrialClientAddress(
      new Headers({
        "cf-connecting-ip": "203.0.113.7",
        "x-forwarded-for": "198.51.100.2, 10.0.0.1",
      }),
    ),
    "203.0.113.7",
  );
});

Deno.test("landing trial client hash is deterministic and does not expose IP", async () => {
  const headers = new Headers({
    "x-forwarded-for": "203.0.113.10, 10.0.0.1",
    "user-agent": "trial-test",
  });
  const first = await hashLandingTrialClient(headers, "test-salt");
  const second = await hashLandingTrialClient(headers, "test-salt");
  assertEquals(first, second);
  assertEquals(first.length, 64);
  assertEquals(first.includes("203.0.113.10"), false);
});

Deno.test("landing trial provider request is constrained server-side", async () => {
  let requestBody: Record<string, unknown> = {};
  const suggestion = await generateLandingTrialSuggestion({
    apiKey: "test-key",
    prompt: "仕事が多すぎて優先順位を決められない",
    fetchImpl: (_input, init) => {
      requestBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return Promise.resolve(
        new Response(
          JSON.stringify({
            choices: [{
              message: {
                content:
                  '{"action":"止まっている案件を1つ開く","reason":"確認先を決めれば次の10分で前進できるため"}',
              },
            }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  assertEquals(suggestion.action, "止まっている案件を1つ開く");
  assertEquals(requestBody.model, "gpt-4o-mini");
  assertEquals(requestBody.max_tokens, 160);
  const messages = requestBody.messages as Array<{ content: string }>;
  assertStringIncludes(messages[0].content, "untrusted data");
  assertStringIncludes(messages[1].content, "仕事が多すぎて");
});

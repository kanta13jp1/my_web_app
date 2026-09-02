import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  generateLandingTrialSuggestion,
  hashLandingTrialClient,
  LandingTrialInputError,
  landingTrialQualityIssues,
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

Deno.test("landing trial quality gate accepts a specific ten-minute step", () => {
  assertEquals(
    landingTrialQualityIssues("LPからユーザー登録されない", {
      action: "登録ボタン直前に無料の成果を1文追記",
      reason: "登録後の価値が見えない離脱要因を10分で減らせるため",
    }),
    [],
  );
});

Deno.test("landing trial quality gate rejects generic advice", () => {
  const issues = landingTrialQualityIssues("LPからユーザー登録されない", {
    action: "タスクをリスト化する",
    reason: "優先順位が明確になり着手しやすくなります",
  });
  assertEquals(issues.includes("generic_action"), true);
  assertEquals(issues.includes("missing_prompt_anchor"), true);
});

Deno.test("landing trial quality gate accepts Japanese verbal noun actions", () => {
  assertEquals(
    landingTrialQualityIssues(
      "毎月の支出が増えていて、どこから見直すべきか分かりません",
      {
        action: "先月の支出で最も高い固定費を1件特定",
        reason: "支出の最大項目を先に特定すると見直し効果が明確になるため",
      },
    ),
    [],
  );
});

Deno.test("landing trial quality gate rejects an answer from another concern domain", () => {
  const issues = landingTrialQualityIssues(
    "毎月の支出が増えていて、どこから見直すべきか分かりません",
    {
      action: "今日締切の仕事を1件選ぶ",
      reason: "優先順位を明確にすることで、着手しやすくなるため",
    },
  );

  assertEquals(issues.includes("missing_prompt_anchor"), true);
});

Deno.test("landing trial quality gate ignores incidental phrase overlap across domains", () => {
  const issues = landingTrialQualityIssues(
    "毎月の支出が増えていて、どこから見直すべきか分かりません",
    {
      action: "今日締切の仕事を1件見直す",
      reason: "仕事の優先順位を明確にすると着手しやすくなるため",
    },
  );

  assertEquals(issues.includes("missing_prompt_anchor"), true);
});

Deno.test("landing trial quality gate accepts semantic matches within a concern domain", () => {
  assertEquals(
    landingTrialQualityIssues(
      "家計の出費が増えていて、どこから削減すべきか分かりません",
      {
        action: "先月の明細で最大の固定費を1件特定",
        reason: "固定費の最大項目を先に決めると削減効果が見えるため",
      },
    ),
    [],
  );
});

Deno.test("landing trial quality gate accepts a concrete monetization step", () => {
  assertEquals(
    landingTrialQualityIssues(
      "ChatGPTのサブスク代金をこのサイトからの収益でまかないたい",
      {
        action: "このサイトの有料商品を1件公開",
        reason:
          "収益源を1つ公開するとChatGPTの月額代を賄う検証を始められるため",
      },
    ),
    [],
  );
});

Deno.test("landing trial quality gate rejects generic monetization ideation", () => {
  const issues = landingTrialQualityIssues(
    "ChatGPTのサブスク代金をこのサイトからの収益でまかないたい",
    {
      action: "このサイトの収益化アイデアを1つ考える",
      reason: "収益化の具体案を1つ持つことで実行可能性が高まるため",
    },
  );

  assertEquals(issues.includes("generic_action"), true);
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
                  '{"action":"優先順位に迷う仕事を1件開き次の操作を書く","reason":"仕事と次の動作を固定すると迷いを止めて10分で着手できるため"}',
              },
            }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  assertEquals(suggestion.action, "優先順位に迷う仕事を1件開き次の操作を書く");
  assertEquals(requestBody.model, "gpt-4o-mini");
  assertEquals(requestBody.max_tokens, 180);
  const messages = requestBody.messages as Array<{ content: string }>;
  assertStringIncludes(messages[0].content, "untrusted data");
  assertStringIncludes(messages[0].content, "Never stop at idea generation");
  assertStringIncludes(messages[0].content, "サイト収益でAIの月額代");
  assertStringIncludes(messages[1].content, "仕事が多すぎて");
});

Deno.test("landing trial retries one generic response and returns repaired output", async () => {
  const requestBodies: Array<Record<string, unknown>> = [];
  const responses = [
    '{"action":"タスクをリスト化する","reason":"優先順位が明確になり着手しやすくなります"}',
    '{"action":"登録ボタン直前に無料の成果を1文追記","reason":"登録後の価値が見えない離脱要因を10分で減らせるため"}',
  ];
  const suggestion = await generateLandingTrialSuggestion({
    apiKey: "test-key",
    prompt: "LPからユーザー登録されない",
    fetchImpl: (_input, init) => {
      requestBodies.push(
        JSON.parse(String(init?.body)) as Record<string, unknown>,
      );
      const content = responses[requestBodies.length - 1];
      return Promise.resolve(
        new Response(
          JSON.stringify({ choices: [{ message: { content } }] }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });

  assertEquals(requestBodies.length, 2);
  assertEquals(suggestion, {
    action: "登録ボタン直前に無料の成果を1文追記",
    reason: "登録後の価値が見えない離脱要因を10分で減らせるため",
    qualityRetryUsed: true,
  });
  const repairMessages = requestBodies[1].messages as Array<{
    content: string;
  }>;
  assertStringIncludes(repairMessages[2].content, "generic_action");
});

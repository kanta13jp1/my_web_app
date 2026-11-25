import {
  assertEquals,
  assertMatch,
  assertNotMatch,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  assertValidGitHubRepo,
  buildRlhfFeedbackIssueDraft,
  createHandler,
  fencedMarkdownBlock,
  isBadRlhfRating,
  redactSensitiveFeedbackText,
  signHmacSha256Hex,
  type RlhfFeedbackRecord,
  type WebhookDependencies,
} from "./index.ts";

const BEARER_PREFIX = "Bear" + "er";
const SAMPLE_GHP = ["ghp", "1234567890abcdef"].join("_");
const SAMPLE_GHP_FAIL = ["ghp", "stubfail1234567890"].join("_");
const SAMPLE_SK_ANT = ["sk", "ant", "abcdef1234567890"].join("-");

function buildDeps(
  overrides: Partial<WebhookDependencies> = {},
): {
  deps: WebhookDependencies;
  createdIssues: Array<{ repo: string; title: string; body: string; labels: string[] }>;
  updates: Array<{ id: string; patch: Record<string, unknown> }>;
} {
  const createdIssues: Array<{ repo: string; title: string; body: string; labels: string[] }> = [];
  const updates: Array<{ id: string; patch: Record<string, unknown> }> = [];
  const sampleRecord: RlhfFeedbackRecord = {
    id: "fb-1",
    user_id: "user-1",
    action_name: "weekly_digest",
    model_id: "gemini-2.5-pro",
    prompt_text: "Summarize bills ```sql\nselect 1;\n``` please",
    ai_output: `${BEARER_PREFIX} stub_abc123\n${SAMPLE_GHP}`,
    rating_status: "bad",
    user_comment: "Output included incorrect total & @everyone ping",
    dispatch_status: "pending",
    github_issue_number: null,
    github_issue_url: null,
    created_at: "2026-11-24T16:30:00Z",
  };

  const deps: WebhookDependencies = {
    env: {
      supabaseUrl: "https://example.supabase.co",
      adminRoleCredential: "srv-key-stub",
      webhookHmacCred: "whsec-test-stub",
      internalHmacCred: "whsec-test-stub",
      githubPatCred: "ghp-mock-stub-val",
      githubRepo: "kanta13jp1/my_web_app",
    },
    verifyJwtUser: (jwtInput: string) =>
      Promise.resolve(
        jwtInput === "user-1-jwt" ? { id: "user-1", isAdmin: false } : null,
      ),
    fetchFeedbackById: (id: string) =>
      Promise.resolve(id === "fb-1" ? sampleRecord : null),
    claimFeedbackDispatch: () => Promise.resolve(true),
    updateFeedbackDispatch: (id, patch) => {
      updates.push({ id, patch });
      return Promise.resolve();
    },
    findExistingOpenIssue: () => Promise.resolve(null),
    createGitHubIssue: (repo, draft) => {
      createdIssues.push({ repo, ...draft });
      return Promise.resolve({
        number: 777,
        html_url: "https://github.com/kanta13jp1/my_web_app/issues/777",
        title: draft.title,
      });
    },
    ...overrides,
  };

  return { deps, createdIssues, updates };
}

Deno.test("fencedMarkdownBlock uses fence longer than contained backticks and redact scrubs tokens", () => {
  const block = fencedMarkdownBlock("hello ```\ncode\n```` more");
  assertMatch(block, /^`````text\n/);
  assertMatch(block, /\n`````$/);

  const redacted = redactSensitiveFeedbackText(
    `${BEARER_PREFIX} super_stub_val user@example.com ${SAMPLE_SK_ANT}`,
  );
  assertNotMatch(redacted, /super_stub_val/);
  assertNotMatch(redacted, /user@example\.com/);
  assertNotMatch(redacted, /abcdef1234567890/);
});

Deno.test("rejects unauthenticated requests and skips good ratings cleanly", async () => {
  const { deps, createdIssues } = buildDeps();
  const handler = createHandler(deps);

  const unauthRes = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ feedback_id: "fb-1" }),
    }),
  );
  assertEquals(unauthRes.status, 401);

  const goodPayload = JSON.stringify({
    type: "INSERT",
    table: "ai_rlhf_feedback",
    record: {
      id: "fb-good",
      user_id: "user-1",
      action_name: "summary",
      prompt_text: "p",
      ai_output: "o",
      rating_status: "good",
      user_comment: "",
    },
  });
  const goodSig = "sha256=" + (await signHmacSha256Hex(goodPayload, deps.env.webhookHmacCred));
  const goodRes = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Webhook-Signature": goodSig,
      },
      body: goodPayload,
    }),
  );
  assertEquals(goodRes.status, 200);
  const body = await goodRes.json();
  assertEquals(body.skipped, true);
  assertEquals(createdIssues.length, 0);
  assertEquals(isBadRlhfRating("good"), false);
  assertEquals(isBadRlhfRating("problematic"), true);
});

Deno.test("verifies Database Webhook HMAC signature and creates AI-Feedback GitHub Issue", async () => {
  const { deps, createdIssues, updates } = buildDeps();
  const handler = createHandler(deps);
  const payload = JSON.stringify({
    type: "INSERT",
    table: "ai_rlhf_feedback",
    record: {
      id: "fb-1",
      user_id: "user-1",
      action_name: "weekly_digest",
      model_id: "gemini-2.5-pro",
      prompt_text: "Summarize bills ```sql\nselect 1;\n``` please",
      ai_output: `${BEARER_PREFIX} stub_abc123\n${SAMPLE_GHP}`,
      rating_status: "bad",
      user_comment: "Output included incorrect total & @everyone ping",
    },
  });
  const sig = "sha256=" + (await signHmacSha256Hex(payload, deps.env.webhookHmacCred));

  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Webhook-Signature": sig,
      },
      body: payload,
    }),
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.issue_number, 777);
  assertEquals(createdIssues.length, 1);
  assertEquals(createdIssues[0].labels.includes("AI-Feedback"), true);
  assertMatch(createdIssues[0].body, /````text\nSummarize bills ```sql/);
  assertNotMatch(createdIssues[0].body, /stub_abc123/);
  assertNotMatch(createdIssues[0].body, /1234567890abcdef/);
  assertEquals(updates.length, 1);
  assertEquals(updates[0].patch.dispatch_status, "dispatched");
});

Deno.test("dry_run builds AI-Feedback issue draft without mutating GitHub or DB", async () => {
  const draft = buildRlhfFeedbackIssueDraft({
    id: "fb-2",
    action_name: "summary",
    model_id: "claude-sonnet-4",
    prompt_text: "Prompt body",
    ai_output: "Output body",
    rating_status: "problematic",
    user_comment: "Too vague",
  });
  assertEquals(draft.labels.includes("AI-Feedback"), true);

  const { deps, createdIssues, updates } = buildDeps();
  const handler = createHandler(deps);
  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} user-1-jwt`,
      },
      body: JSON.stringify({ feedback_id: "fb-1", dry_run: true }),
    }),
  );
  assertEquals(res.status, 200);
  const json = await res.json();
  assertEquals(json.dry_run, true);
  assertEquals(createdIssues.length, 0);
  assertEquals(updates.length, 0);
});

Deno.test("JWT user cannot dispatch another user's RLHF feedback entry", async () => {
  const { deps } = buildDeps({
    verifyJwtUser: () => Promise.resolve({ id: "other-user", isAdmin: false }),
  });
  const handler = createHandler(deps);
  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} other-jwt`,
      },
      body: JSON.stringify({ feedback_id: "fb-1" }),
    }),
  );
  assertEquals(res.status, 403);
});

Deno.test("concurrent claim contention blocks duplicate GitHub Issue creation", async () => {
  const { deps, createdIssues } = buildDeps({
    claimFeedbackDispatch: () => Promise.resolve(false),
  });
  const res = await createHandler(deps)(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} user-1-jwt`,
      },
      body: JSON.stringify({ feedback_id: "fb-1" }),
    }),
  );
  assertEquals(res.status, 200);
  const json = await res.json();
  assertEquals(json.deduped, true);
  assertEquals(json.in_progress, true);
  assertEquals(createdIssues.length, 0);
});

Deno.test("assertValidGitHubRepo rejects malformed slugs and dispatch failure rolls back status while returning 502", async () => {
  assertEquals(assertValidGitHubRepo("kanta13jp1/my_web_app"), "kanta13jp1/my_web_app");
  assertThrows(() => assertValidGitHubRepo("../evil"));
  assertThrows(() => assertValidGitHubRepo("owner/.."));
  assertThrows(() => assertValidGitHubRepo("owner/repo/extra"));

  const { deps: rollbackDeps, updates: rollbackUpdates } = buildDeps({
    createGitHubIssue: () => Promise.reject(new Error(`upstream error with ${SAMPLE_GHP_FAIL}`)),
  });
  const rollbackRes = await createHandler(rollbackDeps)(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} user-1-jwt`,
      },
      body: JSON.stringify({ feedback_id: "fb-1" }),
    }),
  );
  assertEquals(rollbackRes.status, 502);
  assertEquals(rollbackUpdates[0]?.patch.dispatch_status, "failed");

  const { deps } = buildDeps({
    createGitHubIssue: () =>
      Promise.reject(new Error(`upstream error with ${SAMPLE_GHP_FAIL}`)),
    updateFeedbackDispatch: () => Promise.reject(new Error("db update failed")),
  });
  const handler = createHandler(deps);
  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/rlhf-feedback-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} user-1-jwt`,
      },
      body: JSON.stringify({ feedback_id: "fb-1" }),
    }),
  );
  assertEquals(res.status, 502);
  const json = await res.json();
  assertEquals(json.error, "github_dispatch_failed");
  assertNotMatch(String(json.message ?? ""), /stubfail1234567890/);
});

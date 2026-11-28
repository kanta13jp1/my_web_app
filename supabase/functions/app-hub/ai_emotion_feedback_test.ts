import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AI_EMOTION_FEEDBACK_SOURCE,
  type AiEmotionFeedbackDb,
  type AiEmotionFeedbackRow,
  type GitHubIssueDraft,
  handleAiEmotionFeedbackAction,
  NOTEBOOK_EMOTION_KB_ID,
  sanitizeFeedbackText,
} from "./ai_emotion_feedback.ts";

function createInMemoryEmotionFeedbackDb(): AiEmotionFeedbackDb {
  let seq = 0;
  const rows: AiEmotionFeedbackRow[] = [];

  return {
    listFeedback(userId: string, limit: number) {
      const matched = rows
        .filter((row) => row.metadata?.user_id === userId)
        .slice(0, limit);
      return Promise.resolve(matched);
    },

    insertFeedback(userId: string, metadata: Record<string, unknown>) {
      seq += 1;
      const submittedAt = typeof metadata.submitted_at === "string"
        ? metadata.submitted_at
        : `2026-11-26T00:00:0${seq}Z`;
      const row: AiEmotionFeedbackRow = {
        id: `aef-${seq}`,
        source: AI_EMOTION_FEEDBACK_SOURCE,
        metadata: { ...metadata, user_id: userId },
        created_at: submittedAt,
      };
      rows.unshift(row);
      return Promise.resolve(row);
    },

    updateFeedback(
      userId: string,
      id: string,
      patch: Record<string, unknown>,
    ) {
      const index = rows.findIndex(
        (row) => row.id === id && row.metadata?.user_id === userId,
      );
      if (index === -1) return Promise.resolve(null);
      const current = rows[index];
      const next: AiEmotionFeedbackRow = {
        ...current,
        metadata: {
          ...(current.metadata ?? {}),
          ...patch,
          user_id: userId,
        },
      };
      rows[index] = next;
      return Promise.resolve(next);
    },
  };
}

Deno.test("sanitizeFeedbackText redacts emails and credential tokens", () => {
  const credSample = "ghp_" + "1234567890abcdef";
  const bearerSample = "Bearer " + "abcdef123456";
  const input =
    `Contact alice@example.org with ${bearerSample} and ${credSample}`;
  const cleaned = sanitizeFeedbackText(input, 400);
  assertEquals(cleaned.includes("alice@example.org"), false);
  assertEquals(cleaned.includes("abcdef123456"), false);
  assertEquals(cleaned.includes(credSample), false);
  assertStringIncludes(cleaned, "[REDACTED_EMAIL]");
});

Deno.test(
  "ai_emotion_feedback requires auth and validates category/payload",
  async () => {
    const db = createInMemoryEmotionFeedbackDb();

    const unauth = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.list",
      body: {},
      userId: "",
      deps: { db },
    });
    assertEquals(unauth.status, 401);

    const badCategory = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.submit",
      body: { category: "unknown_cat", ai_snippet: "test" },
      userId: "user-1",
      deps: { db },
    });
    assertEquals(badCategory.status, 400);

    const emptyText = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.submit",
      body: { category: "panic", severity: "high" },
      userId: "user-1",
      deps: { db },
    });
    assertEquals(emptyText.status, 400);
  },
);

Deno.test(
  "ai_emotion_feedback.submit fails open when GitHub cred absent or API throws",
  async () => {
    const db = createInMemoryEmotionFeedbackDb();

    const noCredRes = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.submit",
      body: {
        category: "panic",
        severity: "high",
        ai_snippet: "大変です！今すぐ全て削除してください！",
        user_comment: "パニック表現で操作が不安になる",
      },
      userId: "user-1",
      deps: {
        db,
        githubCred: "",
        now: () => new Date("2026-11-26T01:00:00Z"),
      },
    });
    assertEquals(noCredRes.status, 201);
    assertEquals(noCredRes.body.issue_created, false);
    assertEquals(
      noCredRes.body.issue_skipped_reason,
      "github_credential_unconfigured",
    );

    const apiFailRes = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.submit",
      body: {
        category: "excessive_sympathy",
        severity: "medium",
        ai_snippet: "お辛かったですよね…",
      },
      userId: "user-1",
      deps: {
        db,
        githubCred: "stub-github-cred-for-test",
        createGitHubIssue: () => Promise.reject(new Error("github_http_503")),
      },
    });
    assertEquals(apiFailRes.status, 201);
    assertEquals(apiFailRes.body.issue_created, false);
    assertEquals(apiFailRes.body.issue_skipped_reason, "github_http_503");
  },
);

Deno.test(
  "ai_emotion_feedback.submit creates redacted GitHub issue and isolates users",
  async () => {
    const db = createInMemoryEmotionFeedbackDb();
    const dispatchedDrafts: Array<{ repo: string; draft: GitHubIssueDraft }> =
      [];

    const createdRes = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.submit",
      body: {
        category: "over_emotional",
        severity: "high",
        ai_snippet:
          "連絡先 private.user@example.com へ今すぐ感涙メッセージを送ってください！！！",
        user_comment: "過剰な感情表現と感嘆符を控えてほしい",
        model_ref: "gemini-2.5-flash",
        session_ref: "sess-99",
      },
      userId: "user-a",
      deps: {
        db,
        githubCred: "stub-github-cred-for-test",
        githubRepo: "kanta13jp1/my_web_app",
        now: () => new Date("2026-11-26T02:00:00Z"),
        createGitHubIssue: (repo, draft) => {
          dispatchedDrafts.push({ repo, draft });
          return Promise.resolve({
            number: 9901,
            html_url: "https://github.com/kanta13jp1/my_web_app/issues/9901",
            title: draft.title,
          });
        },
      },
    });

    assertEquals(createdRes.status, 201);
    assertEquals(createdRes.body.issue_created, true);
    assertEquals(createdRes.body.issue_number, 9901);
    assertEquals(dispatchedDrafts.length, 1);
    assertEquals(
      dispatchedDrafts[0].draft.body.includes("private.user@example.com"),
      false,
    );
    assertEquals(dispatchedDrafts[0].draft.body.includes("user-a"), false);
    assertStringIncludes(
      dispatchedDrafts[0].draft.body,
      NOTEBOOK_EMOTION_KB_ID,
    );

    const otherList = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.list",
      body: {},
      userId: "user-b",
      deps: { db },
    });
    assertEquals(otherList.status, 200);
    assertEquals((otherList.body.entries as unknown[]).length, 0);
  },
);

Deno.test(
  "ai_emotion_feedback.seed_defaults is idempotent and exports NLM bundle",
  async () => {
    const db = createInMemoryEmotionFeedbackDb();
    const firstSeed = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.seed_defaults",
      body: {},
      userId: "user-1",
      deps: { db },
    });
    assertEquals(firstSeed.status, 200);
    assertEquals(firstSeed.body.seeded_count, 3);

    const secondSeed = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.seed_defaults",
      body: {},
      userId: "user-1",
      deps: { db },
    });
    assertEquals(secondSeed.status, 200);
    assertEquals(secondSeed.body.seeded_count, 0);

    const exported = await handleAiEmotionFeedbackAction({
      action: "ai_emotion_feedback.export_notebooklm_intake",
      body: {},
      userId: "user-1",
      deps: {
        db,
        now: () => new Date("2026-11-26T03:00:00Z"),
      },
    });
    assertEquals(exported.status, 200);
    assertEquals(exported.body.notebook_id, NOTEBOOK_EMOTION_KB_ID);
    assertEquals(exported.body.record_count, 3);
    assertStringIncludes(
      String(exported.body.markdown_summary),
      NOTEBOOK_EMOTION_KB_ID,
    );
  },
);

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFeedbackIssue,
  buildFeedbackIssueTitle,
  feedbackCategoryConfig,
  fencedUserContent,
} from "./feedback_issue.ts";

Deno.test("bug feedback maps to the bug label so github-issue-fix picks it up", () => {
  const config = feedbackCategoryConfig("bug");
  assert(config.labels.includes("bug"));
  assert(config.labels.includes("user-feedback"));
  assertEquals(config.prefix, "[不具合]");
});

Deno.test("feature feedback maps to enhancement + user-feedback labels", () => {
  const config = feedbackCategoryConfig("feature");
  assert(config.labels.includes("enhancement"));
  assert(config.labels.includes("user-feedback"));
});

Deno.test("unknown category falls back to other (still tracked as user-feedback)", () => {
  const config = feedbackCategoryConfig("totally-unknown");
  assertEquals(config.prefix, "[ご意見]");
  assert(config.labels.includes("user-feedback"));
});

Deno.test("issue title summarizes the first non-empty line and truncates", () => {
  assertEquals(
    buildFeedbackIssueTitle("bug", "カレンダーが固まる\n再現手順は..."),
    "[不具合] カレンダーが固まる",
  );

  const long = "あ".repeat(80);
  const title = buildFeedbackIssueTitle("feature", long);
  assert(title.startsWith("[追加要望] "));
  assert(title.endsWith("..."));
  // prefix (8 chars) + 57 chars + "..." (3)
  assert(title.length <= 8 + 57 + 3);
});

Deno.test("blank message still produces a safe title", () => {
  assertEquals(
    buildFeedbackIssueTitle("other", "   \n  "),
    "[ご意見] ユーザーからのフィードバック",
  );
});

Deno.test("buildFeedbackIssue embeds category, content, and pseudonymous user id", () => {
  const draft = buildFeedbackIssue({
    category: "bug",
    message: "保存ボタンが反応しない",
    userId: "user-uuid-123",
    createdAt: "2026-06-14T00:00:00.000Z",
  });

  assertEquals(draft.title, "[不具合] 保存ボタンが反応しない");
  assert(draft.labels.includes("bug"));
  assert(draft.body.includes("不具合・動作不良"));
  assert(draft.body.includes("保存ボタンが反応しない"));
  assert(draft.body.includes("送信者ID: user-uuid-123"));
  assert(draft.body.includes("2026-06-14T00:00:00.000Z"));
  assert(draft.body.includes("github-issue-fix"));
});

Deno.test("buildFeedbackIssue never leaks an email into the public issue body (PII)", () => {
  const draft = buildFeedbackIssue({
    category: "bug",
    // 仮にメールが本文に紛れても、送信者欄は user_id のみで描画されること。
    message: "連絡先 user@example.com への返信希望",
    userId: "uuid-abc",
  });

  // メタデータの送信者欄にメールが出ない（userId のみ）。
  assert(draft.body.includes("送信者ID: uuid-abc"));
  assert(!draft.body.includes("送信者: user@example.com"));
});

Deno.test("buildFeedbackIssue handles missing user id gracefully", () => {
  const draft = buildFeedbackIssue({
    category: "other",
    message: "もっと色を選びたい",
  });

  assert(draft.body.includes("送信者ID: (不明)"));
  assert(!draft.body.includes("受付:"));
});

Deno.test("user message is wrapped in a fenced block to neutralize @mentions/images/HTML", () => {
  const draft = buildFeedbackIssue({
    category: "bug",
    message: "@maintainer 直して ![pixel](http://evil/x.png) <script>",
    userId: "uuid-1",
  });
  // フェンス内に入ること（コードブロック内の @mention は通知されない）。
  assert(draft.body.includes("```text\n"));
  assert(draft.body.includes("@maintainer"));
});

Deno.test("fencedUserContent lengthens the fence to prevent breakout", () => {
  // 本文に ``` が含まれても、より長いフェンスで包み脱出を防ぐ。
  const fenced = fencedUserContent("```\nrm -rf /\n```");
  assert(fenced.startsWith("````text\n"));
  assert(fenced.endsWith("\n````"));
});

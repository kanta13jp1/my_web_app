import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  approveXPostCandidateMetadata,
  buildXPostCandidateMetadata,
  finalizeXPostCandidateMetadata,
  normalizeXPostCandidatePayload,
  rejectXPostCandidateMetadata,
} from "./x_post_candidate.ts";

const NOW = new Date("2026-07-12T10:00:00.000Z");
const APPROVED_AT = new Date("2026-07-12T11:00:00.000Z");

Deno.test("draft payload is publish-ready but strips untrusted controls", () => {
  const payload = normalizeXPostCandidatePayload({
    action: "x.draft.create",
    text: "朝の判断材料",
    replyTexts: ["詳細", "https://example.com"],
    poll: {
      options: ["政策", "経済", "AI", "教育", "ignored"],
      durationMinutes: 99999,
    },
    source: "x-daily-briefing-post.yml",
    route: "growth/daily-briefing",
    experimentKey: "x_first_user_growth_10k",
    variant: "daily_briefing_v2_numbers",
    promptProfile: "workflow_daily_briefing_v3_performance_context",
    contentKind: "daily_briefing_thread",
    linkInReply: true,
    dryRun: true,
    status: "posted",
    approvedBy: "attacker",
  });

  assertEquals(payload.action, "x.post");
  assertEquals(payload.replyTexts.length, 2);
  assertEquals(payload.poll, {
    options: ["政策", "経済", "AI", "教育"],
    durationMinutes: 10080,
  });
  assertEquals(payload.linkInReply, true);
  assertEquals("dryRun" in payload, false);
  assertEquals("status" in payload, false);
  assertEquals("approvedBy" in payload, false);
});

Deno.test("draft payload validates X long-post limits", () => {
  assertThrows(
    () => normalizeXPostCandidatePayload({ text: "" }),
    Error,
    "text required",
  );
  assertThrows(
    () => normalizeXPostCandidatePayload({ text: "x".repeat(25001) }),
    Error,
    "text exceeds 25000 characters",
  );
  assertThrows(
    () =>
      normalizeXPostCandidatePayload({
        text: "ok",
        replyTexts: ["x".repeat(25001)],
      }),
    Error,
    "replyTexts[0] exceeds 25000 characters",
  );
});

Deno.test("draft metadata starts pending and keeps review context", () => {
  const metadata = buildXPostCandidateMetadata(
    {
      text: "朝の判断材料",
      replyTexts: ["詳細"],
      source: "x-daily-briefing-post.yml",
      route: "growth/daily-briefing",
      variant: "daily_briefing_v2_numbers",
    },
    {
      candidateKey: "daily-briefing:2026-07-12",
      candidateType: "daily_briefing_thread",
      sourceKind: "trend_daily_briefing",
      sourceUrls: ["https://example.com/briefing"],
      createdBy: "github-actions:x-daily-briefing-post.yml",
      now: NOW,
      context: {
        workflow: "x-daily-briefing-post.yml",
        workflow_run_id: "1234",
        event: "schedule",
        actor: "github-actions[bot]",
        jst_day: "2026/7/12",
        topics: ["政策", "経済"],
        performance_rows: 18,
        secret: "must-not-be-stored",
      },
    },
  );

  assertEquals(metadata.status, "pending_approval");
  assertEquals(metadata.candidate_key, "daily-briefing:2026-07-12");
  assertEquals(metadata.candidate_type, "daily_briefing_thread");
  assertEquals(metadata.source_kind, "trend_daily_briefing");
  assertEquals(metadata.text, "朝の判断材料");
  assertEquals(metadata.reply_texts, ["詳細"]);
  assertEquals(metadata.variant, "daily_briefing_v2_numbers");
  assertEquals(metadata.content_archetype, null);
  assertEquals(metadata.source_urls, ["https://example.com/briefing"]);
  assertEquals(
    metadata.created_by,
    "github-actions:x-daily-briefing-post.yml",
  );
  assertEquals(metadata.approval_required, true);
  assertEquals(metadata.approved_at, null);
  assertEquals(metadata.idempotency_key, "daily-briefing:2026-07-12");
  assertEquals(metadata.generated_at, NOW.toISOString());
  assertEquals(
    metadata.generation_context,
    {
      workflow: "x-daily-briefing-post.yml",
      workflow_run_id: "1234",
      event: "schedule",
      actor: "github-actions[bot]",
      jst_day: "2026/7/12",
      topics: ["政策", "経済"],
      performance_rows: 18,
    },
  );
});

Deno.test("approval is audited and returns the exact whitelisted x.post payload", () => {
  const draft = buildXPostCandidateMetadata(
    { text: "reviewed", replyTexts: ["detail"], source: "workflow" },
    { now: NOW },
  );
  const approved = approveXPostCandidateMetadata(
    draft,
    {
      actorUserId: "service_role",
      approvedBy: "github:kanta13jp1",
      channel: "github_actions_workflow_dispatch",
      context: { workflow_run_id: "5678", event: "workflow_dispatch" },
    },
    APPROVED_AT,
  );

  assertEquals(approved.metadata.status, "approved");
  assertEquals(approved.metadata.approved_at, APPROVED_AT.toISOString());
  assertEquals(approved.metadata.approved_by, "github:kanta13jp1");
  assertEquals(approved.metadata.publish_attempts, 1);
  assertEquals(approved.postPayload, {
    action: "x.post",
    text: "reviewed",
    replyTexts: ["detail"],
    source: "workflow",
  });
});

Deno.test("posted draft captures the X result and cannot be approved twice", () => {
  const draft = buildXPostCandidateMetadata({ text: "reviewed" }, { now: NOW });
  const approved = approveXPostCandidateMetadata(
    draft,
    {
      actorUserId: "service_role",
      approvedBy: "github:reviewer",
      channel: "github_actions_workflow_dispatch",
    },
    APPROVED_AT,
  );
  const posted = finalizeXPostCandidateMetadata(
    approved.metadata,
    {
      success: true,
      posted: true,
      tweetId: "2076129162553889018",
      replyTweetIds: ["2076129162553889019"],
      log: { id: "4a7dc916-9fcc-43c3-a1d1-cee8f13c1f91" },
    },
    new Date("2026-07-12T11:01:00.000Z"),
  );

  assertEquals(posted.status, "posted");
  assertEquals(posted.tweet_id, "2076129162553889018");
  assertEquals(posted.reply_tweet_ids, ["2076129162553889019"]);
  assertEquals(posted.post_log_id, "4a7dc916-9fcc-43c3-a1d1-cee8f13c1f91");
  assertThrows(
    () =>
      approveXPostCandidateMetadata(posted, {
        actorUserId: "service_role",
        approvedBy: "github:reviewer",
        channel: "github_actions_workflow_dispatch",
      }),
    Error,
    "cannot be approved",
  );
});

Deno.test("duplicate rejection is retained as an auditable terminal status", () => {
  const draft = buildXPostCandidateMetadata({ text: "reviewed" }, { now: NOW });
  const approved = approveXPostCandidateMetadata(
    draft,
    {
      actorUserId: "admin-id",
      approvedBy: "admin-id",
      channel: "admin_ui",
    },
    APPROVED_AT,
  );
  const rejected = finalizeXPostCandidateMetadata(approved.metadata, {
    success: false,
    posted: false,
    code: "duplicate_content",
    error: "same content",
  });
  assertEquals(rejected.status, "rejected_duplicate");
  assertEquals(rejected.publish_code, "duplicate_content");
  assertEquals(rejected.publish_error, "same content");
});

const REJECTED_AT = new Date("2026-07-22T09:00:00.000Z");

Deno.test("rejection is audited and moves an actionable draft to the terminal state", () => {
  const draft = buildXPostCandidateMetadata({ text: "stale news" }, {
    now: NOW,
  });
  const rejected = rejectXPostCandidateMetadata(
    draft,
    {
      actorUserId: "operator-uuid",
      rejectedBy: "operator-uuid",
      reason: "freshness_expired",
    },
    REJECTED_AT,
  );

  assertEquals(rejected.changed, true);
  assertEquals(rejected.metadata.status, "rejected");
  assertEquals(rejected.metadata.rejected_at, REJECTED_AT.toISOString());
  assertEquals(rejected.metadata.rejected_by, "operator-uuid");
  assertEquals(rejected.metadata.reject_reason, "freshness_expired");
});

Deno.test("rejection does not count as a publish attempt", () => {
  const draft = buildXPostCandidateMetadata({ text: "retry me" }, { now: NOW });
  const approved = approveXPostCandidateMetadata(draft, {
    actorUserId: "operator-uuid",
    approvedBy: "operator-uuid",
    channel: "admin_ui",
  }, APPROVED_AT);
  assertEquals(approved.metadata.publish_attempts, 1);

  const rejected = rejectXPostCandidateMetadata(approved.metadata, {
    actorUserId: "operator-uuid",
    rejectedBy: "operator-uuid",
  }, REJECTED_AT);
  // 却下は投稿試行ではない: approve が積んだ回数をそのまま保つ。
  assertEquals(rejected.metadata.publish_attempts, 1);
});

Deno.test("approved and publish_failed drafts can still be rejected", () => {
  const draft = buildXPostCandidateMetadata({ text: "retry me" }, { now: NOW });
  const approved = approveXPostCandidateMetadata(draft, {
    actorUserId: "operator-uuid",
    approvedBy: "operator-uuid",
    channel: "admin_ui",
  }, APPROVED_AT);
  const failed = finalizeXPostCandidateMetadata(
    approved.metadata,
    { posted: false, error: "network", code: "transient" },
    APPROVED_AT,
  );
  assertEquals(failed.status, "publish_failed");

  for (const source of [approved.metadata, failed]) {
    const rejected = rejectXPostCandidateMetadata(source, {
      actorUserId: "operator-uuid",
      rejectedBy: "operator-uuid",
    }, REJECTED_AT);
    assertEquals(rejected.changed, true);
    assertEquals(rejected.metadata.status, "rejected");
    assertEquals(rejected.metadata.reject_reason, null);
  }
});

Deno.test("rejecting a terminal draft is an idempotent no-op that keeps the first audit", () => {
  const draft = buildXPostCandidateMetadata({ text: "stale" }, { now: NOW });
  const first = rejectXPostCandidateMetadata(draft, {
    actorUserId: "operator-uuid",
    rejectedBy: "operator-uuid",
    reason: "freshness_expired",
  }, REJECTED_AT);
  const second = rejectXPostCandidateMetadata(first.metadata, {
    actorUserId: "another-operator",
    rejectedBy: "another-operator",
    reason: "changed my mind",
  }, new Date("2026-07-23T09:00:00.000Z"));

  assertEquals(second.changed, false);
  assertEquals(second.metadata.rejected_at, REJECTED_AT.toISOString());
  assertEquals(second.metadata.rejected_by, "operator-uuid");
  assertEquals(second.metadata.reject_reason, "freshness_expired");
});

Deno.test("rejected_duplicate is already terminal and is not overwritten", () => {
  const draft = buildXPostCandidateMetadata({ text: "dupe" }, { now: NOW });
  const approved = approveXPostCandidateMetadata(draft, {
    actorUserId: "operator-uuid",
    approvedBy: "operator-uuid",
    channel: "admin_ui",
  }, APPROVED_AT);
  const duplicate = finalizeXPostCandidateMetadata(approved.metadata, {
    posted: false,
    code: "duplicate_content",
  }, APPROVED_AT);
  assertEquals(duplicate.status, "rejected_duplicate");

  const result = rejectXPostCandidateMetadata(duplicate, {
    actorUserId: "operator-uuid",
    rejectedBy: "operator-uuid",
  }, REJECTED_AT);
  assertEquals(result.changed, false);
  assertEquals(result.metadata.status, "rejected_duplicate");
});

Deno.test("a posted draft cannot be rejected", () => {
  const draft = buildXPostCandidateMetadata({ text: "already live" }, {
    now: NOW,
  });
  const approved = approveXPostCandidateMetadata(draft, {
    actorUserId: "operator-uuid",
    approvedBy: "operator-uuid",
    channel: "admin_ui",
  }, APPROVED_AT);
  const posted = finalizeXPostCandidateMetadata(approved.metadata, {
    posted: true,
    tweetId: "2076129162553889018",
  }, APPROVED_AT);
  assertEquals(posted.status, "posted");

  assertThrows(
    () =>
      rejectXPostCandidateMetadata(posted, {
        actorUserId: "operator-uuid",
        rejectedBy: "operator-uuid",
      }, REJECTED_AT),
    Error,
    "cannot be rejected",
  );
});

Deno.test("rejection requires actor and rejector", () => {
  const draft = buildXPostCandidateMetadata({ text: "x" }, { now: NOW });
  assertThrows(
    () =>
      rejectXPostCandidateMetadata(draft, {
        actorUserId: "",
        rejectedBy: "operator-uuid",
      }, REJECTED_AT),
    Error,
    "required",
  );
});

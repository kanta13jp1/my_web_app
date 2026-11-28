import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type DevReviewSession,
  type DevReviewStore,
  handleDevReviewAction,
  resolveAppHubAction,
  signGithubWebhookPayload,
  validatePhaseTransition,
  verifyGithubWebhookSignature,
} from "./dev_review_tracking.ts";

function createFakeStore() {
  const sessions: DevReviewSession[] = [];
  let seq = 0;

  const store: DevReviewStore = {
    listSessions(userId, limit) {
      return Promise.resolve(
        sessions.filter((s) => s.userId === userId).slice(0, limit),
      );
    },
    getSession(sessionId, userId) {
      const found = sessions.find(
        (s) => s.id === sessionId && s.userId === userId,
      );
      return Promise.resolve(found ?? null);
    },
    findSessionsByGithubTarget(repo, num) {
      return Promise.resolve(
        sessions.filter(
          (s) => s.githubRepo === repo && s.targetNumber === num,
        ),
      );
    },
    createSession(input) {
      seq += 1;
      const created: DevReviewSession = {
        id: `rev-${seq}`,
        userId: input.userId,
        title: input.title,
        targetType: input.targetType,
        githubRepo: input.githubRepo,
        targetNumber: input.targetNumber,
        currentPhase: input.currentPhase,
        approver: input.approver,
        items: input.items,
        githubSnapshot: input.githubSnapshot,
        phaseHistory: [],
        createdAt: "2026-11-25T12:00:00Z",
        updatedAt: "2026-11-25T12:00:00Z",
      };
      sessions.push(created);
      return Promise.resolve(created);
    },
    updateSession(sessionId, userId, next) {
      const idx = sessions.findIndex(
        (s) => s.id === sessionId && s.userId === userId,
      );
      if (idx < 0) return Promise.resolve(null);
      sessions[idx] = next;
      return Promise.resolve(next);
    },
  };

  return { store, sessions };
}

Deno.test(
  "auto-generates checklist + test variations and blocks phase until approved",
  async () => {
    const fake = createFakeStore();
    const createdRes = await handleDevReviewAction({
      action: "dev_review.session.create",
      body: {
        title: "Review PR #6355",
        target_type: "pr",
        github_repo: "kanta13jp1/my_web_app",
        target_number: 6355,
        approver: "tech-lead",
        assignee: "dev-a",
      },
      userId: "user-1",
      store: fake.store,
    });
    assertEquals(createdRes.status, 200);
    const session = createdRes.body.session as DevReviewSession;
    assertEquals(session.items.length, 6);

    const blockedRes = await handleDevReviewAction({
      action: "dev_review.phase.advance",
      body: { session_id: session.id, target_phase: "design" },
      userId: "user-1",
      store: fake.store,
    });
    assertEquals(blockedRes.status, 409);
    assertEquals(blockedRes.body.blocked, true);

    for (const item of session.items) {
      await handleDevReviewAction({
        action: "dev_review.item.update",
        body: {
          session_id: session.id,
          item_id: item.id,
          status: "approved",
          note: "Verified",
        },
        userId: "user-1",
        store: fake.store,
      });
    }

    const okRes = await handleDevReviewAction({
      action: "dev_review.phase.advance",
      body: {
        session_id: session.id,
        target_phase: "design",
        note: "All items approved",
      },
      userId: "user-1",
      store: fake.store,
    });
    assertEquals(okRes.status, 200);
    assertEquals(okRes.body.blocked, false);
    const advanced = okRes.body.session as DevReviewSession;
    assertEquals(advanced.currentPhase, "design");
    assertEquals(advanced.phaseHistory.length, 1);
  },
);

Deno.test(
  "verifies GitHub webhook HMAC-SHA256 fail-closed and updates sync snapshot",
  async () => {
    const fake = createFakeStore();
    await handleDevReviewAction({
      action: "dev_review.session.create",
      body: {
        title: "Track Issue #2743",
        target_type: "pr",
        github_repo: "kanta13jp1/my_web_app",
        target_number: 2743,
        approver: "lead",
      },
      userId: "user-1",
      store: fake.store,
    });

    const payload = JSON.stringify({
      repository: { full_name: "kanta13jp1/my_web_app" },
      pull_request: {
        number: 2743,
        state: "open",
        merged: false,
        html_url: "https://github.com/kanta13jp1/my_web_app/pull/2743",
      },
      review: { state: "changes_requested" },
    });

    const unconfigured = await handleDevReviewAction({
      action: "dev_review.github_webhook",
      body: JSON.parse(payload),
      rawBody: payload,
      signatureHeader: "sha256=" + "0".repeat(64),
      userId: "",
      store: fake.store,
      getEnv: () => "",
    });
    assertEquals(unconfigured.status, 503);

    const invalidSig = await handleDevReviewAction({
      action: "dev_review.github_webhook",
      body: JSON.parse(payload),
      rawBody: payload,
      signatureHeader: "sha256=" + "a".repeat(64),
      userId: "",
      store: fake.store,
      getEnv: () => "demo-wh",
    });
    assertEquals(invalidSig.status, 401);

    const validSig = await signGithubWebhookPayload(payload, "demo-wh");
    assertEquals(
      await verifyGithubWebhookSignature(payload, validSig, "demo-wh"),
      true,
    );

    const synced = await handleDevReviewAction({
      action: "dev_review.github_webhook",
      body: JSON.parse(payload),
      rawBody: payload,
      signatureHeader: validSig,
      userId: "",
      store: fake.store,
      getEnv: () => "demo-wh",
    });
    assertEquals(synced.status, 200);
    assertEquals(synced.body.matched_sessions, 1);

    const gateCheck = validatePhaseTransition(fake.sessions[0], "design");
    assertEquals(gateCheck.allowed, false);
    assertStringIncludes(
      gateCheck.blockingReasons.join(" | "),
      "changes_requested",
    );
  },
);

Deno.test(
  "webhook query param beats GitHub body.action ('submitted') on dispatch",
  async () => {
    const fake = createFakeStore();
    await handleDevReviewAction({
      action: "dev_review.session.create",
      body: {
        title: "Track PR #2743 submitted",
        target_type: "pr",
        github_repo: "kanta13jp1/my_web_app",
        target_number: 2743,
        approver: "lead",
      },
      userId: "user-1",
      store: fake.store,
    });

    const ghBody = {
      action: "submitted",
      repository: { full_name: "kanta13jp1/my_web_app" },
      pull_request: {
        number: 2743,
        state: "open",
        merged: false,
        html_url: "https://github.com/kanta13jp1/my_web_app/pull/2743",
      },
      review: { state: "approved" },
    };

    assertEquals(
      resolveAppHubAction(
        "https://example.test/functions/v1/app-hub" +
          "?action=dev_review.github_webhook",
        ghBody,
      ),
      "dev_review.github_webhook",
    );
    assertEquals(
      resolveAppHubAction("https://example.test/functions/v1/app-hub", {
        action: "dev_review.session.list",
      }),
      "dev_review.session.list",
    );

    const raw = JSON.stringify(ghBody);
    const sig = await signGithubWebhookPayload(raw, "demo-wh");
    const res = await handleDevReviewAction({
      action: resolveAppHubAction(
        "https://example.test/functions/v1/app-hub" +
          "?action=dev_review.github_webhook",
        ghBody,
      ),
      body: ghBody,
      rawBody: raw,
      signatureHeader: sig,
      userId: "",
      store: fake.store,
      getEnv: () => "demo-wh",
    });
    assertEquals(res.status, 200);
    assertEquals(res.body.matched_sessions, 1);
    assertEquals(fake.sessions[0].githubSnapshot?.reviewDecision, "approved");
  },
);

import {
  ACCESS_POLICY,
  authorizeRequest,
  createFixedWindowLimiter,
  createHandler,
  type DigestDependencies,
} from "./index.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const allowedOrigin = "https://my-web-app-b67f4.web.app";
const adminId = "79edc36b-b31d-4841-a0cb-64e75b98ab3a";
const fakeAdmin = {} as never;

function postRequest(token = "admin-token"): Request {
  return new Request("https://local.test/functions/v1/growth-weekly-digest", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      origin: allowedOrigin,
    },
    body: JSON.stringify({ endDate: "2026-08-29" }),
  });
}

function successDependencies(
  overrides: Partial<DigestDependencies> = {},
): DigestDependencies {
  const currentRows = [{
    source_details: {
      touch_landing: 20,
      signup_submit_landing: 1,
      touch_profile: 15,
      signup_submit_profile: 0,
      import_preview_notion: 4,
      import_signup_cta: 3,
      public_memo_signup_cta: 2,
    },
  }];
  const priorRows = [{
    source_details: {
      touch_landing: 12,
      signup_submit_landing: 0,
      touch_profile: 20,
      signup_submit_profile: 2,
      import_preview_notion: 1,
    },
  }];
  return {
    allowedOrigins: [allowedOrigin],
    authorize: () =>
      Promise.resolve({
        actorKey: adminId,
        decisionOwner: adminId,
        admin: fakeAdmin,
      }),
    fetchAnalyticsRows: (_admin, startDate) =>
      Promise.resolve(startDate === "2026-08-23" ? currentRows : priorRows),
    fetchReferralCount: (_admin, startDate) =>
      Promise.resolve(startDate === "2026-08-23" ? 3 : 1),
    allowRequest: () => true,
    now: () => new Date("2026-08-29T12:00:00.000Z"),
    ...overrides,
  };
}

Deno.test("service-role bearer is accepted without user lookup", async () => {
  let userLookupCalled = false;
  const result = await authorizeRequest(postRequest("service-secret"), {
    serviceRoleKey: "service-secret",
    admin: fakeAdmin,
    getUser: () => {
      userLookupCalled = true;
      return Promise.resolve(null);
    },
    getAdminProfile: () => Promise.resolve(null),
  });
  assertEquals("status" in result, false);
  if (!("status" in result)) {
    assertEquals(result.actorKey, "service_role");
    assertEquals(result.decisionOwner, "service_role");
  }
  assertEquals(userLookupCalled, false);
});

Deno.test("missing bearer is rejected without identity lookups", async () => {
  let lookupCalled = false;
  const result = await authorizeRequest(
    new Request("https://local.test", { method: "POST" }),
    {
      serviceRoleKey: "service-secret",
      admin: fakeAdmin,
      getUser: () => {
        lookupCalled = true;
        return Promise.resolve(null);
      },
      getAdminProfile: () => {
        lookupCalled = true;
        return Promise.resolve(null);
      },
    },
  );
  assertEquals(result, { status: 401, error: "unauthorized" });
  assertEquals(lookupCalled, false);
});

Deno.test("authenticated non-admin is denied before privileged queries", async () => {
  let queryCalled = false;
  const handler = createHandler(successDependencies({
    authorize: async (request) =>
      await authorizeRequest(request, {
        serviceRoleKey: "service-secret",
        admin: fakeAdmin,
        getUser: () => Promise.resolve({ id: adminId }),
        getAdminProfile: () =>
          Promise.resolve({ is_admin: false, role: "user" }),
      }),
    fetchAnalyticsRows: () => {
      queryCalled = true;
      return Promise.resolve([]);
    },
  }));
  const response = await handler(postRequest());
  assertEquals(response.status, 403);
  assertEquals((await response.json()).error, "admin_required");
  assertEquals(queryCalled, false);
});

Deno.test("authorization dependency errors fail closed", async () => {
  const result = await authorizeRequest(postRequest(), {
    serviceRoleKey: "service-secret",
    admin: fakeAdmin,
    getUser: () => Promise.resolve({ id: adminId }),
    getAdminProfile: () => Promise.reject(new Error("database unavailable")),
  });
  assertEquals(result, { status: 503, error: "service_unavailable" });
});

Deno.test("GET and unapproved browser origins are rejected", async () => {
  let authorizeCalled = false;
  const handler = createHandler(successDependencies({
    authorize: () => {
      authorizeCalled = true;
      return Promise.resolve({
        actorKey: adminId,
        decisionOwner: adminId,
        admin: fakeAdmin,
      });
    },
  }));
  const getResponse = await handler(
    new Request("https://local.test", {
      method: "GET",
      headers: { origin: allowedOrigin },
    }),
  );
  assertEquals(getResponse.status, 405);
  assertEquals(authorizeCalled, false);

  const originResponse = await handler(
    new Request("https://local.test", {
      method: "OPTIONS",
      headers: { origin: "https://attacker.example" },
    }),
  );
  assertEquals(originResponse.status, 403);
  assertEquals(originResponse.headers.get("access-control-allow-origin"), null);
});

Deno.test("successful response exposes only aggregate digest contract", async () => {
  const response = await createHandler(successDependencies())(postRequest());
  assertEquals(response.status, 200);
  assertEquals(
    response.headers.get("access-control-allow-origin"),
    allowedOrigin,
  );
  const payload = await response.json();
  assertEquals(payload.success, true);
  assertEquals(payload.accessPolicy, ACCESS_POLICY);
  assertEquals(payload.digest.currentWeek, {
    startDate: "2026-08-23",
    endDate: "2026-08-29",
  });
  assertEquals(payload.digest.signupSubmitTotal, 1);
  assertEquals(payload.digest.signupSubmitDelta, -1);
  assertEquals(payload.digest.referralsCompleted, 3);
  assertEquals(payload.digest.channels[0].cvr, 5);
  assertEquals(payload.digest.decision.owner, adminId);
  assertEquals(
    payload.digest.decision.id,
    "growth-weekly:2026-08-29:profile:cvr-5",
  );
  assertEquals(payload.digest.decision.priorityChannel.id, "profile");
  assertEquals(payload.digest.decision.threshold, {
    metric: "cvr_percent",
    operator: ">=",
    target: 5,
    minimumTouches: 10,
  });
  assertEquals(payload.digest.decision.dueDate, "2026-09-05");
  assertEquals(payload.digest.decision.outcome.status, "pending");
  assertEquals(
    payload.digest.previousDecisionOutcome.priorityChannel.id,
    "landing",
  );
  assertEquals(
    payload.digest.previousDecisionOutcome.decisionId,
    "growth-weekly:2026-08-22:landing:cvr-5",
  );
  assertEquals(payload.digest.previousDecisionOutcome.owner, adminId);
  assertEquals(payload.digest.previousDecisionOutcome.dueDate, "2026-08-29");
  assertEquals(payload.digest.previousDecisionOutcome.status, "met");
  assert(
    !JSON.stringify(payload).includes("source_details"),
    "raw analytics rows must not be returned",
  );
});

Deno.test("per-actor fixed-window limit returns 429", async () => {
  const limiter = createFixedWindowLimiter(1, 60_000);
  const handler = createHandler(successDependencies({ allowRequest: limiter }));
  const first = await handler(postRequest());
  const second = await handler(postRequest());
  assertEquals(first.status, 200);
  assertEquals(second.status, 429);
  assertEquals(second.headers.get("retry-after"), "60");
});

Deno.test("invalid date is rejected before aggregate queries", async () => {
  let queryCalled = false;
  const handler = createHandler(successDependencies({
    fetchAnalyticsRows: () => {
      queryCalled = true;
      return Promise.resolve([]);
    },
  }));
  const response = await handler(
    new Request("https://local.test", {
      method: "POST",
      headers: {
        authorization: "Bearer admin-token",
        "content-type": "application/json",
        origin: allowedOrigin,
      },
      body: JSON.stringify({ endDate: "2026-02-30" }),
    }),
  );
  assertEquals(response.status, 422);
  assertEquals(queryCalled, false);
});

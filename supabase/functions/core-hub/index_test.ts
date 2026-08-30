import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { CORE_HUB_ACTION_REGISTRY } from "./action_registry.ts";
import { handleCoreHubRequest } from "./index.ts";

function post(action: string): Request {
  return new Request("https://example.test/functions/v1/core-hub", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action, memo_id: 42, reaction: "👍" }),
  });
}

function serviceRolePost(
  action: string,
  body: Record<string, unknown>,
): Request {
  return new Request("https://example.test/functions/v1/core-hub", {
    method: "POST",
    headers: {
      authorization: "Bearer expected-service-role-key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ action, ...body }),
  });
}

for (const action of ["memo.react.list", "memo.react.toggle"]) {
  Deno.test(`${action} reaches the route without authentication`, async () => {
    let authenticateCalled = false;
    const response = await handleCoreHubRequest(post(action), {
      createAdminClient: () => ({}) as never,
      authenticateUser: () => {
        authenticateCalled = true;
        return Promise.resolve(null);
      },
      handleMemoReaction: (input) =>
        Promise.resolve({
          status: 200,
          payload: { routedAction: input.action },
        }),
      reportError: () => {},
    });

    assertEquals(response.status, 200);
    assertEquals(await response.json(), { routedAction: action });
    assertFalse(authenticateCalled);
  });
}

Deno.test("unknown actions return 400 before authentication", async () => {
  let authenticateCalled = false;
  const response = await handleCoreHubRequest(post("memo.react.unknown"), {
    createAdminClient: () => {
      throw new Error("admin client must not be created");
    },
    authenticateUser: () => {
      authenticateCalled = true;
      return Promise.resolve(null);
    },
    reportError: () => {},
  });

  assertEquals(response.status, 400);
  assertEquals(await response.json(), {
    error: "Unknown action: memo.react.unknown",
  });
  assertFalse(authenticateCalled);
});

Deno.test("unexpected route exceptions are sanitized", async () => {
  let reportedError: unknown;
  const response = await handleCoreHubRequest(post("memo.react.list"), {
    createAdminClient: () => ({}) as never,
    handleMemoReaction: () => {
      throw new Error("database password leaked in backend message");
    },
    reportError: (error) => {
      reportedError = error;
    },
  });

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "Internal server error" });
  assertEquals(reportedError instanceof Error, true);
});

Deno.test("returned backend errors are sanitized", async () => {
  const response = await handleCoreHubRequest(post("memo.react.toggle"), {
    createAdminClient: () => ({}) as never,
    handleMemoReaction: () =>
      Promise.resolve({
        status: 500,
        payload: { error: "database password leaked in backend message" },
      }),
    reportError: () => {},
  });

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "Internal server error" });
});

Deno.test("user actions still require an authenticated user", async () => {
  const response = await handleCoreHubRequest(post("memo.share"), {
    authenticateUser: () => Promise.resolve(null),
    reportError: () => {},
  });
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "Unauthorized" });
});

Deno.test("service-role actions reject an anonymous bearer", async () => {
  const response = await handleCoreHubRequest(post("slack.notify"), {
    serviceRoleKey: "expected-service-role-key",
    reportError: () => {},
  });
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "Unauthorized" });
});

for (
  const [action, body] of [
    [
      "design.audit.upsert",
      { route: "/example", compliance: Array(7).fill(true) },
    ],
    [
      "design.rollout.upsert",
      {
        route: "/example",
        stage: "applied",
        figma_mcp: "applied",
        ai_designer: "applied",
        design_skills: "applied",
        design_md: "applied",
      },
    ],
  ] as const
) {
  Deno.test(`${action} accepts the registered service role`, async () => {
    const response = await handleCoreHubRequest(serviceRolePost(action, body), {
      createAdminClient: () =>
        ({
          from: () => ({
            upsert: () => Promise.resolve({ error: null }),
          }),
        }) as never,
      serviceRoleKey: "expected-service-role-key",
      reportError: () => {},
    });

    assertEquals(response.status, 200);
    assertEquals(await response.json(), { success: true });
  });
}

Deno.test("all protected actions enforce their registered auth policy", async (t) => {
  for (
    const [action, definition] of Object.entries(
      CORE_HUB_ACTION_REGISTRY,
    )
  ) {
    if (definition.auth === "anonymous") continue;

    await t.step(`${action} requires ${definition.auth}`, async () => {
      let authenticateCalled = false;
      const response = await handleCoreHubRequest(post(action), {
        createAdminClient: () => {
          throw new Error("admin client must not be created");
        },
        authenticateUser: () => {
          authenticateCalled = true;
          return Promise.resolve(null);
        },
        serviceRoleKey: "expected-service-role-key",
        reportError: () => {},
      });

      assertEquals(response.status, 401);
      assertEquals(await response.json(), { error: "Unauthorized" });
      assertEquals(authenticateCalled, definition.auth === "user");
    });
  }
});

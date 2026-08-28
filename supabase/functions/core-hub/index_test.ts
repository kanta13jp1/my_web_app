import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleCoreHubRequest } from "./index.ts";

function post(action: string): Request {
  return new Request("https://example.test/functions/v1/core-hub", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action, memo_id: 42, reaction: "👍" }),
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

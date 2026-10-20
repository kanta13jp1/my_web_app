import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { authorizeAutomationActor } from "./automation-auth.ts";

function invalidUserRequest(): Request {
  let token = "automation-auth-invalid-fixture";
  while (token === Deno.env.get("SERVICE_ROLE_KEY")) token += "-invalid";
  return new Request("https://fixture.invalid/", {
    headers: { authorization: `Bearer ${token}` },
  });
}

Deno.test("automation authorization rejects missing token before auth lookup", async () => {
  let calls = 0;
  const admin = {
    auth: {
      getUser: () => {
        calls += 1;
        throw new Error("unexpected lookup");
      },
    },
  };
  await assertRejects(
    () => authorizeAutomationActor(admin, new Request("https://fixture.invalid/")),
    Error,
    "Authorization token is required.",
  );
  assertEquals(calls, 0);
});

Deno.test("automation authorization rejects invalid token despite forged admin claims", async () => {
  let calls = 0;
  const admin = {
    auth: {
      getUser: () => {
        calls += 1;
        return Promise.resolve({
          data: { user: null },
          error: new Error("fixture invalid token"),
        });
      },
    },
  };
  const request = invalidUserRequest();
  const forged = new Request(request, {
    method: "POST",
    headers: {
      authorization: request.headers.get("authorization")!,
      "content-type": "application/json",
    },
    body: JSON.stringify({ role: "admin", email: "admin@example.invalid" }),
  });
  await assertRejects(
    () => authorizeAutomationActor(admin, forged),
    Error,
    "fixture invalid token",
  );
  assertEquals(calls, 1);
});

Deno.test("automation authorization rejects absent user after successful auth response", async () => {
  const admin = {
    auth: {
      getUser: () =>
        Promise.resolve({ data: { user: null }, error: null }),
    },
  };
  await assertRejects(
    () => authorizeAutomationActor(admin, invalidUserRequest()),
    Error,
    "Authenticated user not found.",
  );
});

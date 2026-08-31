import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  aiHubActionAccess,
  authorizeAiHubAction,
  resolveAuthenticatedUserId,
  SERVICE_ROLE_AI_HUB_ACTIONS,
} from "./action_access_policy.ts";

Deno.test(
  "AI Hub action policy covers public, authenticated, and service-role categories",
  () => {
    const cases = [
      { action: "home.popular", access: "public" },
      { action: "home.recommend", access: "authenticated" },
      { action: "observability.sessions", access: "service_role" },
    ] as const;

    for (const testCase of cases) {
      assertEquals(aiHubActionAccess(testCase.action), testCase.access);
    }
  },
);

Deno.test(
  "all observability actions reject anonymous and regular users but allow service role",
  () => {
    for (const action of SERVICE_ROLE_AI_HUB_ACTIONS) {
      assertEquals(
        authorizeAiHubAction(action, { userId: null, isServiceRole: false }),
        { allowed: false, status: 401, error: "Unauthorized" },
      );
      assertEquals(
        authorizeAiHubAction(action, {
          userId: "regular-user",
          isServiceRole: false,
        }),
        { allowed: false, status: 403, error: "Forbidden" },
      );
      assertEquals(
        authorizeAiHubAction(action, { userId: null, isServiceRole: true }),
        { allowed: true },
      );
    }
  },
);

Deno.test("home recommendation is bound to the authenticated user", () => {
  assertEquals(resolveAuthenticatedUserId("user-a", undefined), {
    userId: "user-a",
  });
  assertEquals(resolveAuthenticatedUserId("user-a", "user-a"), {
    userId: "user-a",
  });
  assertEquals(resolveAuthenticatedUserId("user-a", "user-b"), {
    status: 403,
    error: "Forbidden",
  });
});

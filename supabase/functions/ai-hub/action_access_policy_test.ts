import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  aiHubActionAccess,
  AUTHENTICATED_AI_HUB_ACTIONS,
  authorizeAiHubAction,
  PUBLIC_AI_HUB_ACTIONS,
  resolveAuthenticatedUserId,
  SERVICE_ROLE_AI_HUB_ACTIONS,
} from "./action_access_policy.ts";

Deno.test("aiHubActionAccess classifies registered actions correctly", () => {
  assertEquals(aiHubActionAccess("judgment.get"), "public");
  assertEquals(aiHubActionAccess("search.query"), "authenticated");
  assertEquals(aiHubActionAccess("corporate_site.readiness"), "authenticated");
  assertEquals(aiHubActionAccess("observability.heatmap"), "service_role");
  assertEquals(aiHubActionAccess("unknown.random.action"), null);
});

Deno.test("authorizeAiHubAction fails closed on unregistered actions", () => {
  const decision = authorizeAiHubAction("unknown.action", {
    userId: "user-1",
    isServiceRole: false,
  });
  assertEquals(decision, {
    allowed: false,
    status: 400,
    error: "UnknownAction",
  });
});

Deno.test("authorizeAiHubAction allows public actions for anonymous users", () => {
  const decision = authorizeAiHubAction("judgment.get", {
    userId: null,
    isServiceRole: false,
  });
  assertEquals(decision, { allowed: true });
});

Deno.test("authorizeAiHubAction requires auth for authenticated actions", () => {
  const anonDecision = authorizeAiHubAction("search.query", {
    userId: null,
    isServiceRole: false,
  });
  assertEquals(anonDecision, {
    allowed: false,
    status: 401,
    error: "Unauthorized",
  });

  const authDecision = authorizeAiHubAction("search.query", {
    userId: "user-123",
    isServiceRole: false,
  });
  assertEquals(authDecision, { allowed: true });
});

Deno.test("authorizeAiHubAction protects service-role actions", () => {
  const userDecision = authorizeAiHubAction("observability.heatmap", {
    userId: "user-123",
    isServiceRole: false,
  });
  assertEquals(userDecision, {
    allowed: false,
    status: 403,
    error: "Forbidden",
  });

  const serviceRoleDecision = authorizeAiHubAction("observability.heatmap", {
    userId: null,
    isServiceRole: true,
  });
  assertEquals(serviceRoleDecision, { allowed: true });
});

Deno.test("resolveAuthenticatedUserId checks matching user id", () => {
  const matched = resolveAuthenticatedUserId("user-1", "user-1");
  assertEquals(matched, { userId: "user-1" });

  const mismatched = resolveAuthenticatedUserId("user-1", "user-2");
  assertEquals(mismatched, { status: 403, error: "Forbidden" });

  const emptyRequested = resolveAuthenticatedUserId("user-1", "");
  assertEquals(emptyRequested, { userId: "user-1" });
});

Deno.test("disjointness of action registry sets", () => {
  const pub = [...PUBLIC_AI_HUB_ACTIONS];
  const auth = [...AUTHENTICATED_AI_HUB_ACTIONS];
  const srv = [...SERVICE_ROLE_AI_HUB_ACTIONS];

  for (const a of pub) {
    assertEquals(
      AUTHENTICATED_AI_HUB_ACTIONS.has(a),
      false,
      `${a} is in both public and authenticated`,
    );
    assertEquals(
      SERVICE_ROLE_AI_HUB_ACTIONS.has(a),
      false,
      `${a} is in both public and service_role`,
    );
  }
  for (const a of auth) {
    assertEquals(
      SERVICE_ROLE_AI_HUB_ACTIONS.has(a),
      false,
      `${a} is in both authenticated and service_role`,
    );
  }
  for (const a of srv) {
    assertEquals(
      PUBLIC_AI_HUB_ACTIONS.has(a),
      false,
      `${a} is in both service_role and public`,
    );
    assertEquals(
      AUTHENTICATED_AI_HUB_ACTIONS.has(a),
      false,
      `${a} is in both service_role and authenticated`,
    );
  }
});

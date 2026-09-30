import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { previewAgentToolPolicy } from "./agent_tool_policy_preview.ts";
import { authorizeAiHubAction } from "./action_access_policy.ts";

Deno.test("preview shows read result without granting execution", () => {
  const result = previewAgentToolPolicy({actor_role: "cfo", requested_scopes: ["read"]});
  assertEquals(result.allowed, true);
  assertEquals(result.simulation_only, true);
  assertEquals(result.audit_logged, false);
});

Deno.test("preview rejects unknown input and cannot accept invented approval", () => {
  assertEquals(previewAgentToolPolicy({requested_scopes: ["read", 42]}).blocked_reason, "invalid_requested_scope");
  const result = previewAgentToolPolicy({actor_role: "ceo", requested_scopes: ["send"], approval: {decision: "approved", approvedBy: "ceo", approvedAt: "now"}});
  assertEquals(result.allowed, false);
  assertEquals(result.blocked_reason, "approval_required");
  assertEquals(result.audit_logged, false);
});

Deno.test("preview remains authenticated and recovers with a corrected input", () => {
  assertEquals(authorizeAiHubAction("agent.tool_policy.preview", {userId: null, isServiceRole: false}).allowed, false);
  assertEquals(authorizeAiHubAction("agent.tool_policy.preview", {userId: "fixture", isServiceRole: false}).allowed, true);
  assertEquals(previewAgentToolPolicy({requested_scopes: []}).blocked_reason, "empty_requested_scope");
  assertEquals(previewAgentToolPolicy({requested_scopes: ["read"]}).allowed, true);
});

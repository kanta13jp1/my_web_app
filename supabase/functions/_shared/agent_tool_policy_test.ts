import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateAgentToolPolicy,
  evaluateGeneratedUiSandboxToolPolicy,
  GENERATED_UI_SANDBOX_ACTOR_ROLE,
  getDefaultAgentRoleScopes,
  normalizeAgentToolScopes,
  requiresCeoApproval,
} from "./agent_tool_policy.ts";

Deno.test("normalizeAgentToolScopes keeps only known scopes and deduplicates", () => {
  assertEquals(
    normalizeAgentToolScopes([" READ ", "send", "send", "unknown"]),
    ["read", "send"],
  );
});

Deno.test("default agent role scopes keep CFO away from high risk execution", () => {
  assertEquals(getDefaultAgentRoleScopes("cfo"), [
    "read",
    "suggest",
    "create",
    "update",
  ]);
});

Deno.test("generated UI sandbox defaults to read-only capability", () => {
  assertEquals(getDefaultAgentRoleScopes(GENERATED_UI_SANDBOX_ACTOR_ROLE), [
    "read",
  ]);
});

Deno.test("low risk allowed scope passes without approval", () => {
  const decision = evaluateAgentToolPolicy({
    actorRole: "cfo",
    toolName: "finance.report",
    requestedScopes: ["read", "suggest"],
  });

  assertEquals(decision.allowed, true);
  assertEquals(decision.requiresApproval, false);
  assertEquals(decision.blockedReason, null);
});

Deno.test("missing scope fails closed before external tool execution", () => {
  const decision = evaluateAgentToolPolicy({
    actorRole: "cho",
    toolName: "billing.refund",
    requestedScopes: ["read", "update"],
  });

  assertEquals(decision.allowed, false);
  assertEquals(decision.blockedReason, "missing_scope");
  assertEquals(decision.missingScopes, ["update"]);
});

Deno.test("high risk scopes require explicit CEO approval metadata", () => {
  assertEquals(requiresCeoApproval(["send"]), true);

  const decision = evaluateAgentToolPolicy({
    actorRole: "cmo",
    toolName: "x.post",
    requestedScopes: ["create", "external_share"],
  });

  assertEquals(decision.allowed, false);
  assertEquals(decision.requiresApproval, true);
  assertEquals(decision.highRiskScopes, ["external_share"]);
  assertEquals(decision.blockedReason, "approval_required");
});

Deno.test("discount scope is high risk and waits for explicit approval", () => {
  assertEquals(requiresCeoApproval(["discount"]), true);

  const decision = evaluateAgentToolPolicy({
    actorRole: "cfo",
    toolName: "discount.apply",
    requestedScopes: ["create", "discount"],
    allowedScopes: ["read", "suggest", "create", "discount"],
  });

  assertEquals(decision.allowed, false);
  assertEquals(decision.requiresApproval, true);
  assertEquals(decision.highRiskScopes, ["discount"]);
  assertEquals(decision.blockedReason, "approval_required");
});

Deno.test("approved high risk execution is allowed and audit-ready", () => {
  const decision = evaluateAgentToolPolicy({
    actorRole: "cmo",
    toolName: "x.post",
    requestedScopes: ["create", "external_share"],
    approval: {
      decision: "approved",
      approvedBy: "ceo",
      approvedAt: "2026-04-30T09:00:00Z",
    },
  });

  assertEquals(decision.allowed, true);
  assertEquals(decision.blockedReason, null);
  assertEquals(decision.auditPayload.blocked_reason, null);
  assertEquals(decision.auditPayload.approved_by, "ceo");
});

Deno.test("generated UI sandbox allows only read requests", () => {
  const allowed = evaluateGeneratedUiSandboxToolPolicy({
    toolName: "generated-ui.preview",
    requestedScopes: ["read"],
  });

  assertEquals(allowed.allowed, true);
  assertEquals(allowed.blockedReason, null);
  assertEquals(
    allowed.auditPayload.actor_role,
    GENERATED_UI_SANDBOX_ACTOR_ROLE,
  );

  const blocked = evaluateGeneratedUiSandboxToolPolicy({
    toolName: "generated-ui.preview",
    requestedScopes: ["read", "suggest"],
  });

  assertEquals(blocked.allowed, false);
  assertEquals(blocked.blockedReason, "missing_scope");
  assertEquals(blocked.missingScopes, ["suggest"]);
});

Deno.test("generated UI sandbox cannot be widened by approval metadata", () => {
  const decision = evaluateGeneratedUiSandboxToolPolicy({
    toolName: "generated-ui.preview",
    requestedScopes: ["send", "external_share"],
    approval: {
      decision: "approved",
      approvedBy: "ceo",
      approvedAt: "2026-07-07T00:00:00Z",
    },
  });

  assertEquals(decision.allowed, false);
  assertEquals(decision.requiresApproval, true);
  assertEquals(decision.blockedReason, "missing_scope");
  assertEquals(decision.missingScopes, ["send", "external_share"]);
  assertEquals(decision.highRiskScopes, ["send", "external_share"]);
});

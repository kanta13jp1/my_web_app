import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateAgentToolPolicy,
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

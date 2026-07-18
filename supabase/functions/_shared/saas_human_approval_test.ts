import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildSaasApprovalStatus,
  externalSaasGateReason,
  isPendingSaasApprovalStatus,
  normalizeSaasApprovalDecision,
  normalizeSaasConnectorSettings,
} from "./saas_human_approval.ts";

Deno.test("AI external write scopes are queued for approval", () => {
  assertEquals(
    externalSaasGateReason({
      connectorEnabled: true,
      actorType: "ai",
      requestedScopes: ["send", "external_share"],
    }),
    "approval_required",
  );
});

Deno.test("disabled connector blocks execution before approval", () => {
  assertEquals(
    externalSaasGateReason({
      connectorEnabled: false,
      humanApprovalRequired: true,
      requestedScopes: ["send"],
    }),
    "connector_disabled",
  );
});

Deno.test("connector settings default to Slack enabled only", () => {
  assertEquals(normalizeSaasConnectorSettings({ discord: true }), {
    slack: true,
    discord: true,
    notion: false,
    asana: false,
    gmail: false,
  });
});

Deno.test("decision aliases normalize to stored statuses", () => {
  assertEquals(normalizeSaasApprovalDecision("revise"), "revision_requested");
  assertEquals(
    buildSaasApprovalStatus("revision_requested"),
    "revision_requested",
  );
  assertEquals(normalizeSaasApprovalDecision("unknown"), null);
});

Deno.test("only pending or legacy blank approvals can be decided", () => {
  assertEquals(isPendingSaasApprovalStatus("pending"), true);
  assertEquals(isPendingSaasApprovalStatus(""), true);
  assertEquals(isPendingSaasApprovalStatus("approved"), false);
  assertEquals(isPendingSaasApprovalStatus("rejected"), false);
  assertEquals(isPendingSaasApprovalStatus("revision_requested"), false);
});

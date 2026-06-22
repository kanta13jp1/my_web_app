import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyApprovalStepDecision,
  buildMultiStepApprovalWorkflow,
} from "./multi_step_approval_workflow.ts";

Deno.test("multi-step approval is not required for a small discount", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "discount_apply",
    amountJpy: 1000,
    discountPct: 5,
    requestedByRole: "agent",
    requestedAt: "2026-06-09T00:00:00Z",
  });

  assertEquals(workflow.required, false);
  assertEquals(workflow.status, "not_required");
  assertEquals(workflow.transactionStatus, "approval_not_required");
  assertEquals(workflow.steps, []);
  assertEquals(workflow.notificationEvent, null);
});

Deno.test("multi-step approval holds large discounts for manager and finance", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "discount_apply",
    amountJpy: 8000,
    discountPct: 25,
    requestedByRole: "agent",
    requestedAt: "2026-06-09T00:00:00Z",
  });

  assertEquals(workflow.required, true);
  assertEquals(workflow.status, "pending");
  assertEquals(workflow.transactionStatus, "held_for_approval");
  assertEquals(workflow.currentStepId, "manager_review");
  assertEquals(workflow.steps.map((step) => step.id), [
    "manager_review",
    "finance_review",
  ]);
  assertEquals(workflow.notificationEvent?.channel, "admin_approval_requests");
  assertEquals(workflow.notificationEvent?.severity, "high");
});

Deno.test("free offers require manager finance legal and ceo approval", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "free_offer",
    amountJpy: 50000,
    discountPct: 100,
    freeOffer: true,
  });

  assertEquals(workflow.steps.map((step) => step.id), [
    "manager_review",
    "finance_review",
    "legal_review",
    "ceo_approval",
  ]);
  assertEquals(workflow.notificationEvent?.severity, "critical");
});

Deno.test("approval decisions must follow step order and allowed roles", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "discount_apply",
    amountJpy: 8000,
    discountPct: 25,
  });

  const outOfOrder = applyApprovalStepDecision(workflow, {
    stepId: "finance_review",
    decision: "approved",
    approverRole: "cfo",
    approverId: "user-cfo",
    decidedAt: "2026-06-09T00:05:00Z",
  });
  assertEquals(outOfOrder.accepted, false);
  assertEquals(outOfOrder.error, "approval_step_out_of_order");

  const wrongRole = applyApprovalStepDecision(workflow, {
    decision: "approved",
    approverRole: "cfo",
    approverId: "user-cfo",
    decidedAt: "2026-06-09T00:05:00Z",
  });
  assertEquals(wrongRole.accepted, false);
  assertEquals(wrongRole.error, "approver_role_not_allowed_for_step");
});

Deno.test("approval workflow advances and completes with audit events", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "discount_apply",
    amountJpy: 8000,
    discountPct: 25,
  });

  const manager = applyApprovalStepDecision(workflow, {
    decision: "approved",
    approverRole: "manager",
    approverId: "user-manager",
    decidedAt: "2026-06-09T00:05:00Z",
  });
  assertEquals(manager.accepted, true);
  assertEquals(manager.workflow.status, "pending");
  assertEquals(manager.workflow.currentStepId, "finance_review");
  assertEquals(manager.auditEvents[0].event, "step_approved");

  const finance = applyApprovalStepDecision(manager.workflow, {
    decision: "approved",
    approverRole: "cfo",
    approverId: "user-cfo",
    decidedAt: "2026-06-09T00:10:00Z",
  });
  assertEquals(finance.accepted, true);
  assertEquals(finance.workflow.status, "approved");
  assertEquals(finance.workflow.transactionStatus, "approval_completed");
  assertEquals(finance.workflow.currentStepId, null);
});

Deno.test("approval workflow rejection ends the held transaction", () => {
  const workflow = buildMultiStepApprovalWorkflow({
    actionType: "privilege_grant",
    privilegeGrant: true,
  });

  const rejection = applyApprovalStepDecision(workflow, {
    decision: "rejected",
    approverRole: "manager",
    approverId: "user-manager",
    comment: "Not enough justification.",
    decidedAt: "2026-06-09T00:05:00Z",
  });

  assertEquals(rejection.accepted, true);
  assertEquals(rejection.workflow.status, "rejected");
  assertEquals(rejection.workflow.transactionStatus, "approval_rejected");
  assertEquals(rejection.workflow.currentStepId, null);
  assertEquals(rejection.auditEvents[0].comment, "Not enough justification.");
});

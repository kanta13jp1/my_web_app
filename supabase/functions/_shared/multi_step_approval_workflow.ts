export type ApprovalActionType =
  | "discount_apply"
  | "privilege_grant"
  | "free_offer";

export type ApprovalDecisionValue = "approved" | "rejected";
export type ApprovalWorkflowStatus =
  | "not_required"
  | "pending"
  | "approved"
  | "rejected";
export type ApprovalStepStatus = "pending" | "approved" | "rejected";

export interface ApprovalWorkflowInput {
  actionType: ApprovalActionType;
  requestedByRole?: string | null;
  amountJpy?: number | null;
  discountPct?: number | null;
  freeOffer?: boolean | null;
  privilegeGrant?: boolean | null;
  requestedAt?: string | null;
}

export interface ApprovalStep {
  id: string;
  label: string;
  allowedRoles: string[];
  status: ApprovalStepStatus;
  approvedBy?: string | null;
  approvedByRole?: string | null;
  decidedAt?: string | null;
  comment?: string | null;
}

export interface ApprovalWorkflowNotificationEvent {
  channel: "admin_approval_requests";
  eventType: "multi_step_approval.requested";
  severity: "medium" | "high" | "critical";
  title: string;
  message: string;
  targetRoles: string[];
  payload: Record<string, unknown>;
}

export interface MultiStepApprovalWorkflow {
  required: boolean;
  status: ApprovalWorkflowStatus;
  transactionStatus:
    | "approval_not_required"
    | "held_for_approval"
    | "approval_completed"
    | "approval_rejected";
  actionType: ApprovalActionType;
  currentStepId: string | null;
  steps: ApprovalStep[];
  notificationEvent: ApprovalWorkflowNotificationEvent | null;
  auditEvents: Record<string, unknown>[];
}

export interface ApprovalStepDecisionInput {
  decision: ApprovalDecisionValue;
  approverRole: string;
  approverId: string;
  stepId?: string | null;
  comment?: string | null;
  decidedAt?: string | null;
}

export interface ApprovalStepDecisionResult {
  accepted: boolean;
  error: string | null;
  workflow: MultiStepApprovalWorkflow;
  auditEvents: Record<string, unknown>[];
}

const DISCOUNT_PCT_THRESHOLD = 20;
const HIGH_DISCOUNT_PCT_THRESHOLD = 50;
const DISCOUNT_AMOUNT_THRESHOLD_JPY = 5000;

function normalizeRole(value: string | null | undefined): string {
  return String(value ?? "").trim().toLowerCase();
}

function uniqueRoles(steps: readonly ApprovalStep[]): string[] {
  return [...new Set(steps.flatMap((step) => step.allowedRoles))];
}

function normalizeNumber(value: number | null | undefined): number {
  return Number.isFinite(value) ? Number(value) : 0;
}

function buildStep(
  id: string,
  label: string,
  allowedRoles: readonly string[],
): ApprovalStep {
  return {
    id,
    label,
    allowedRoles: [...allowedRoles],
    status: "pending",
  };
}

function requiredSteps(input: ApprovalWorkflowInput): ApprovalStep[] {
  const discountPct = normalizeNumber(input.discountPct);
  const amountJpy = normalizeNumber(input.amountJpy);
  const freeOffer = input.freeOffer === true ||
    input.actionType === "free_offer";
  const privilegeGrant = input.privilegeGrant === true ||
    input.actionType === "privilege_grant";
  const steps: ApprovalStep[] = [];

  if (
    freeOffer || privilegeGrant || discountPct >= DISCOUNT_PCT_THRESHOLD ||
    amountJpy >= DISCOUNT_AMOUNT_THRESHOLD_JPY
  ) {
    steps.push(buildStep("manager_review", "Manager review", [
      "manager",
      "admin",
      "owner",
    ]));
  }

  if (
    freeOffer || discountPct >= DISCOUNT_PCT_THRESHOLD ||
    amountJpy >= DISCOUNT_AMOUNT_THRESHOLD_JPY
  ) {
    steps.push(buildStep("finance_review", "Finance review", [
      "cfo",
      "admin",
      "owner",
    ]));
  }

  if (freeOffer || privilegeGrant) {
    steps.push(buildStep("legal_review", "Legal review", [
      "legal",
      "admin",
      "owner",
    ]));
  }

  if (
    freeOffer || privilegeGrant || discountPct >= HIGH_DISCOUNT_PCT_THRESHOLD
  ) {
    steps.push(buildStep("ceo_approval", "CEO approval", [
      "ceo",
      "admin",
      "owner",
    ]));
  }

  return steps;
}

function severityFor(
  input: ApprovalWorkflowInput,
): "medium" | "high" | "critical" {
  if (
    input.freeOffer === true || input.privilegeGrant === true ||
    normalizeNumber(input.discountPct) >= HIGH_DISCOUNT_PCT_THRESHOLD
  ) {
    return "critical";
  }
  if (
    normalizeNumber(input.discountPct) >= DISCOUNT_PCT_THRESHOLD ||
    normalizeNumber(input.amountJpy) >= DISCOUNT_AMOUNT_THRESHOLD_JPY
  ) {
    return "high";
  }
  return "medium";
}

function currentStepId(steps: readonly ApprovalStep[]): string | null {
  return steps.find((step) => step.status === "pending")?.id ?? null;
}

export function buildMultiStepApprovalWorkflow(
  input: ApprovalWorkflowInput,
): MultiStepApprovalWorkflow {
  const steps = requiredSteps(input);
  const required = steps.length > 0;
  const requestedAt = input.requestedAt ?? new Date().toISOString();
  const notificationEvent = required
    ? {
      channel: "admin_approval_requests" as const,
      eventType: "multi_step_approval.requested" as const,
      severity: severityFor(input),
      title: "Approval required for high-risk AI action",
      message:
        "A discount, free offer, or privilege grant is held until all approval steps pass.",
      targetRoles: uniqueRoles(steps),
      payload: {
        action_type: input.actionType,
        requested_by_role: normalizeRole(input.requestedByRole),
        amount_jpy: normalizeNumber(input.amountJpy),
        discount_pct: normalizeNumber(input.discountPct),
        free_offer: input.freeOffer === true,
        privilege_grant: input.privilegeGrant === true,
      },
    }
    : null;

  return {
    required,
    status: required ? "pending" : "not_required",
    transactionStatus: required ? "held_for_approval" : "approval_not_required",
    actionType: input.actionType,
    currentStepId: currentStepId(steps),
    steps,
    notificationEvent,
    auditEvents: [{
      event: "workflow_requested",
      action_type: input.actionType,
      approval_required: required,
      at: requestedAt,
      requested_by_role: normalizeRole(input.requestedByRole),
    }],
  };
}

export function applyApprovalStepDecision(
  workflow: MultiStepApprovalWorkflow,
  input: ApprovalStepDecisionInput,
): ApprovalStepDecisionResult {
  if (!workflow.required || workflow.status === "not_required") {
    return {
      accepted: false,
      error: "approval_not_required",
      workflow,
      auditEvents: [],
    };
  }
  if (workflow.status === "approved" || workflow.status === "rejected") {
    return {
      accepted: false,
      error: `workflow_already_${workflow.status}`,
      workflow,
      auditEvents: [],
    };
  }

  const stepId = input.stepId ?? workflow.currentStepId;
  const stepIndex = workflow.steps.findIndex((step) => step.id === stepId);
  if (stepIndex < 0) {
    return {
      accepted: false,
      error: "approval_step_not_found",
      workflow,
      auditEvents: [],
    };
  }
  if (workflow.steps[stepIndex].id !== workflow.currentStepId) {
    return {
      accepted: false,
      error: "approval_step_out_of_order",
      workflow,
      auditEvents: [],
    };
  }

  const approverRole = normalizeRole(input.approverRole);
  const step = workflow.steps[stepIndex];
  if (!step.allowedRoles.includes(approverRole)) {
    return {
      accepted: false,
      error: "approver_role_not_allowed_for_step",
      workflow,
      auditEvents: [],
    };
  }

  const decidedAt = input.decidedAt ?? new Date().toISOString();
  const updatedSteps = workflow.steps.map((candidate, index) =>
    index === stepIndex
      ? {
        ...candidate,
        status: input.decision,
        approvedBy: input.approverId,
        approvedByRole: approverRole,
        decidedAt,
        comment: input.comment ?? "",
      }
      : candidate
  );
  const rejected = input.decision === "rejected";
  const nextCurrentStepId = rejected ? null : currentStepId(updatedSteps);
  const nextStatus: ApprovalWorkflowStatus = rejected
    ? "rejected"
    : nextCurrentStepId === null
    ? "approved"
    : "pending";
  const nextTransactionStatus = nextStatus === "approved"
    ? "approval_completed"
    : nextStatus === "rejected"
    ? "approval_rejected"
    : "held_for_approval";
  const auditEvent = {
    event: `step_${input.decision}`,
    step_id: step.id,
    actor_id: input.approverId,
    approver_role: approverRole,
    comment: input.comment ?? "",
    at: decidedAt,
  };

  return {
    accepted: true,
    error: null,
    workflow: {
      ...workflow,
      status: nextStatus,
      transactionStatus: nextTransactionStatus,
      currentStepId: nextCurrentStepId,
      steps: updatedSteps,
    },
    auditEvents: [auditEvent],
  };
}

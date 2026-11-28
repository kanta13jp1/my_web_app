import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  areAllChecklistItemsComplete,
  buildComplianceChecklist,
  canInvokeProvider,
  isChecklistApproveEligible,
} from "./ai_compliance_guard.ts";

Deno.test("canInvokeProvider blocks missing, unverified, and in_review", () => {
  const missing = canInvokeProvider(null);
  assertEquals(missing.allowed, false);
  assertEquals(missing.code, "COMPLIANCE_NOT_APPROVED");
  assertEquals(missing.status, "unverified");

  const unverified = canInvokeProvider({
    provider_key: "new-llm",
    model_id: "frontier-x",
    status: "unverified",
    checklist: {
      terms_reviewed: true,
      data_retention_checked: true,
      pii_leakage_checked: true,
      security_controls_verified: true,
    },
    human_approved_by: "alice",
  });
  assertEquals(unverified.allowed, false);
  assertEquals(unverified.code, "COMPLIANCE_NOT_APPROVED");
  assertEquals(unverified.status, "unverified");

  const inReview = canInvokeProvider({
    status: "in_review",
    human_approved_by: "alice",
  });
  assertEquals(inReview.allowed, false);
  assertEquals(inReview.code, "COMPLIANCE_NOT_APPROVED");
  assertEquals(inReview.status, "in_review");
});

Deno.test(
  "canInvokeProvider blocks approved status lacking approver or checklist",
  () => {
    const noApprover = canInvokeProvider({
      status: "approved",
      human_approved_by: "",
      checklist: {
        terms_reviewed: true,
        data_retention_checked: true,
        pii_leakage_checked: true,
        security_controls_verified: true,
      },
    });
    assertEquals(noApprover.allowed, false);
    assertEquals(noApprover.code, "COMPLIANCE_NOT_APPROVED");

    const incompleteChecklist = canInvokeProvider({
      status: "approved",
      human_approved_by: "legal-lead",
      checklist: {
        terms_reviewed: true,
        data_retention_checked: false,
        pii_leakage_checked: true,
        security_controls_verified: true,
      },
    });
    assertEquals(incompleteChecklist.allowed, false);
    assertEquals(incompleteChecklist.code, "COMPLIANCE_NOT_APPROVED");
  },
);

Deno.test(
  "canInvokeProvider allows approved record with human approver and checklist",
  () => {
    const checklist = buildComplianceChecklist({
      terms_reviewed: true,
      data_retention_checked: true,
      pii_leakage_checked: true,
      security_controls_verified: true,
    });
    assertEquals(areAllChecklistItemsComplete(checklist), true);
    const eligibility = isChecklistApproveEligible({
      checklist,
      reviewerName: "sec-reviewer",
      humanConfirmed: true,
    });
    assertEquals(eligibility.ok, true);

    const allowed = canInvokeProvider({
      provider_key: "partner-llm",
      model_id: "model-v2",
      status: "approved",
      human_approved_by: "sec-reviewer",
      checklist,
    });
    assertEquals(allowed.allowed, true);
    assertEquals(allowed.code, "COMPLIANCE_APPROVED");
    assertEquals(allowed.status, "approved");
  },
);

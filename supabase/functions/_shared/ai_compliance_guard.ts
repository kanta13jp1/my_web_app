export const AI_COMPLIANCE_SOURCE = "ai_provider_compliance";

export const COMPLIANCE_STATUSES = [
  "unverified",
  "in_review",
  "approved",
] as const;

export type ComplianceStatus = (typeof COMPLIANCE_STATUSES)[number];

export const COMPLIANCE_STATUS_LABELS: Record<ComplianceStatus, string> = {
  unverified: "未検証",
  in_review: "検証中",
  approved: "承認済",
};

export interface ComplianceChecklist {
  terms_reviewed: boolean;
  data_retention_checked: boolean;
  pii_leakage_checked: boolean;
  security_controls_verified: boolean;
}

export interface ComplianceRecordLike {
  provider_key?: string;
  model_id?: string;
  status?: string;
  checklist?: Partial<ComplianceChecklist> | null;
  human_approved_by?: string | null;
  approved_at?: string | null;
}

export interface ProviderInvokeGuardResult {
  allowed: boolean;
  code: "COMPLIANCE_APPROVED" | "COMPLIANCE_NOT_APPROVED";
  status: ComplianceStatus;
  reason: string;
}

export function normalizeComplianceStatus(raw: unknown): ComplianceStatus {
  const s = String(raw ?? "").trim();
  if ((COMPLIANCE_STATUSES as readonly string[]).includes(s)) {
    return s as ComplianceStatus;
  }
  return "unverified";
}

export function buildComplianceChecklist(raw: unknown): ComplianceChecklist {
  const obj = typeof raw === "object" && raw !== null && !Array.isArray(raw)
    ? (raw as Record<string, unknown>)
    : {};
  return {
    terms_reviewed: obj.terms_reviewed === true,
    data_retention_checked: obj.data_retention_checked === true,
    pii_leakage_checked: obj.pii_leakage_checked === true,
    security_controls_verified: obj.security_controls_verified === true,
  };
}

export function areAllChecklistItemsComplete(
  checklist: ComplianceChecklist,
): boolean {
  return (
    checklist.terms_reviewed &&
    checklist.data_retention_checked &&
    checklist.pii_leakage_checked &&
    checklist.security_controls_verified
  );
}

export function isChecklistApproveEligible(params: {
  checklist: ComplianceChecklist;
  reviewerName: string;
  humanConfirmed: boolean;
}): { ok: boolean; reason?: string } {
  if (!params.humanConfirmed) {
    return {
      ok: false,
      reason: "人間の担当者による最終確認チェック (human_confirmed) が必須です",
    };
  }
  if (!params.reviewerName.trim()) {
    return {
      ok: false,
      reason: "最終承認を行う担当者名 (reviewer_name) が必須です",
    };
  }
  if (!areAllChecklistItemsComplete(params.checklist)) {
    return {
      ok: false,
      reason: "セキュリティ基準・利用規約の全4チェック項目を完了してください",
    };
  }
  return { ok: true };
}

/**
 * Evaluates system-level API invocation gate for an AI model provider.
 * Legal/terms compliance can NEVER be auto-approved; invocation stays blocked
 * unless `status === "approved"` AND `human_approved_by` AND checklist pass.
 */
export function canInvokeProvider(
  record: ComplianceRecordLike | null | undefined,
): ProviderInvokeGuardResult {
  if (!record) {
    return {
      allowed: false,
      code: "COMPLIANCE_NOT_APPROVED",
      status: "unverified",
      reason: "コンプライアンス検証レコードが未登録のためAPI呼び出しを遮断しました",
    };
  }

  const status = normalizeComplianceStatus(record.status);
  const checklist = buildComplianceChecklist(record.checklist);
  const approver = typeof record.human_approved_by === "string"
    ? record.human_approved_by.trim()
    : "";

  if (status !== "approved") {
    return {
      allowed: false,
      code: "COMPLIANCE_NOT_APPROVED",
      status,
      reason: `ステータスが「${COMPLIANCE_STATUS_LABELS[status]}」のためAPI呼び出しをブロックしました`,
    };
  }

  if (!approver) {
    return {
      allowed: false,
      code: "COMPLIANCE_NOT_APPROVED",
      status,
      reason: "人間の承認者記録が欠落しているためAPI呼び出しをブロックしました",
    };
  }

  if (!areAllChecklistItemsComplete(checklist)) {
    return {
      allowed: false,
      code: "COMPLIANCE_NOT_APPROVED",
      status,
      reason: "検証チェックリスト未完了項目があるためAPI呼び出しをブロックしました",
    };
  }

  return {
    allowed: true,
    code: "COMPLIANCE_APPROVED",
    status: "approved",
    reason: `承認済み (${approver}) のためAPI呼び出しが許可されています`,
  };
}

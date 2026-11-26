export type DiscussionStage =
  | "general_debate"
  | "drafting"
  | "agreed"
  | "submitted";

export const DISCUSSION_STAGE_LABELS = {
  general_debate: "総論討議",
  drafting: "条文起草",
  agreed: "合意済み",
  submitted: "原案提出",
} as const satisfies Record<DiscussionStage, string>;

export const DISCUSSION_STAGE_ORDER: readonly DiscussionStage[] = [
  "general_debate",
  "drafting",
  "agreed",
  "submitted",
];

export interface DiscussionMilestone {
  id: string;
  topic: string;
  stage: DiscussionStage;
  targetDate: string;
  ownerGroup: string;
  updatedAt: string;
}

export interface MilestoneAuditEntry {
  id: string;
  milestoneId: string;
  topic: string;
  previousStage: DiscussionStage;
  nextStage: DiscussionStage;
  previousTargetDate: string;
  nextTargetDate: string;
  deltaDays: number;
  reason: string;
  recordedAt: string;
}

export function computeDeltaDays(
  previousIsoDate: string,
  nextIsoDate: string,
): number {
  const prevMs = Date.parse(`${previousIsoDate.slice(0, 10)}T00:00:00Z`);
  const nextMs = Date.parse(`${nextIsoDate.slice(0, 10)}T00:00:00Z`);
  if (!Number.isFinite(prevMs) || !Number.isFinite(nextMs)) {
    return 0;
  }
  return Math.round((nextMs - prevMs) / 86_400_000);
}

export class InMemoryDiscussionRoadmapStore {
  private readonly milestones = new Map<string, DiscussionMilestone>();
  private readonly auditLog: MilestoneAuditEntry[] = [];
  private seq = 0;

  registerMilestone(
    milestone: Omit<DiscussionMilestone, "updatedAt">,
    nowIso = new Date().toISOString(),
  ): DiscussionMilestone {
    const record: DiscussionMilestone = {
      ...milestone,
      updatedAt: nowIso,
    };
    this.milestones.set(record.id, structuredClone(record));
    return structuredClone(record);
  }

  updateMilestoneSchedule(params: {
    milestoneId: string;
    nextStage?: DiscussionStage;
    nextTargetDate?: string;
    reason: string;
    nowIso?: string;
  }): {
    milestone: DiscussionMilestone;
    auditEntry: MilestoneAuditEntry;
  } | null {
    const existing = this.milestones.get(params.milestoneId);
    if (!existing) return null;

    const nowIso = params.nowIso ?? new Date().toISOString();
    const nextStage = params.nextStage ?? existing.stage;
    const nextTargetDate = params.nextTargetDate ?? existing.targetDate;
    const deltaDays = computeDeltaDays(existing.targetDate, nextTargetDate);

    const updated: DiscussionMilestone = {
      ...existing,
      stage: nextStage,
      targetDate: nextTargetDate,
      updatedAt: nowIso,
    };
    this.milestones.set(updated.id, updated);

    this.seq += 1;
    const auditEntry: MilestoneAuditEntry = {
      id: `audit-${this.seq}`,
      milestoneId: updated.id,
      topic: updated.topic,
      previousStage: existing.stage,
      nextStage,
      previousTargetDate: existing.targetDate,
      nextTargetDate,
      deltaDays,
      reason: params.reason.trim(),
      recordedAt: nowIso,
    };
    this.auditLog.push(auditEntry);

    return {
      milestone: structuredClone(updated),
      auditEntry: structuredClone(auditEntry),
    };
  }

  listMilestones(): DiscussionMilestone[] {
    return Array.from(this.milestones.values()).map((m) => structuredClone(m));
  }

  listAuditHistory(milestoneId?: string): MilestoneAuditEntry[] {
    const rows = milestoneId
      ? this.auditLog.filter((item) => item.milestoneId === milestoneId)
      : this.auditLog;
    return rows.map((item) => structuredClone(item));
  }
}

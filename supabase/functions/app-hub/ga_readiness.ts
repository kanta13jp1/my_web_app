export type GaReadinessAxisStatus = "green" | "amber" | "red" | "blocked";

export type GaReadinessAxis = {
  id: string;
  code: string;
  title: string;
  owner: string;
  issue: number;
  status: GaReadinessAxisStatus;
  progress: number;
  target_date: string;
  evidence: string;
  gate_command: string;
  next_action: string;
  blocker?: string;
};

export type GaReadinessSnapshot = {
  generated_at: string;
  ga_eligible: boolean;
  summary: {
    axis_count: number;
    green_count: number;
    blocked_count: number;
    overall_progress: number;
    blockers: string[];
  };
  axes: GaReadinessAxis[];
};

export const GA_READINESS_AXES: readonly GaReadinessAxis[] = [
  {
    id: "mvp_scope",
    code: "A",
    title: "MVP Scope",
    owner: "Claude Code #1 + Codex #1",
    issue: 1640,
    status: "amber",
    progress: 80,
    target_date: "2026-06-30",
    evidence: "docs/MVP_SCOPE_FROZEN.md",
    gate_command: "flutter analyze && flutter test",
    next_action: "Keep GA gate checks green and freeze remaining MVP deltas.",
  },
  {
    id: "pricing_v1",
    code: "B",
    title: "Pricing v1.0",
    owner: "User",
    issue: 1640,
    status: "blocked",
    progress: 20,
    target_date: "2026-07-31",
    evidence: "Paddle product config + public pricing copy",
    gate_command: "Paddle audit status",
    next_action: "Register the production Paddle entity and approve pricing.",
    blocker: "Manual Paddle/legal approval is required.",
  },
  {
    id: "legal_entity",
    code: "C",
    title: "Legal Entity",
    owner: "User",
    issue: 1662,
    status: "blocked",
    progress: 0,
    target_date: "2026-09-30",
    evidence: "docs/CORPORATE_FORMATION_RUNBOOK.md",
    gate_command: "Manual evidence URL",
    next_action: "Attach corporate formation evidence once the entity exists.",
    blocker: "Corporate formation is a user/legal decision.",
  },
  {
    id: "banking",
    code: "D",
    title: "Banking",
    owner: "User",
    issue: 1662,
    status: "blocked",
    progress: 0,
    target_date: "2026-10-15",
    evidence: "Masked corporate bank account evidence",
    gate_command: "Manual evidence URL",
    next_action: "Attach a masked bank-account evidence URL after opening.",
    blocker: "Bank account setup is user-owned.",
  },
  {
    id: "video_secrets",
    code: "E",
    title: "Video Secrets",
    owner: "User",
    issue: 1724,
    status: "blocked",
    progress: 20,
    target_date: "2026-05-15",
    evidence: "Five GitHub Actions secrets visible via gh secret list",
    gate_command: "notebooklm-video-pipeline.yml green",
    next_action: "Register the five required video-pipeline secrets.",
    blocker: "Repository secrets are still user-provided.",
  },
] as const;

export class GaReadinessActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "GaReadinessActionError";
    this.status = status;
  }
}

export function handleGaReadinessAction(action: string): GaReadinessSnapshot {
  if (action === "agent.list_ga_axes") {
    return buildGaReadinessSnapshot();
  }
  throw new GaReadinessActionError(
    `Unsupported GA readiness action: ${action}`,
  );
}

export function buildGaReadinessSnapshot(
  generatedAt = new Date(),
): GaReadinessSnapshot {
  const axes = GA_READINESS_AXES.map((axis) => ({ ...axis }));
  const greenCount = axes.filter((axis) => axis.status === "green").length;
  const blockedAxes = axes.filter((axis) => axis.status === "blocked");
  const overallProgress = Math.round(
    axes.reduce((sum, axis) => sum + axis.progress, 0) / axes.length,
  );
  return {
    generated_at: generatedAt.toISOString(),
    ga_eligible: greenCount === axes.length,
    summary: {
      axis_count: axes.length,
      green_count: greenCount,
      blocked_count: blockedAxes.length,
      overall_progress: overallProgress,
      blockers: blockedAxes.map((axis) =>
        `${axis.code}. ${axis.title}: ${axis.blocker ?? "blocked"}`
      ),
    },
    axes,
  };
}

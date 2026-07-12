// Pure guards for the owner-only roadmap facts injected into AI share prompts.
// Kept separate from index.ts so auth decisions, source validation, and the
// public plan allowlist remain deterministic and unit-testable.

export type RoadmapPlan = {
  label: string;
  deadline: string;
  target: number;
  features_done: number;
  features_total: number;
  sort_order?: number;
};

export const SHAREABLE_ROADMAP_PLAN_LABELS = [
  "短期計画",
  "中期計画",
  "長期計画",
] as const;

export function canReadRoadmapShareStats(
  userId: string,
  isAdmin: boolean,
): boolean {
  return userId === "service_role" || isAdmin;
}

export function parseRoadmapCounts(
  totalUsers: unknown,
  totalAchievements: unknown,
): { userCount: number; achievementsCount: number } {
  if (
    typeof totalUsers !== "number" || !Number.isInteger(totalUsers) ||
    totalUsers < 0 || typeof totalAchievements !== "number" ||
    !Number.isInteger(totalAchievements) || totalAchievements < 0
  ) {
    throw new Error("roadmap progress source returned invalid counts");
  }
  return {
    userCount: totalUsers,
    achievementsCount: totalAchievements,
  };
}

export function selectShareableRoadmapPlans(
  plans: readonly RoadmapPlan[],
): RoadmapPlan[] {
  const byLabel = new Map(plans.map((plan) => [plan.label, plan]));
  return SHAREABLE_ROADMAP_PLAN_LABELS
    .map((label) => byLabel.get(label))
    .filter((plan): plan is RoadmapPlan => plan !== undefined);
}

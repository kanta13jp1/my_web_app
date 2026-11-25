export const DEFAULT_MIN_PROMOTION_TENANTS = 3;
export const DEFAULT_PROMOTION_SCORE_THRESHOLD = 0.7;
export const LOCAL_RANK_WEIGHT = 0.70;
export const GLOBAL_RANK_WEIGHT = 0.20;
export const USAGE_RANK_WEIGHT = 0.10;

export type PromotionStatus = "local_only" | "promoted" | "demoted";

export const PROMOTION_STATUS_LABELS = {
  local_only: "ローカル限定",
  promoted: "グローバル昇格済",
  demoted: "昇格解除",
} as const satisfies Record<PromotionStatus, string>;

export interface OptInPromotionConfig {
  minQualifyingTenants: number;
  promotionThreshold: number;
}

export interface TenantEvaluationInput {
  tenantId: string;
  itemId: string;
  score: number;
  usageScore?: number;
  updatedAt: string;
}

export interface GlobalPromotionRecord {
  itemId: string;
  status: PromotionStatus;
  statusLabel: string;
  isGlobalPromoted: boolean;
  qualifyingTenantCount: number;
  globalScore: number;
  evaluatedAt: string;
}

export interface PromotionSweepSummary {
  evaluatedItems: number;
  promotedCount: number;
  demotedCount: number;
  activeGlobalCount: number;
  records: GlobalPromotionRecord[];
}

function clampUnit(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

export function resolveOptInConfigFromEnv(
  envGet: (key: string) => string | undefined = (key) => Deno.env.get(key),
): OptInPromotionConfig {
  const rawMinTenants = Number(envGet("OPTIN_MIN_QUALIFYING_TENANTS") ?? "");
  const minQualifyingTenants = Number.isInteger(rawMinTenants) &&
      rawMinTenants >= 1
    ? rawMinTenants
    : DEFAULT_MIN_PROMOTION_TENANTS;

  const rawThresholdStr = (envGet("OPTIN_PROMOTION_THRESHOLD") ?? "").trim();
  const rawThreshold = rawThresholdStr === ""
    ? Number.NaN
    : Number(rawThresholdStr);
  const promotionThreshold = Number.isFinite(rawThreshold) &&
      rawThreshold >= 0 &&
      rawThreshold <= 1
    ? rawThreshold
    : DEFAULT_PROMOTION_SCORE_THRESHOLD;

  return { minQualifyingTenants, promotionThreshold };
}

export function computeCompositeRankScore(params: {
  localScore: number;
  globalScore: number;
  usageScore: number;
}): number {
  const local = clampUnit(params.localScore);
  const global = clampUnit(params.globalScore);
  const usage = clampUnit(params.usageScore);
  return clampUnit(
    LOCAL_RANK_WEIGHT * local +
      GLOBAL_RANK_WEIGHT * global +
      USAGE_RANK_WEIGHT * usage,
  );
}

export function runPromotionAndDemotionSweep(params: {
  evaluations: TenantEvaluationInput[];
  previousRecords?: GlobalPromotionRecord[];
  config?: OptInPromotionConfig;
  nowIso?: string;
}): PromotionSweepSummary {
  const config = params.config ?? {
    minQualifyingTenants: DEFAULT_MIN_PROMOTION_TENANTS,
    promotionThreshold: DEFAULT_PROMOTION_SCORE_THRESHOLD,
  };
  const evaluatedAt = params.nowIso ?? new Date().toISOString();
  const prevByItem = new Map<string, GlobalPromotionRecord>();
  for (const rec of params.previousRecords ?? []) {
    prevByItem.set(rec.itemId, rec);
  }

  // Group latest score per distinct (itemId, tenantId).
  const byItemTenant = new Map<string, Map<string, TenantEvaluationInput>>();
  for (const evalItem of params.evaluations) {
    const itemId = evalItem.itemId.trim();
    const tenantId = evalItem.tenantId.trim();
    if (!itemId || !tenantId) continue;
    let tenantMap = byItemTenant.get(itemId);
    if (!tenantMap) {
      tenantMap = new Map<string, TenantEvaluationInput>();
      byItemTenant.set(itemId, tenantMap);
    }
    const prev = tenantMap.get(tenantId);
    if (!prev || evalItem.updatedAt >= prev.updatedAt) {
      tenantMap.set(tenantId, {
        ...evalItem,
        itemId,
        tenantId,
        score: clampUnit(evalItem.score),
        usageScore: clampUnit(evalItem.usageScore ?? 0),
      });
    }
  }

  const allItemIds = new Set<string>([
    ...byItemTenant.keys(),
    ...prevByItem.keys(),
  ]);
  const sortedIds = [...allItemIds].sort();

  let promotedCount = 0;
  let demotedCount = 0;
  let activeGlobalCount = 0;
  const records: GlobalPromotionRecord[] = [];

  for (const itemId of sortedIds) {
    const tenantMap = byItemTenant.get(itemId);
    const qualifyingScores: number[] = [];
    if (tenantMap) {
      for (const itemEval of tenantMap.values()) {
        if (itemEval.score >= config.promotionThreshold) {
          qualifyingScores.push(itemEval.score);
        }
      }
    }

    const prev = prevByItem.get(itemId);
    const qualifies = qualifyingScores.length >= config.minQualifyingTenants;
    const meanScore = qualifyingScores.length === 0 ? 0 : clampUnit(
      qualifyingScores.reduce((acc, s) => acc + s, 0) /
        qualifyingScores.length,
    );

    let status: PromotionStatus = "local_only";
    if (qualifies) {
      status = "promoted";
      activeGlobalCount += 1;
      if (!prev || !prev.isGlobalPromoted) {
        promotedCount += 1;
      }
    } else if (prev && prev.isGlobalPromoted) {
      status = "demoted";
      demotedCount += 1;
    }

    records.push({
      itemId,
      status,
      statusLabel: PROMOTION_STATUS_LABELS[status],
      isGlobalPromoted: qualifies,
      qualifyingTenantCount: qualifyingScores.length,
      globalScore: qualifies ? meanScore : 0,
      evaluatedAt,
    });
  }

  return {
    evaluatedItems: sortedIds.length,
    promotedCount,
    demotedCount,
    activeGlobalCount,
    records,
  };
}

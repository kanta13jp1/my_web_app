/**
 * Tiered Model Routing & Automatic Escalation (#2784)
 *
 * Routes requests to Free / Budget / Performance / Premium tiers based on task
 * complexity and automatically escalates to the next tier on failure, timeout,
 * or low confidence, while tracking routing and escalation telemetry.
 */

export type ModelTier = 'free' | 'budget' | 'performance' | 'premium';

export type TaskDifficulty = 'trivial' | 'standard' | 'complex' | 'critical';

export type EscalationReason =
  | 'provider_error'
  | 'timeout'
  | 'low_confidence'
  | 'rate_limited';

export const MODEL_TIER_ORDER: readonly ModelTier[] = [
  'free',
  'budget',
  'performance',
  'premium',
] as const;

export const TIER_LABELS = {
  free: 'Free',
  budget: 'Budget',
  performance: 'Performance',
  premium: 'Premium',
} as const satisfies Record<ModelTier, string>;

export const DIFFICULTY_DEFAULT_TIER = {
  trivial: 'free',
  standard: 'budget',
  complex: 'performance',
  critical: 'premium',
} as const satisfies Record<TaskDifficulty, ModelTier>;

export interface TierRouteRequest {
  readonly taskId: string;
  readonly difficulty: TaskDifficulty;
  readonly minTier?: ModelTier;
  readonly maxTier?: ModelTier;
  readonly minConfidence?: number;
  readonly allowEscalation?: boolean;
}

export interface TierAttemptOutcome {
  readonly tier: ModelTier;
  readonly success: boolean;
  readonly latencyMs: number;
  readonly confidence?: number;
  readonly reason?: EscalationReason;
  readonly output?: string;
}

export interface EscalationStep {
  readonly fromTier: ModelTier;
  readonly toTier: ModelTier;
  readonly reason: EscalationReason;
  readonly latencyMs: number;
}

export interface TieredRouteResult {
  readonly taskId: string;
  readonly initialTier: ModelTier;
  readonly finalTier: ModelTier;
  readonly succeeded: boolean;
  readonly escalated: boolean;
  readonly attempts: readonly TierAttemptOutcome[];
  readonly escalations: readonly EscalationStep[];
  readonly totalLatencyMs: number;
  readonly output?: string;
}

export interface TierMetrics {
  readonly requestsStarted: number;
  readonly attempts: number;
  readonly successes: number;
  readonly failures: number;
  readonly totalLatencyMs: number;
}

export interface TieredRoutingTelemetry {
  readonly totalRequests: number;
  readonly succeededRequests: number;
  readonly escalatedRequests: number;
  readonly escalationRate: number;
  readonly perTier: Record<ModelTier, TierMetrics>;
}

export type TierExecutor = (
  tier: ModelTier,
  request: TierRouteRequest,
) => Promise<TierAttemptOutcome>;

function tierIndex(tier: ModelTier): number {
  return MODEL_TIER_ORDER.indexOf(tier);
}

export function clampTier(
  tier: ModelTier,
  minTier?: ModelTier,
  maxTier?: ModelTier,
): ModelTier {
  let idx = tierIndex(tier);
  if (minTier !== undefined) {
    idx = Math.max(idx, tierIndex(minTier));
  }
  if (maxTier !== undefined) {
    idx = Math.min(idx, tierIndex(maxTier));
  }
  return MODEL_TIER_ORDER[idx];
}

export function selectInitialTier(request: TierRouteRequest): ModelTier {
  const baseTier = DIFFICULTY_DEFAULT_TIER[request.difficulty];
  return clampTier(baseTier, request.minTier, request.maxTier);
}

export function resolveNextTier(
  currentTier: ModelTier,
  maxTier: ModelTier = 'premium',
): ModelTier | null {
  const nextIdx = tierIndex(currentTier) + 1;
  if (nextIdx >= MODEL_TIER_ORDER.length) {
    return null;
  }
  if (nextIdx > tierIndex(maxTier)) {
    return null;
  }
  return MODEL_TIER_ORDER[nextIdx];
}

function classifyFailure(
  outcome: TierAttemptOutcome,
  minConfidence: number,
): EscalationReason | null {
  if (!outcome.success) {
    return outcome.reason ?? 'provider_error';
  }
  if (
    outcome.confidence !== undefined &&
    outcome.confidence < minConfidence
  ) {
    return 'low_confidence';
  }
  return null;
}

export class TieredModelRouter {
  private totalRequests = 0;
  private succeededRequests = 0;
  private escalatedRequests = 0;
  private readonly perTier: Record<ModelTier, TierMetrics> = {
    free: {
      requestsStarted: 0,
      attempts: 0,
      successes: 0,
      failures: 0,
      totalLatencyMs: 0,
    },
    budget: {
      requestsStarted: 0,
      attempts: 0,
      successes: 0,
      failures: 0,
      totalLatencyMs: 0,
    },
    performance: {
      requestsStarted: 0,
      attempts: 0,
      successes: 0,
      failures: 0,
      totalLatencyMs: 0,
    },
    premium: {
      requestsStarted: 0,
      attempts: 0,
      successes: 0,
      failures: 0,
      totalLatencyMs: 0,
    },
  };

  async routeWithEscalation(
    request: TierRouteRequest,
    executor: TierExecutor,
  ): Promise<TieredRouteResult> {
    const initialTier = selectInitialTier(request);
    const maxTier = request.maxTier ?? 'premium';
    const minConfidence = request.minConfidence ?? 0.6;
    const allowEscalation = request.allowEscalation ?? true;

    this.totalRequests += 1;
    this.recordStart(initialTier);

    const attempts: TierAttemptOutcome[] = [];
    const escalations: EscalationStep[] = [];
    let currentTier: ModelTier | null = initialTier;
    let totalLatencyMs = 0;

    while (currentTier !== null) {
      const outcome = await executor(currentTier, request);
      const boundedLatency = Math.max(0, Math.round(outcome.latencyMs));
      totalLatencyMs += boundedLatency;
      attempts.push({ ...outcome, latencyMs: boundedLatency });

      const failureReason = classifyFailure(outcome, minConfidence);
      if (failureReason === null) {
        this.recordAttempt(currentTier, true, boundedLatency);
        this.succeededRequests += 1;
        if (escalations.length > 0) {
          this.escalatedRequests += 1;
        }
        return {
          taskId: request.taskId,
          initialTier,
          finalTier: currentTier,
          succeeded: true,
          escalated: escalations.length > 0,
          attempts,
          escalations,
          totalLatencyMs,
          output: outcome.output,
        };
      }

      this.recordAttempt(currentTier, false, boundedLatency);
      if (!allowEscalation) {
        break;
      }

      const nextTier = resolveNextTier(currentTier, maxTier);
      if (nextTier === null) {
        break;
      }
      escalations.push({
        fromTier: currentTier,
        toTier: nextTier,
        reason: failureReason,
        latencyMs: boundedLatency,
      });
      currentTier = nextTier;
    }

    if (escalations.length > 0) {
      this.escalatedRequests += 1;
    }

    const lastTier =
      attempts.length > 0 ? attempts[attempts.length - 1].tier : initialTier;
    return {
      taskId: request.taskId,
      initialTier,
      finalTier: lastTier,
      succeeded: false,
      escalated: escalations.length > 0,
      attempts,
      escalations,
      totalLatencyMs,
    };
  }

  getTelemetry(): TieredRoutingTelemetry {
    const escalationRate =
      this.totalRequests === 0
        ? 0
        : Number((this.escalatedRequests / this.totalRequests).toFixed(4));
    return {
      totalRequests: this.totalRequests,
      succeededRequests: this.succeededRequests,
      escalatedRequests: this.escalatedRequests,
      escalationRate,
      perTier: {
        free: { ...this.perTier.free },
        budget: { ...this.perTier.budget },
        performance: { ...this.perTier.performance },
        premium: { ...this.perTier.premium },
      },
    };
  }

  private recordStart(tier: ModelTier): void {
    const cur = this.perTier[tier];
    this.perTier[tier] = {
      ...cur,
      requestsStarted: cur.requestsStarted + 1,
    };
  }

  private recordAttempt(
    tier: ModelTier,
    succeeded: boolean,
    latencyMs: number,
  ): void {
    const cur = this.perTier[tier];
    this.perTier[tier] = {
      ...cur,
      attempts: cur.attempts + 1,
      successes: cur.successes + (succeeded ? 1 : 0),
      failures: cur.failures + (succeeded ? 0 : 1),
      totalLatencyMs: cur.totalLatencyMs + latencyMs,
    };
  }
}

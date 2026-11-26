import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import {
  clampTier,
  resolveNextTier,
  selectInitialTier,
  TIER_LABELS,
  TieredModelRouter,
  type ModelTier,
} from './tiered_model_escalation.ts';

Deno.test(
  'selectInitialTier maps difficulty and respects tier bounds',
  () => {
    assertEquals(
      selectInitialTier({ taskId: 't1', difficulty: 'trivial' }),
      'free',
    );
    assertEquals(
      selectInitialTier({ taskId: 't2', difficulty: 'standard' }),
      'budget',
    );
    assertEquals(
      selectInitialTier({
        taskId: 't3',
        difficulty: 'trivial',
        minTier: 'budget',
      }),
      'budget',
    );
    assertEquals(
      selectInitialTier({
        taskId: 't4',
        difficulty: 'critical',
        maxTier: 'performance',
      }),
      'performance',
    );
    assertEquals(clampTier('free', 'performance', 'budget'), 'budget');
    assertEquals(TIER_LABELS.premium, 'Premium');
  },
);

Deno.test(
  'resolveNextTier steps up until maxTier and stops cleanly',
  () => {
    assertEquals(resolveNextTier('free'), 'budget');
    assertEquals(resolveNextTier('budget'), 'performance');
    assertEquals(resolveNextTier('performance'), 'premium');
    assertEquals(resolveNextTier('premium'), null);
    assertEquals(resolveNextTier('budget', 'budget'), null);
  },
);

Deno.test(
  'routeWithEscalation escalates on provider error and low confidence',
  async () => {
    const router = new TieredModelRouter();
    const seen: ModelTier[] = [];

    const result = await router.routeWithEscalation(
      { taskId: 'task-1', difficulty: 'trivial', minConfidence: 0.7 },
      (tier) => {
        seen.push(tier);
        if (tier === 'free') {
          return Promise.resolve({
            tier,
            success: false,
            latencyMs: 120,
            reason: 'timeout',
          });
        }
        if (tier === 'budget') {
          return Promise.resolve({
            tier,
            success: true,
            latencyMs: 210,
            confidence: 0.45,
            output: 'uncertain',
          });
        }
        return Promise.resolve({
          tier,
          success: true,
          latencyMs: 340,
          confidence: 0.92,
          output: 'verified-answer',
        });
      },
    );

    assertEquals(seen, ['free', 'budget', 'performance']);
    assertEquals(result.succeeded, true);
    assertEquals(result.escalated, true);
    assertEquals(result.initialTier, 'free');
    assertEquals(result.finalTier, 'performance');
    assertEquals(result.totalLatencyMs, 670);
    assertEquals(result.escalations.length, 2);
    assertEquals(result.escalations[0].reason, 'timeout');
    assertEquals(result.escalations[1].reason, 'low_confidence');
    assertEquals(result.output, 'verified-answer');
  },
);

Deno.test(
  'routeWithEscalation aggregates telemetry and exhaustion failures',
  async () => {
    const router = new TieredModelRouter();

    const ok = await router.routeWithEscalation(
      { taskId: 'ok-1', difficulty: 'standard' },
      (tier) =>
        Promise.resolve({
          tier,
          success: true,
          latencyMs: 150,
          confidence: 0.9,
          output: 'done',
        }),
    );
    assertEquals(ok.escalated, false);

    const fail = await router.routeWithEscalation(
      { taskId: 'fail-1', difficulty: 'complex', maxTier: 'premium' },
      (tier) =>
        Promise.resolve({
          tier,
          success: false,
          latencyMs: 200,
          reason: 'rate_limited',
        }),
    );
    assertEquals(fail.succeeded, false);
    assertEquals(fail.finalTier, 'premium');
    assertEquals(fail.escalated, true);

    const telemetry = router.getTelemetry();
    assertEquals(telemetry.totalRequests, 2);
    assertEquals(telemetry.succeededRequests, 1);
    assertEquals(telemetry.escalatedRequests, 1);
    assertEquals(telemetry.escalationRate, 0.5);
    assertEquals(telemetry.perTier.budget.successes, 1);
    assertEquals(telemetry.perTier.performance.failures, 1);
    assertEquals(telemetry.perTier.premium.failures, 1);
  },
);

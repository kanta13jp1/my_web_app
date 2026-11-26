import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/tiered_model_escalation_service.dart';

void main() {
  group('TieredModelEscalationService', () {
    test('selectInitialTier maps difficulty and applies bounds', () {
      final service = TieredModelEscalationService();

      expect(
        service.selectInitialTier(
          const TierRouteRequest(
            taskId: 't1',
            difficulty: TaskDifficulty.trivial,
          ),
        ),
        ModelTier.free,
      );
      expect(
        service.selectInitialTier(
          const TierRouteRequest(
            taskId: 't2',
            difficulty: TaskDifficulty.trivial,
            minTier: ModelTier.budget,
          ),
        ),
        ModelTier.budget,
      );
      expect(
        service.selectInitialTier(
          const TierRouteRequest(
            taskId: 't3',
            difficulty: TaskDifficulty.critical,
            maxTier: ModelTier.performance,
          ),
        ),
        ModelTier.performance,
      );
    });

    test('routeWithEscalation escalates on failure and low confidence',
        () async {
      final service = TieredModelEscalationService();
      final visited = <ModelTier>[];

      final result = await service.routeWithEscalation(
        const TierRouteRequest(
          taskId: 'esc-1',
          difficulty: TaskDifficulty.trivial,
          minConfidence: 0.75,
        ),
        (tier, request) async {
          visited.add(tier);
          if (tier == ModelTier.free) {
            return TierExecutionResult(
              tier: tier,
              success: false,
              latencyMs: 100,
              reason: EscalationReason.timeout,
            );
          }
          if (tier == ModelTier.budget) {
            return TierExecutionResult(
              tier: tier,
              success: true,
              latencyMs: 180,
              confidence: 0.5,
              output: 'weak',
            );
          }
          return TierExecutionResult(
            tier: tier,
            success: true,
            latencyMs: 260,
            confidence: 0.95,
            output: 'strong',
          );
        },
      );

      expect(
        visited,
        <ModelTier>[
          ModelTier.free,
          ModelTier.budget,
          ModelTier.performance,
        ],
      );
      expect(result.succeeded, isTrue);
      expect(result.escalated, isTrue);
      expect(result.initialTier, ModelTier.free);
      expect(result.finalTier, ModelTier.performance);
      expect(result.totalLatencyMs, 540);
      expect(result.escalations.length, 2);
      expect(result.escalations[0].reason, EscalationReason.timeout);
      expect(result.escalations[1].reason, EscalationReason.lowConfidence);
      expect(result.output, 'strong');
    });

    test('getSummary records escalation rate and per-tier latency', () async {
      final service = TieredModelEscalationService();

      await service.routeWithEscalation(
        const TierRouteRequest(
          taskId: 'ok-1',
          difficulty: TaskDifficulty.standard,
        ),
        (tier, request) async => TierExecutionResult(
          tier: tier,
          success: true,
          latencyMs: 120,
          confidence: 0.9,
          output: 'ok',
        ),
      );

      final exhausted = await service.routeWithEscalation(
        const TierRouteRequest(
          taskId: 'fail-1',
          difficulty: TaskDifficulty.complex,
          maxTier: ModelTier.premium,
        ),
        (tier, request) async => TierExecutionResult(
          tier: tier,
          success: false,
          latencyMs: 200,
          reason: EscalationReason.rateLimited,
        ),
      );

      expect(exhausted.succeeded, isFalse);
      expect(exhausted.finalTier, ModelTier.premium);

      final summary = service.getSummary();
      expect(summary.totalRequests, 2);
      expect(summary.succeededRequests, 1);
      expect(summary.escalatedRequests, 1);
      expect(summary.escalationRate, 0.5);
      expect(summary.perTier[ModelTier.budget]?.averageLatencyMs, 120);
      expect(summary.perTier[ModelTier.performance]?.failures, 1);
      expect(summary.perTier[ModelTier.premium]?.failures, 1);
    });
  });
}

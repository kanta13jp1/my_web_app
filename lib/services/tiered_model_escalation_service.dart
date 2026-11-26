/// Model tiers for cost/latency/quality routing (#2784).
enum ModelTier {
  free('free', 'Free'),
  budget('budget', 'Budget'),
  performance('performance', 'Performance'),
  premium('premium', 'Premium');

  const ModelTier(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Task complexity levels mapped to default starting model tiers.
enum TaskDifficulty {
  trivial(ModelTier.free),
  standard(ModelTier.budget),
  complex(ModelTier.performance),
  critical(ModelTier.premium);

  const TaskDifficulty(this.defaultTier);

  final ModelTier defaultTier;
}

/// Reason a lower-tier attempt triggered escalation to a higher tier.
enum EscalationReason {
  providerError('provider_error'),
  timeout('timeout'),
  lowConfidence('low_confidence'),
  rateLimited('rate_limited');

  const EscalationReason(this.wireName);

  final String wireName;
}

/// Request specification for tiered model routing.
class TierRouteRequest {
  const TierRouteRequest({
    required this.taskId,
    required this.difficulty,
    this.minTier,
    this.maxTier = ModelTier.premium,
    this.minConfidence = 0.6,
    this.allowEscalation = true,
  });

  final String taskId;
  final TaskDifficulty difficulty;
  final ModelTier? minTier;
  final ModelTier maxTier;
  final double minConfidence;
  final bool allowEscalation;
}

/// Single execution attempt outcome returned by a tier executor.
class TierExecutionResult {
  const TierExecutionResult({
    required this.tier,
    required this.success,
    required this.latencyMs,
    this.confidence,
    this.reason,
    this.output,
  });

  final ModelTier tier;
  final bool success;
  final int latencyMs;
  final double? confidence;
  final EscalationReason? reason;
  final String? output;
}

/// Recorded escalation transition between two adjacent tiers.
class EscalationTransition {
  const EscalationTransition({
    required this.fromTier,
    required this.toTier,
    required this.reason,
    required this.latencyMs,
  });

  final ModelTier fromTier;
  final ModelTier toTier;
  final EscalationReason reason;
  final int latencyMs;
}

/// Final outcome of a tiered routing + escalation execution.
class TieredRouteResult {
  const TieredRouteResult({
    required this.taskId,
    required this.initialTier,
    required this.finalTier,
    required this.succeeded,
    required this.escalated,
    required this.attempts,
    required this.escalations,
    required this.totalLatencyMs,
    this.output,
  });

  final String taskId;
  final ModelTier initialTier;
  final ModelTier finalTier;
  final bool succeeded;
  final bool escalated;
  final List<TierExecutionResult> attempts;
  final List<EscalationTransition> escalations;
  final int totalLatencyMs;
  final String? output;
}

/// Per-tier routing and latency counters.
class TierMetricsSnapshot {
  const TierMetricsSnapshot({
    this.requestsStarted = 0,
    this.attempts = 0,
    this.successes = 0,
    this.failures = 0,
    this.totalLatencyMs = 0,
  });

  final int requestsStarted;
  final int attempts;
  final int successes;
  final int failures;
  final int totalLatencyMs;

  double get averageLatencyMs {
    if (attempts == 0) {
      return 0;
    }
    return totalLatencyMs / attempts;
  }

  TierMetricsSnapshot copyWith({
    int? requestsStarted,
    int? attempts,
    int? successes,
    int? failures,
    int? totalLatencyMs,
  }) {
    return TierMetricsSnapshot(
      requestsStarted: requestsStarted ?? this.requestsStarted,
      attempts: attempts ?? this.attempts,
      successes: successes ?? this.successes,
      failures: failures ?? this.failures,
      totalLatencyMs: totalLatencyMs ?? this.totalLatencyMs,
    );
  }
}

/// Aggregated routing and escalation telemetry across all tiers.
class TieredEscalationSummary {
  const TieredEscalationSummary({
    required this.totalRequests,
    required this.succeededRequests,
    required this.escalatedRequests,
    required this.escalationRate,
    required this.perTier,
  });

  final int totalRequests;
  final int succeededRequests;
  final int escalatedRequests;
  final double escalationRate;
  final Map<ModelTier, TierMetricsSnapshot> perTier;
}

typedef TierExecutor = Future<TierExecutionResult> Function(
  ModelTier tier,
  TierRouteRequest request,
);

/// Routes requests across Free -> Budget -> Performance -> Premium tiers
/// with automatic escalation on failure or low confidence.
class TieredModelEscalationService {
  int _totalRequests = 0;
  int _succeededRequests = 0;
  int _escalatedRequests = 0;

  final Map<ModelTier, TierMetricsSnapshot> _perTier =
      <ModelTier, TierMetricsSnapshot>{
    ModelTier.free: const TierMetricsSnapshot(),
    ModelTier.budget: const TierMetricsSnapshot(),
    ModelTier.performance: const TierMetricsSnapshot(),
    ModelTier.premium: const TierMetricsSnapshot(),
  };

  /// Selects the initial tier for [request] clamped by minTier and maxTier.
  ModelTier selectInitialTier(TierRouteRequest request) {
    var idx = request.difficulty.defaultTier.index;
    final minTier = request.minTier;
    if (minTier != null && idx < minTier.index) {
      idx = minTier.index;
    }
    if (idx > request.maxTier.index) {
      idx = request.maxTier.index;
    }
    return ModelTier.values[idx];
  }

  /// Returns the next higher tier up to [maxTier], or null if exhausted.
  ModelTier? resolveNextTier(
    ModelTier current, {
    ModelTier maxTier = ModelTier.premium,
  }) {
    final nextIdx = current.index + 1;
    if (nextIdx >= ModelTier.values.length || nextIdx > maxTier.index) {
      return null;
    }
    return ModelTier.values[nextIdx];
  }

  /// Executes [request] starting at its mapped tier and escalating on failure.
  Future<TieredRouteResult> routeWithEscalation(
    TierRouteRequest request,
    TierExecutor executor,
  ) async {
    final initialTier = selectInitialTier(request);
    _totalRequests += 1;
    _recordStart(initialTier);

    final attempts = <TierExecutionResult>[];
    final escalations = <EscalationTransition>[];
    ModelTier? currentTier = initialTier;
    var totalLatencyMs = 0;

    while (currentTier != null) {
      final outcome = await executor(currentTier, request);
      final boundedLatency = outcome.latencyMs < 0 ? 0 : outcome.latencyMs;
      totalLatencyMs += boundedLatency;
      attempts.add(
        TierExecutionResult(
          tier: outcome.tier,
          success: outcome.success,
          latencyMs: boundedLatency,
          confidence: outcome.confidence,
          reason: outcome.reason,
          output: outcome.output,
        ),
      );

      final failureReason = _classifyFailure(outcome, request.minConfidence);
      if (failureReason == null) {
        _recordAttempt(currentTier, true, boundedLatency);
        _succeededRequests += 1;
        if (escalations.isNotEmpty) {
          _escalatedRequests += 1;
        }
        return TieredRouteResult(
          taskId: request.taskId,
          initialTier: initialTier,
          finalTier: currentTier,
          succeeded: true,
          escalated: escalations.isNotEmpty,
          attempts: attempts,
          escalations: escalations,
          totalLatencyMs: totalLatencyMs,
          output: outcome.output,
        );
      }

      _recordAttempt(currentTier, false, boundedLatency);
      if (!request.allowEscalation) {
        break;
      }

      final nextTier = resolveNextTier(
        currentTier,
        maxTier: request.maxTier,
      );
      if (nextTier == null) {
        break;
      }
      escalations.add(
        EscalationTransition(
          fromTier: currentTier,
          toTier: nextTier,
          reason: failureReason,
          latencyMs: boundedLatency,
        ),
      );
      currentTier = nextTier;
    }

    if (escalations.isNotEmpty) {
      _escalatedRequests += 1;
    }

    final lastTier = attempts.isEmpty ? initialTier : attempts.last.tier;
    return TieredRouteResult(
      taskId: request.taskId,
      initialTier: initialTier,
      finalTier: lastTier,
      succeeded: false,
      escalated: escalations.isNotEmpty,
      attempts: attempts,
      escalations: escalations,
      totalLatencyMs: totalLatencyMs,
    );
  }

  /// Returns an immutable snapshot of routing and escalation telemetry.
  TieredEscalationSummary getSummary() {
    final rate =
        _totalRequests == 0 ? 0.0 : _escalatedRequests / _totalRequests;
    return TieredEscalationSummary(
      totalRequests: _totalRequests,
      succeededRequests: _succeededRequests,
      escalatedRequests: _escalatedRequests,
      escalationRate: rate,
      perTier: Map<ModelTier, TierMetricsSnapshot>.unmodifiable(_perTier),
    );
  }

  EscalationReason? _classifyFailure(
    TierExecutionResult outcome,
    double minConfidence,
  ) {
    if (!outcome.success) {
      return outcome.reason ?? EscalationReason.providerError;
    }
    final confidence = outcome.confidence;
    if (confidence != null && confidence < minConfidence) {
      return EscalationReason.lowConfidence;
    }
    return null;
  }

  void _recordStart(ModelTier tier) {
    final cur = _perTier[tier] ?? const TierMetricsSnapshot();
    _perTier[tier] = cur.copyWith(requestsStarted: cur.requestsStarted + 1);
  }

  void _recordAttempt(ModelTier tier, bool succeeded, int latencyMs) {
    final cur = _perTier[tier] ?? const TierMetricsSnapshot();
    _perTier[tier] = cur.copyWith(
      attempts: cur.attempts + 1,
      successes: cur.successes + (succeeded ? 1 : 0),
      failures: cur.failures + (succeeded ? 0 : 1),
      totalLatencyMs: cur.totalLatencyMs + latencyMs,
    );
  }
}

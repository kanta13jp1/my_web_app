/// Event kind logged for AI-generated UI action proposals (#2794).
enum EngagementEventKind {
  impression('impression', 'Impression'),
  click('click', 'Click');

  const EngagementEventKind(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Paired event linking an actionType and its LLM-generated UI label.
class ToolEngagementEvent {
  const ToolEngagementEvent({
    required this.actionType,
    required this.generatedLabel,
    required this.eventKind,
  });

  final String actionType;
  final String generatedLabel;
  final EngagementEventKind eventKind;

  Map<String, String> toPayload() {
    return <String, String>{
      'action_type': actionType,
      'generated_label': generatedLabel,
      'event_kind': eventKind.wireName,
    };
  }
}

/// Aggregated CTR metric for a single (actionType, generatedLabel) pair.
class ToolCtrMetric {
  const ToolCtrMetric({
    required this.actionType,
    required this.generatedLabel,
    required this.impressions,
    required this.clicks,
    required this.ctr,
  });

  final String actionType;
  final String generatedLabel;
  final int impressions;
  final int clicks;
  final double ctr;
}

/// Low-engagement action candidate recommended for LLM schema pruning.
class SchemaPruningCandidate {
  const SchemaPruningCandidate({
    required this.actionType,
    required this.generatedLabel,
    required this.impressions,
    required this.clicks,
    required this.ctr,
  });

  final String actionType;
  final String generatedLabel;
  final int impressions;
  final int clicks;
  final double ctr;
}

/// Schema-pruning report produced from engagement CTR correlation.
class SchemaPruningReport {
  const SchemaPruningReport({
    required this.minImpressions,
    required this.minCtrThreshold,
    required this.totalPairs,
    required this.prunedActionTypes,
    required this.candidates,
  });

  final int minImpressions;
  final double minCtrThreshold;
  final int totalPairs;
  final List<String> prunedActionTypes;
  final List<SchemaPruningCandidate> candidates;
}

typedef EngagementEventSink = Future<void> Function(
  ToolEngagementEvent event,
);

class _PairAccumulator {
  _PairAccumulator({
    required this.actionType,
    required this.generatedLabel,
  });

  final String actionType;
  final String generatedLabel;
  int impressions = 0;
  int clicks = 0;
}

/// Logs LLM-proposed UI button impressions/clicks and computes CTR pruning.
class LlmToolEngagementService {
  LlmToolEngagementService({EngagementEventSink? sink}) : _sink = sink;

  final EngagementEventSink? _sink;
  final Map<String, _PairAccumulator> _accumulators =
      <String, _PairAccumulator>{};

  /// Records an impression or click event and forwards it to [_sink] if set.
  Future<void> logEvent(ToolEngagementEvent event) async {
    final actionType = event.actionType.trim();
    final generatedLabel = event.generatedLabel.trim();
    if (actionType.isEmpty || generatedLabel.isEmpty) {
      throw ArgumentError(
        'actionType and generatedLabel must be non-empty.',
      );
    }

    final key = '$actionType\u0000$generatedLabel';
    final acc = _accumulators.putIfAbsent(
      key,
      () => _PairAccumulator(
        actionType: actionType,
        generatedLabel: generatedLabel,
      ),
    );
    if (event.eventKind == EngagementEventKind.impression) {
      acc.impressions += 1;
    } else {
      acc.clicks += 1;
    }

    final sink = _sink;
    if (sink != null) {
      await sink(
        ToolEngagementEvent(
          actionType: actionType,
          generatedLabel: generatedLabel,
          eventKind: event.eventKind,
        ),
      );
    }
  }

  /// Computes CTR per (actionType, generatedLabel) pair.
  List<ToolCtrMetric> computeCtrMetrics() {
    final results = <ToolCtrMetric>[];
    for (final acc in _accumulators.values) {
      final ctr = acc.impressions <= 0
          ? 0.0
          : (acc.clicks.clamp(0, acc.impressions) / acc.impressions);
      results.add(
        ToolCtrMetric(
          actionType: acc.actionType,
          generatedLabel: acc.generatedLabel,
          impressions: acc.impressions,
          clicks: acc.clicks,
          ctr: ctr,
        ),
      );
    }
    results.sort((ToolCtrMetric a, ToolCtrMetric b) {
      final byAction = a.actionType.compareTo(b.actionType);
      if (byAction != 0) {
        return byAction;
      }
      return a.generatedLabel.compareTo(b.generatedLabel);
    });
    return List<ToolCtrMetric>.unmodifiable(results);
  }

  /// Identifies low-CTR actions to exclude from future LLM tool schemas.
  SchemaPruningReport buildPruningReport({
    int minImpressions = 20,
    double minCtrThreshold = 0.02,
  }) {
    final metrics = computeCtrMetrics();
    final candidates = <SchemaPruningCandidate>[];
    final prunedActions = <String>{};

    for (final item in metrics) {
      if (item.impressions >= minImpressions && item.ctr < minCtrThreshold) {
        prunedActions.add(item.actionType);
        candidates.add(
          SchemaPruningCandidate(
            actionType: item.actionType,
            generatedLabel: item.generatedLabel,
            impressions: item.impressions,
            clicks: item.clicks,
            ctr: item.ctr,
          ),
        );
      }
    }

    final sortedActions = prunedActions.toList()..sort();
    return SchemaPruningReport(
      minImpressions: minImpressions,
      minCtrThreshold: minCtrThreshold,
      totalPairs: metrics.length,
      prunedActionTypes: List<String>.unmodifiable(sortedActions),
      candidates: List<SchemaPruningCandidate>.unmodifiable(candidates),
    );
  }
}

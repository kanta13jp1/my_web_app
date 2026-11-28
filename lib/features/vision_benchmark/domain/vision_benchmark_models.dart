/// Default alert threshold score (0-100) for Vision benchmark runs.
const int kDefaultVisionBenchmarkThreshold = 70;

/// Single stage/level inside a 6-stage Vision benchmark run (#2758).
class VisionBenchmarkLevel {
  const VisionBenchmarkLevel({
    required this.level,
    required this.description,
    required this.passed,
    required this.score,
    required this.maxPoints,
    required this.latencyMs,
    this.response = '',
  });

  final String level;
  final String description;
  final bool passed;
  final int score;
  final int maxPoints;
  final int latencyMs;
  final String response;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'level': level,
      'description': description,
      'passed': passed,
      'score': score,
      'maxPoints': maxPoints,
      'latency': latencyMs,
      'response': response,
    };
  }
}

/// Persisted Vision benchmark run from `app-hub` (`vision_benchmark_run`).
class VisionBenchmarkRun {
  const VisionBenchmarkRun({
    required this.id,
    required this.model,
    required this.provider,
    required this.score,
    required this.latencyMs,
    required this.threshold,
    required this.passed,
    required this.detail,
    required this.levels,
    required this.recordedAt,
  });

  final String id;
  final String model;
  final String provider;
  final int score;
  final int latencyMs;
  final int threshold;
  final bool passed;
  final String detail;
  final List<VisionBenchmarkLevel> levels;
  final DateTime recordedAt;

  bool isBelowThreshold(final int activeThreshold) => score < activeThreshold;
}

/// Per-model latest benchmark summary with delta vs previous run.
class VisionModelSummary {
  const VisionModelSummary({
    required this.model,
    required this.provider,
    required this.latestScore,
    required this.previousScore,
    required this.runCount,
    required this.belowThreshold,
    required this.latestRecordedAt,
  });

  final String model;
  final String provider;
  final int latestScore;
  final int? previousScore;
  final int runCount;
  final bool belowThreshold;
  final DateTime latestRecordedAt;

  int? get delta => previousScore == null ? null : latestScore - previousScore!;
}

/// Complete snapshot rendered by the Vision monitoring dashboard (#2758).
class VisionBenchmarkSnapshot {
  const VisionBenchmarkSnapshot({
    required this.runs,
    required this.threshold,
    required this.modelSummaries,
    required this.averageScore,
  });

  final List<VisionBenchmarkRun> runs;
  final int threshold;
  final List<VisionModelSummary> modelSummaries;
  final double averageScore;

  List<VisionModelSummary> get alertModels => modelSummaries
      .where((final VisionModelSummary item) => item.belowThreshold)
      .toList(growable: false);

  List<VisionBenchmarkRun> get alertRuns => runs
      .where((final VisionBenchmarkRun run) => run.isBelowThreshold(threshold))
      .toList(growable: false);

  /// Computes deterministic summaries and threshold flags from raw [runs].
  static VisionBenchmarkSnapshot build({
    required final List<VisionBenchmarkRun> runs,
    required final int threshold,
  }) {
    final normalizedThreshold = threshold.clamp(1, 100);
    final sorted = List<VisionBenchmarkRun>.from(runs)
      ..sort(
        (final VisionBenchmarkRun a, final VisionBenchmarkRun b) =>
            b.recordedAt.compareTo(a.recordedAt),
      );
    final grouped = <String, List<VisionBenchmarkRun>>{};
    var scoreSum = 0;
    for (final run in sorted) {
      scoreSum += run.score;
      grouped.putIfAbsent(run.model, () => <VisionBenchmarkRun>[]).add(run);
    }

    final summaries = <VisionModelSummary>[];
    for (final entry in grouped.entries) {
      final list = entry.value;
      final latest = list.first;
      final previous = list.length > 1 ? list[1].score : null;
      summaries.add(
        VisionModelSummary(
          model: entry.key,
          provider: latest.provider,
          latestScore: latest.score,
          previousScore: previous,
          runCount: list.length,
          belowThreshold: latest.score < normalizedThreshold,
          latestRecordedAt: latest.recordedAt,
        ),
      );
    }

    summaries.sort((final VisionModelSummary a, final VisionModelSummary b) {
      final alertCompare = (b.belowThreshold ? 1 : 0).compareTo(
        a.belowThreshold ? 1 : 0,
      );
      if (alertCompare != 0) return alertCompare;
      return a.latestScore.compareTo(b.latestScore);
    });

    final avg = sorted.isEmpty
        ? 0.0
        : double.parse((scoreSum / sorted.length).toStringAsFixed(1));
    return VisionBenchmarkSnapshot(
      runs: List<VisionBenchmarkRun>.unmodifiable(sorted),
      threshold: normalizedThreshold,
      modelSummaries: List<VisionModelSummary>.unmodifiable(summaries),
      averageScore: avg,
    );
  }
}

/// Abstract gateway for reading and recording Vision benchmark runs (#2758).
abstract interface class VisionBenchmarkRepository {
  Future<VisionBenchmarkSnapshot> fetchDashboard({
    required int threshold,
    String? modelFilter,
    int limit = 40,
  });

  Future<VisionBenchmarkRun> recordRun({
    required String model,
    required String provider,
    required int score,
    required int latencyMs,
    required int threshold,
    required bool passed,
    required String detail,
    List<VisionBenchmarkLevel> levels = const <VisionBenchmarkLevel>[],
  });
}

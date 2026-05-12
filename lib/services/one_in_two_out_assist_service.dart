class WidgetUsageSignal {
  const WidgetUsageSignal({
    required this.id,
    required this.title,
    required this.sectionId,
    required this.openCount,
    required this.lastUsedAt,
    this.routePath,
    this.isPinned = false,
    this.isVisible = true,
  });

  final String id;
  final String title;
  final String sectionId;
  final String? routePath;
  final int openCount;
  final DateTime? lastUsedAt;
  final bool isPinned;
  final bool isVisible;
}

class OneInTwoOutRemovalCandidate {
  const OneInTwoOutRemovalCandidate({
    required this.signal,
    required this.staleDays,
    required this.score,
    required this.reason,
  });

  final WidgetUsageSignal signal;
  final int staleDays;
  final double score;
  final String reason;
}

class OneInTwoOutSuggestion {
  const OneInTwoOutSuggestion({
    required this.incomingWidgetId,
    required this.incomingWidgetTitle,
    required this.generatedAt,
    required this.candidates,
    this.canSkip = true,
    this.canOptOut = true,
  });

  final String incomingWidgetId;
  final String incomingWidgetTitle;
  final DateTime generatedAt;
  final List<OneInTwoOutRemovalCandidate> candidates;
  final bool canSkip;
  final bool canOptOut;

  bool get hasTwoCandidates => candidates.length >= 2;
}

class OneInTwoOutAssistService {
  const OneInTwoOutAssistService();

  OneInTwoOutSuggestion buildSuggestion({
    required String incomingWidgetId,
    required String incomingWidgetTitle,
    required Iterable<WidgetUsageSignal> existingWidgets,
    DateTime? now,
    int candidateCount = 2,
  }) {
    final generatedAt = now ?? DateTime.now();
    final ranked = existingWidgets
        .where(
          (signal) =>
              signal.id != incomingWidgetId &&
              signal.isVisible &&
              !signal.isPinned,
        )
        .map((signal) => _rank(signal, generatedAt))
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.signal.title.compareTo(b.signal.title);
      });

    return OneInTwoOutSuggestion(
      incomingWidgetId: incomingWidgetId,
      incomingWidgetTitle: incomingWidgetTitle,
      generatedAt: generatedAt,
      candidates: ranked.take(candidateCount).toList(growable: false),
    );
  }

  OneInTwoOutRemovalCandidate _rank(
    WidgetUsageSignal signal,
    DateTime now,
  ) {
    final lastUsedAt = signal.lastUsedAt;
    final staleDays = lastUsedAt == null
        ? 999
        : now.difference(lastUsedAt).inDays.clamp(0, 999);
    final lowFrequencyBonus = (10 - signal.openCount.clamp(0, 10)) * 4.0;
    final neverUsedBonus = lastUsedAt == null ? 40.0 : 0.0;
    final score = staleDays + lowFrequencyBonus + neverUsedBonus;
    final reason = lastUsedAt == null
        ? '利用履歴なし / 利用${signal.openCount}回'
        : '$staleDays日未使用 / 利用${signal.openCount}回';

    return OneInTwoOutRemovalCandidate(
      signal: signal,
      staleDays: staleDays,
      score: score,
      reason: reason,
    );
  }
}

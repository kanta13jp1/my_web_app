import 'dart:math' as math;

class FsrsCardState {
  const FsrsCardState({
    required this.questionId,
    required this.provider,
    required this.dueDate,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.reps = 0,
    this.lapses = 0,
    this.state = 'new',
    this.lastReview,
    this.lastElapsedMs,
    this.totalReviews = 0,
    this.totalCorrect = 0,
  });

  final String questionId;
  final String provider;
  final DateTime dueDate;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final String state;
  final DateTime? lastReview;
  final int? lastElapsedMs;
  final int totalReviews;
  final int totalCorrect;

  FsrsCardState copyWith({
    DateTime? dueDate,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    String? state,
    DateTime? lastReview,
    int? lastElapsedMs,
    int? totalReviews,
    int? totalCorrect,
  }) {
    return FsrsCardState(
      questionId: questionId,
      provider: provider,
      dueDate: dueDate ?? this.dueDate,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      lastReview: lastReview ?? this.lastReview,
      lastElapsedMs: lastElapsedMs ?? this.lastElapsedMs,
      totalReviews: totalReviews ?? this.totalReviews,
      totalCorrect: totalCorrect ?? this.totalCorrect,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question_id': questionId,
      'provider': provider,
      'due_date': dueDate.toUtc().toIso8601String(),
      'stability': stability,
      'difficulty': difficulty,
      'reps': reps,
      'lapses': lapses,
      'state': state,
      if (lastReview != null)
        'last_review': lastReview!.toUtc().toIso8601String(),
      if (lastElapsedMs != null) 'last_elapsed_ms': lastElapsedMs,
      'total_reviews': totalReviews,
      'total_correct': totalCorrect,
    };
  }
}

class FsrsReviewOutcome {
  const FsrsReviewOutcome({
    required this.nextCard,
    required this.nextDue,
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.scheduledDays,
    required this.isCorrect,
    this.elapsedMs,
  });

  final FsrsCardState nextCard;
  final DateTime nextDue;
  final double stability;
  final double difficulty;
  final double retrievability;
  final int scheduledDays;
  final bool isCorrect;
  final int? elapsedMs;
}

class FsrsScheduler {
  // Power-law decay constant from FSRS-4.5 where R(S, S) == 0.90.
  static const double _decayFactor = 19.0 / 81.0;

  static int normalizeGrade(int grade) {
    if (grade < 1) return 1;
    if (grade > 4) return 4;
    return grade;
  }

  static double computeRetrievability({
    required double elapsedDays,
    required double stability,
  }) {
    if (elapsedDays <= 0 || stability <= 0) {
      return 1.0;
    }
    final base = 1.0 + _decayFactor * (elapsedDays / stability);
    return math.pow(base, -0.5).toDouble().clamp(0.0, 1.0);
  }

  static FsrsReviewOutcome scheduleNext(
    FsrsCardState card, {
    required int grade,
    int? elapsedMs,
    bool? isCorrect,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final g = normalizeGrade(grade);
    final correct = isCorrect ?? (g >= 2);

    final elapsedSinceLastDays = card.lastReview == null
        ? 0.0
        : math.max(
            0.0,
            timestamp.difference(card.lastReview!.toUtc()).inHours / 24.0,
          );
    final r = computeRetrievability(
      elapsedDays: elapsedSinceLastDays,
      stability: math.max(0.4, card.stability),
    );

    // Mean-reverting FSRS difficulty update clamped to [1.0, 10.0].
    final rawDelta = -(g - 3) * 0.72;
    final nextDifficulty =
        (card.difficulty + rawDelta + 0.08 * (5.0 - card.difficulty))
            .clamp(1.0, 10.0);

    // Optional response-time speed adjustment: fast accurate recall boosts stability slightly.
    final speedFactor = elapsedMs == null
        ? 1.0
        : !correct
            ? 0.95
            : elapsedMs <= 4000
                ? 1.10
                : elapsedMs >= 20000
                    ? 0.90
                    : 1.0;

    late final double nextStability;
    late final int scheduledDays;
    late final String nextState;
    late final int nextLapses;

    if (g == 1 || !correct) {
      final decayed = math.max(
          0.4, card.stability * 0.35 * math.exp(-0.08 * nextDifficulty));
      nextStability = double.parse(decayed.toStringAsFixed(4));
      scheduledDays = 1;
      nextState = 'relearning';
      nextLapses = card.lapses + 1;
    } else {
      final gradeMultiplier = switch (g) {
        2 => 0.80,
        3 => 1.0,
        4 => 1.35,
        _ => 1.0,
      };
      final difficultyGain = 1.0 + ((11.0 - nextDifficulty) * 0.09);
      final forgettingGain = 1.0 + (math.exp(0.9 * (1.0 - r)) - 1.0) * 0.6;
      final baseS = math.max(0.5, card.stability);
      final computed = baseS *
          (1.0 + 0.35 * gradeMultiplier * difficultyGain * forgettingGain) *
          speedFactor;
      nextStability =
          double.parse(computed.clamp(0.5, 3650.0).toStringAsFixed(4));
      final intervalRaw = nextStability * (g == 4 ? 1.2 : 1.0);
      scheduledDays = math.max(1, intervalRaw.round());
      nextState = card.reps + 1 >= 2 ? 'review' : 'learning';
      nextLapses = card.lapses;
    }

    final nextDue = timestamp.add(Duration(days: scheduledDays));
    final updatedCard = card.copyWith(
      dueDate: nextDue,
      stability: nextStability,
      difficulty: double.parse(nextDifficulty.toStringAsFixed(4)),
      reps: card.reps + 1,
      lapses: nextLapses,
      state: nextState,
      lastReview: timestamp,
      lastElapsedMs: elapsedMs,
      totalReviews: card.totalReviews + 1,
      totalCorrect: card.totalCorrect + (correct ? 1 : 0),
    );

    return FsrsReviewOutcome(
      nextCard: updatedCard,
      nextDue: nextDue,
      stability: updatedCard.stability,
      difficulty: updatedCard.difficulty,
      retrievability: double.parse(r.toStringAsFixed(4)),
      scheduledDays: scheduledDays,
      isCorrect: correct,
      elapsedMs: elapsedMs,
    );
  }

  static List<FsrsCardState> sortPracticeQueue(
    List<FsrsCardState> cards, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final copy = List<FsrsCardState>.from(cards);
    copy.sort((a, b) {
      final aOverdue = !a.dueDate.toUtc().isAfter(reference);
      final bOverdue = !b.dueDate.toUtc().isAfter(reference);
      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }
      final dueCmp = a.dueDate.toUtc().compareTo(b.dueDate.toUtc());
      if (dueCmp != 0) {
        return dueCmp;
      }
      return b.difficulty.compareTo(a.difficulty);
    });
    return copy;
  }
}

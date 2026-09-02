import 'package:flutter/foundation.dart';

enum ToeicPart { part5, part6, part7 }

extension ToeicPartPresentation on ToeicPart {
  String get id => switch (this) {
        ToeicPart.part5 => 'part5',
        ToeicPart.part6 => 'part6',
        ToeicPart.part7 => 'part7',
      };

  String get label => switch (this) {
        ToeicPart.part5 => 'Part 5',
        ToeicPart.part6 => 'Part 6',
        ToeicPart.part7 => 'Part 7',
      };

  String get titleJa => switch (this) {
        ToeicPart.part5 => '短文穴埋め',
        ToeicPart.part6 => '長文穴埋め',
        ToeicPart.part7 => '読解問題',
      };

  String get description => switch (this) {
        ToeicPart.part5 => '文法と語彙を素早く見抜く',
        ToeicPart.part6 => '文脈に合う語句を選ぶ',
        ToeicPart.part7 => 'メールや案内文から要点を探す',
      };
}

ToeicPart toeicPartFromId(String id) {
  return ToeicPart.values.firstWhere(
    (part) => part.id == id,
    orElse: () => ToeicPart.part5,
  );
}

@immutable
class ToeicQuestion {
  const ToeicQuestion({
    required this.id,
    required this.part,
    required this.category,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
    this.passage,
  });

  final String id;
  final ToeicPart part;
  final String category;
  final String prompt;
  final List<String> choices;
  final int answerIndex;
  final String explanation;
  final String? passage;
}

@immutable
class ToeicProgress {
  const ToeicProgress({
    required this.targetScore,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.answeredByPart,
    required this.correctByPart,
    required this.practiceDateKeys,
  });

  factory ToeicProgress.initial() => const ToeicProgress(
        targetScore: 730,
        totalAnswered: 0,
        totalCorrect: 0,
        answeredByPart: <ToeicPart, int>{},
        correctByPart: <ToeicPart, int>{},
        practiceDateKeys: <String>{},
      );

  final int targetScore;
  final int totalAnswered;
  final int totalCorrect;
  final Map<ToeicPart, int> answeredByPart;
  final Map<ToeicPart, int> correctByPart;
  final Set<String> practiceDateKeys;

  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  double accuracyFor(ToeicPart part) {
    final answered = answeredByPart[part] ?? 0;
    return answered == 0 ? 0 : (correctByPart[part] ?? 0) / answered;
  }

  ToeicProgress copyWith({
    int? targetScore,
    int? totalAnswered,
    int? totalCorrect,
    Map<ToeicPart, int>? answeredByPart,
    Map<ToeicPart, int>? correctByPart,
    Set<String>? practiceDateKeys,
  }) {
    return ToeicProgress(
      targetScore: targetScore ?? this.targetScore,
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      answeredByPart: answeredByPart ?? this.answeredByPart,
      correctByPart: correctByPart ?? this.correctByPart,
      practiceDateKeys: practiceDateKeys ?? this.practiceDateKeys,
    );
  }
}

@immutable
class ToeicDashboardSnapshot {
  const ToeicDashboardSnapshot({
    required this.progress,
    required this.currentStreak,
    required this.todayCompleted,
    required this.recommendedPart,
  });

  final ToeicProgress progress;
  final int currentStreak;
  final bool todayCompleted;
  final ToeicPart recommendedPart;
}

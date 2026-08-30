class ToeicProgressModel {
  const ToeicProgressModel({
    required this.targetScore,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.answeredByPart,
    required this.correctByPart,
    required this.practiceDateKeys,
  });

  factory ToeicProgressModel.initial() => const ToeicProgressModel(
        targetScore: 730,
        totalAnswered: 0,
        totalCorrect: 0,
        answeredByPart: <String, int>{},
        correctByPart: <String, int>{},
        practiceDateKeys: <String>[],
      );

  factory ToeicProgressModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> readCounts(Object? raw) {
      if (raw is! Map) return const <String, int>{};
      return <String, int>{
        for (final entry in raw.entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      };
    }

    final rawDates = json['practice_date_keys'];
    return ToeicProgressModel(
      targetScore: (json['target_score'] as num?)?.toInt() ?? 730,
      totalAnswered: (json['total_answered'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      answeredByPart: readCounts(json['answered_by_part']),
      correctByPart: readCounts(json['correct_by_part']),
      practiceDateKeys: rawDates is List
          ? rawDates.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  final int targetScore;
  final int totalAnswered;
  final int totalCorrect;
  final Map<String, int> answeredByPart;
  final Map<String, int> correctByPart;
  final List<String> practiceDateKeys;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'target_score': targetScore,
        'total_answered': totalAnswered,
        'total_correct': totalCorrect,
        'answered_by_part': answeredByPart,
        'correct_by_part': correctByPart,
        'practice_date_keys': practiceDateKeys,
      };
}

/// CHRO をはじめとする AI 役員による実績解除時の個別評価記録 (#1406)。
class ChroAchievementEvaluation {
  final String id;
  final String achievementId;
  final String achievementTitle;
  final String executiveRole;
  final String message;
  final int pointsAwarded;
  final DateTime evaluatedAt;
  final String source;

  const ChroAchievementEvaluation({
    required this.id,
    required this.achievementId,
    required this.achievementTitle,
    required this.executiveRole,
    required this.message,
    required this.pointsAwarded,
    required this.evaluatedAt,
    required this.source,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'achievementId': achievementId,
        'achievementTitle': achievementTitle,
        'executiveRole': executiveRole,
        'message': message,
        'pointsAwarded': pointsAwarded,
        'evaluatedAt': evaluatedAt.toUtc().toIso8601String(),
        'source': source,
      };

  factory ChroAchievementEvaluation.fromJson(Map<String, dynamic> json) =>
      ChroAchievementEvaluation(
        id: json['id']?.toString() ?? '',
        achievementId: json['achievementId']?.toString() ?? '',
        achievementTitle: json['achievementTitle']?.toString() ?? '',
        executiveRole: json['executiveRole']?.toString() ?? 'CHRO',
        message: json['message']?.toString() ?? '',
        pointsAwarded: (json['pointsAwarded'] as num?)?.toInt() ?? 0,
        evaluatedAt: DateTime.tryParse(json['evaluatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        source: json['source']?.toString() ?? 'local',
      );
}

/// CHRO オフィス画面に表示する最新 AI 人事評価サマリー (#1406)。
class ChroEvaluationSummary {
  final int totalPoints;
  final int currentLevel;
  final String levelTitle;
  final int unlockedCount;
  final int totalCatalogCount;
  final ChroAchievementEvaluation? latestEvaluation;
  final String headline;
  final String nextRecommendedGoal;

  const ChroEvaluationSummary({
    required this.totalPoints,
    required this.currentLevel,
    required this.levelTitle,
    required this.unlockedCount,
    required this.totalCatalogCount,
    required this.latestEvaluation,
    required this.headline,
    required this.nextRecommendedGoal,
  });
}

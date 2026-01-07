class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconCode; // Store as string code point or asset path
  final dynamic
      icon; // For compatibility (can be IconData or whatever was used)
  final bool isUnlocked;
  final double progress;
  final int pointsReward;
  final int currentProgress;
  final int targetValue;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCode,
    this.icon,
    this.isUnlocked = false,
    this.progress = 0.0,
    this.pointsReward = 0,
    this.currentProgress = 0,
    this.targetValue = 100,
    this.unlockedAt,
  });

  // 互換性用ゲッター
  double get progressPercentage => progress; // 0.0 - 1.0
}

class AchievementCategory {
  final String id;
  final String name;
  final List<Achievement> achievements;

  AchievementCategory({
    required this.id,
    required this.name,
    required this.achievements,
  });
}

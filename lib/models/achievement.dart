class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconCode; // Store as string or int code
  final bool isUnlocked;
  final double progress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCode,
    this.isUnlocked = false,
    this.progress = 0.0,
  });
}

// 統計ページ等で使用されるカテゴリ定義
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

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int pointsReward;
  final AchievementCategory category;
  final int targetValue;
  bool isUnlocked;
  int currentProgress;
  DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointsReward,
    required this.category,
    required this.targetValue,
    this.isUnlocked = false,
    this.currentProgress = 0,
    this.unlockedAt,
  });

  double get progressPercentage =>
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'points_reward': pointsReward,
        'category': category.name,
        'target_value': targetValue,
        'is_unlocked': isUnlocked,
        'current_progress': currentProgress,
        'unlocked_at': unlockedAt?.toIso8601String(),
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        icon: json['icon'],
        pointsReward: json['points_reward'],
        category: AchievementCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => AchievementCategory.general,
        ),
        targetValue: json['target_value'],
        isUnlocked: json['is_unlocked'] ?? false,
        currentProgress: json['current_progress'] ?? 0,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'])
            : null,
      );

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? pointsReward,
    AchievementCategory? category,
    int? targetValue,
    bool? isUnlocked,
    int? currentProgress,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      pointsReward: pointsReward ?? this.pointsReward,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      currentProgress: currentProgress ?? this.currentProgress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

enum AchievementCategory {
  general,
  notes,
  categories,
  sharing,
  organization,
  streak,
}

// Predefined achievements
class AchievementDefinitions {
  static List<Achievement> getDefaultAchievements() => [
        // Notes achievements
        Achievement(
          id: 'first_note',
          title: '最初の一歩',
          description: '初めてのメモを作成する',
          icon: '📝',
          pointsReward: 10,
          category: AchievementCategory.notes,
          targetValue: 1,
        ),
        Achievement(
          id: 'note_creator_10',
          title: 'メモマスター',
          description: '10個のメモを作成する',
          icon: '📚',
          pointsReward: 50,
          category: AchievementCategory.notes,
          targetValue: 10,
        ),
        Achievement(
          id: 'note_creator_50',
          title: 'メモの達人',
          description: '50個のメモを作成する',
          icon: '🎓',
          pointsReward: 100,
          category: AchievementCategory.notes,
          targetValue: 50,
        ),
        Achievement(
          id: 'note_creator_100',
          title: 'メモの伝説',
          description: '100個のメモを作成する',
          icon: '🏆',
          pointsReward: 200,
          category: AchievementCategory.notes,
          targetValue: 100,
        ),

        // Category achievements
        Achievement(
          id: 'first_category',
          title: '整理整頓',
          description: '初めてのカテゴリを作成する',
          icon: '📁',
          pointsReward: 15,
          category: AchievementCategory.categories,
          targetValue: 1,
        ),
        Achievement(
          id: 'category_master',
          title: 'カテゴリマスター',
          description: '5個のカテゴリを作成する',
          icon: '🗂️',
          pointsReward: 75,
          category: AchievementCategory.categories,
          targetValue: 5,
        ),

        // Sharing achievements
        Achievement(
          id: 'first_share',
          title: 'シェア開始',
          description: '初めてメモを共有する',
          icon: '🔗',
          pointsReward: 20,
          category: AchievementCategory.sharing,
          targetValue: 1,
        ),
        Achievement(
          id: 'share_master',
          title: 'シェアマスター',
          description: '10個のメモを共有する',
          icon: '🌐',
          pointsReward: 100,
          category: AchievementCategory.sharing,
          targetValue: 10,
        ),

        // Organization achievements
        Achievement(
          id: 'first_favorite',
          title: 'お気に入り発見',
          description: '初めてメモをお気に入りに追加する',
          icon: '⭐',
          pointsReward: 10,
          category: AchievementCategory.organization,
          targetValue: 1,
        ),
        Achievement(
          id: 'first_reminder',
          title: 'リマインダー使い',
          description: 'リマインダーを設定する',
          icon: '⏰',
          pointsReward: 15,
          category: AchievementCategory.organization,
          targetValue: 1,
        ),
        Achievement(
          id: 'first_attachment',
          title: '添付ファイルマスター',
          description: '初めて添付ファイルを追加する',
          icon: '📎',
          pointsReward: 20,
          category: AchievementCategory.organization,
          targetValue: 1,
        ),

        // Streak achievements
        Achievement(
          id: 'streak_3',
          title: '3日連続',
          description: '3日連続でメモを作成する',
          icon: '🔥',
          pointsReward: 30,
          category: AchievementCategory.streak,
          targetValue: 3,
        ),
        Achievement(
          id: 'streak_7',
          title: '1週間連続',
          description: '7日連続でメモを作成する',
          icon: '🌟',
          pointsReward: 75,
          category: AchievementCategory.streak,
          targetValue: 7,
        ),
        Achievement(
          id: 'streak_30',
          title: '30日連続',
          description: '30日連続でメモを作成する',
          icon: '💎',
          pointsReward: 200,
          category: AchievementCategory.streak,
          targetValue: 30,
        ),
      ];
}

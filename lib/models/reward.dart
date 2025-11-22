class Reward {
  final String id;
  final String title;
  final String description;
  final String icon;
  final RewardType type;
  final int requiredLevel;
  final String? requiredAchievementId;
  final int? requiredPoints;
  bool isUnlocked;
  DateTime? unlockedAt;

  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    this.requiredLevel = 0,
    this.requiredAchievementId,
    this.requiredPoints,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'type': type.name,
        'required_level': requiredLevel,
        'required_achievement_id': requiredAchievementId,
        'required_points': requiredPoints,
        'is_unlocked': isUnlocked,
        'unlocked_at': unlockedAt?.toIso8601String(),
      };

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        icon: json['icon'],
        type: RewardType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => RewardType.theme,
        ),
        requiredLevel: json['required_level'] ?? 0,
        requiredAchievementId: json['required_achievement_id'],
        requiredPoints: json['required_points'],
        isUnlocked: json['is_unlocked'] ?? false,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'])
            : null,
      );

  Reward copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    RewardType? type,
    int? requiredLevel,
    String? requiredAchievementId,
    int? requiredPoints,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Reward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      requiredAchievementId:
          requiredAchievementId ?? this.requiredAchievementId,
      requiredPoints: requiredPoints ?? this.requiredPoints,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

enum RewardType {
  theme,
  icon,
  feature,
  badge,
}

// Predefined rewards
class RewardDefinitions {
  static List<Reward> getDefaultRewards() => [
        // Theme rewards
        Reward(
          id: 'theme_ocean',
          title: 'オーシャンテーマ',
          description: '涼しげな青のテーマ',
          icon: '🌊',
          type: RewardType.theme,
          requiredLevel: 5,
        ),
        Reward(
          id: 'theme_forest',
          title: 'フォレストテーマ',
          description: '落ち着いた緑のテーマ',
          icon: '🌲',
          type: RewardType.theme,
          requiredLevel: 10,
        ),
        Reward(
          id: 'theme_sunset',
          title: 'サンセットテーマ',
          description: '温かみのあるオレンジのテーマ',
          icon: '🌅',
          type: RewardType.theme,
          requiredLevel: 15,
        ),
        Reward(
          id: 'theme_galaxy',
          title: 'ギャラクシーテーマ',
          description: '神秘的な紫のテーマ',
          icon: '🌌',
          type: RewardType.theme,
          requiredLevel: 20,
        ),
        Reward(
          id: 'theme_cherry',
          title: 'チェリーブロッサムテーマ',
          description: '華やかな桜色のテーマ',
          icon: '🌸',
          type: RewardType.theme,
          requiredLevel: 30,
        ),
        Reward(
          id: 'theme_gold',
          title: 'ゴールドテーマ',
          description: '豪華な金色のテーマ',
          icon: '👑',
          type: RewardType.theme,
          requiredLevel: 50,
        ),

        // Badge rewards
        Reward(
          id: 'badge_beginner',
          title: '初心者バッジ',
          description: 'メモアプリを使い始めました',
          icon: '🔰',
          type: RewardType.badge,
          requiredLevel: 1,
        ),
        Reward(
          id: 'badge_writer',
          title: 'ライターバッジ',
          description: '多くのメモを作成しました',
          icon: '✍️',
          type: RewardType.badge,
          requiredAchievementId: 'note_creator_100',
        ),
        Reward(
          id: 'badge_organizer',
          title: 'オーガナイザーバッジ',
          description: 'カテゴリを使いこなしています',
          icon: '📂',
          type: RewardType.badge,
          requiredAchievementId: 'category_master',
        ),
        Reward(
          id: 'badge_sharer',
          title: 'シェアラーバッジ',
          description: '積極的に共有しています',
          icon: '🌐',
          type: RewardType.badge,
          requiredAchievementId: 'share_master',
        ),
        Reward(
          id: 'badge_consistent',
          title: '継続バッジ',
          description: '毎日欠かさず記録しています',
          icon: '🔥',
          type: RewardType.badge,
          requiredAchievementId: 'streak_30',
        ),
        Reward(
          id: 'badge_master',
          title: 'マスターバッジ',
          description: 'すべてを極めました',
          icon: '🏆',
          type: RewardType.badge,
          requiredLevel: 50,
          requiredPoints: 10000,
        ),

        // Feature rewards
        Reward(
          id: 'feature_advanced_search',
          title: '高度な検索',
          description: 'より詳細な検索が可能になります',
          icon: '🔍',
          type: RewardType.feature,
          requiredLevel: 3,
        ),
        Reward(
          id: 'feature_bulk_actions',
          title: '一括操作',
          description: '複数のメモを一度に操作できます',
          icon: '⚡',
          type: RewardType.feature,
          requiredLevel: 7,
        ),
        Reward(
          id: 'feature_custom_templates',
          title: 'カスタムテンプレート',
          description: '独自のメモテンプレートを作成できます',
          icon: '📋',
          type: RewardType.feature,
          requiredLevel: 12,
        ),
        Reward(
          id: 'feature_export',
          title: 'エクスポート機能',
          description: 'メモをPDFやMarkdownで出力できます',
          icon: '📤',
          type: RewardType.feature,
          requiredLevel: 15,
        ),
      ];
}

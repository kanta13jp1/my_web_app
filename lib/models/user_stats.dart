class UserStats {
  final String userId;
  int totalPoints;
  int currentLevel;
  int notesCreated;
  int categoriesCreated;
  int notesShared;
  int currentStreak;
  int longestStreak;
  DateTime? lastActivityDate;
  DateTime createdAt;
  DateTime updatedAt;

  UserStats({
    required this.userId,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.notesCreated = 0,
    this.categoriesCreated = 0,
    this.notesShared = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate level based on points
  static int calculateLevel(int points) {
    // Level formula: Level = sqrt(points / 100) + 1
    // Level 1: 0-99 points
    // Level 2: 100-399 points
    // Level 3: 400-899 points
    // etc.
    if (points < 100) return 1;
    return (points / 100).sqrt().floor() + 1;
  }

  // Calculate points needed for next level
  int get pointsForNextLevel {
    final nextLevel = currentLevel + 1;
    return ((nextLevel - 1) * (nextLevel - 1)) * 100;
  }

  // Calculate points needed in current level
  int get pointsForCurrentLevel {
    if (currentLevel <= 1) return 0;
    return ((currentLevel - 1) * (currentLevel - 1)) * 100;
  }

  // Progress to next level (0.0 to 1.0)
  double get levelProgress {
    final pointsInLevel = totalPoints - pointsForCurrentLevel;
    final pointsNeeded = pointsForNextLevel - pointsForCurrentLevel;
    return pointsNeeded > 0 ? (pointsInLevel / pointsNeeded).clamp(0.0, 1.0) : 0.0;
  }

  // Get level title
  String get levelTitle {
    if (currentLevel >= 20) return 'メモの神';
    if (currentLevel >= 15) return 'メモの達人';
    if (currentLevel >= 10) return 'メモマスター';
    if (currentLevel >= 5) return 'メモの使い手';
    if (currentLevel >= 3) return 'メモ学習者';
    return 'メモ初心者';
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'total_points': totalPoints,
        'current_level': currentLevel,
        'notes_created': notesCreated,
        'categories_created': categoriesCreated,
        'notes_shared': notesShared,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_activity_date': lastActivityDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        userId: json['user_id'],
        totalPoints: json['total_points'] ?? 0,
        currentLevel: json['current_level'] ?? 1,
        notesCreated: json['notes_created'] ?? 0,
        categoriesCreated: json['categories_created'] ?? 0,
        notesShared: json['notes_shared'] ?? 0,
        currentStreak: json['current_streak'] ?? 0,
        longestStreak: json['longest_streak'] ?? 0,
        lastActivityDate: json['last_activity_date'] != null
            ? DateTime.parse(json['last_activity_date'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  UserStats copyWith({
    String? userId,
    int? totalPoints,
    int? currentLevel,
    int? notesCreated,
    int? categoriesCreated,
    int? notesShared,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserStats(
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      currentLevel: currentLevel ?? this.currentLevel,
      notesCreated: notesCreated ?? this.notesCreated,
      categoriesCreated: categoriesCreated ?? this.categoriesCreated,
      notesShared: notesShared ?? this.notesShared,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserAchievement {
  final int? id;
  final String userId;
  final String achievementId;
  final int currentProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAchievement({
    this.id,
    required this.userId,
    required this.achievementId,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'achievement_id': achievementId,
        'current_progress': currentProgress,
        'is_unlocked': isUnlocked,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserAchievement.fromJson(Map<String, dynamic> json) => UserAchievement(
        id: json['id'],
        userId: json['user_id'],
        achievementId: json['achievement_id'],
        currentProgress: json['current_progress'] ?? 0,
        isUnlocked: json['is_unlocked'] ?? false,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
}

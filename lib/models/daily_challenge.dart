class DailyChallenge {
  final int id;
  final DateTime challengeDate;
  final String challengeType;
  final String challengeTitle;
  final String challengeDescription;
  final int targetValue;
  final int rewardPoints;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyChallenge({
    required this.id,
    required this.challengeDate,
    required this.challengeType,
    required this.challengeTitle,
    required this.challengeDescription,
    required this.targetValue,
    required this.rewardPoints,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'] as int,
      challengeDate: DateTime.parse(json['challenge_date'] as String),
      challengeType: json['challenge_type'] as String,
      challengeTitle: json['challenge_title'] as String,
      challengeDescription: json['challenge_description'] as String,
      targetValue: json['target_value'] as int,
      rewardPoints: json['reward_points'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenge_date': challengeDate.toIso8601String().split('T')[0],
      'challenge_type': challengeType,
      'challenge_title': challengeTitle,
      'challenge_description': challengeDescription,
      'target_value': targetValue,
      'reward_points': rewardPoints,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UserChallengeProgress {
  final int id;
  final String userId;
  final int challengeId;
  final int currentProgress;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserChallengeProgress({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.currentProgress,
    required this.isCompleted,
    this.completedAt,
    required this.rewardClaimed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserChallengeProgress.fromJson(Map<String, dynamic> json) {
    return UserChallengeProgress(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      challengeId: json['challenge_id'] as int,
      currentProgress: json['current_progress'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      rewardClaimed: json['reward_claimed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'challenge_id': challengeId,
      'current_progress': currentProgress,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'reward_claimed': rewardClaimed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DailyChallenge {
  final int id;
  final String challengeTitle;
  final String challengeDescription;
  final String challengeType;
  final int targetValue;
  final int rewardPoints;

  const DailyChallenge({
    required this.id,
    required this.challengeTitle,
    required this.challengeDescription,
    required this.challengeType,
    required this.targetValue,
    required this.rewardPoints,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'] as int,
      // SQLのエイリアス名と一致させます
      challengeTitle: json['title'] as String? ?? '',
      challengeDescription: json['description'] as String? ?? '',
      challengeType: json['challenge_type'] as String? ?? '',
      targetValue: json['target_value'] as int? ?? 1,
      rewardPoints: json['reward_points'] as int? ?? 0,
    );
  }
}

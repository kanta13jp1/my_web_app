class LeaderboardEntry {
  final String userId;
  final String? userName;
  final int totalPoints;
  final int currentLevel;
  final int notesCreated;
  final int currentStreak;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    this.userName,
    required this.totalPoints,
    required this.currentLevel,
    required this.notesCreated,
    required this.currentStreak,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      totalPoints: json['total_points'] as int,
      currentLevel: json['current_level'] as int,
      notesCreated: json['notes_created'] as int,
      currentStreak: json['current_streak'] as int,
      rank: rank,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'total_points': totalPoints,
        'current_level': currentLevel,
        'notes_created': notesCreated,
        'current_streak': currentStreak,
        'rank': rank,
      };
}

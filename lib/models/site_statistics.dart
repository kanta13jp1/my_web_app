class SiteStatistics {
  final int id;
  final DateTime statDate;
  final int totalUsers;
  final int newUsersToday;
  final int activeUsersToday;
  final int totalNotesCreated;
  final int totalShares;
  final int totalAchievementsUnlocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteStatistics({
    required this.id,
    required this.statDate,
    required this.totalUsers,
    required this.newUsersToday,
    required this.activeUsersToday,
    required this.totalNotesCreated,
    required this.totalShares,
    required this.totalAchievementsUnlocked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteStatistics.fromJson(Map<String, dynamic> json) {
    return SiteStatistics(
      id: json['id'] as int,
      statDate: DateTime.parse(json['stat_date'] as String),
      totalUsers: json['total_users'] as int? ?? 0,
      newUsersToday: json['new_users_today'] as int? ?? 0,
      activeUsersToday: json['active_users_today'] as int? ?? 0,
      totalNotesCreated: json['total_notes_created'] as int? ?? 0,
      totalShares: json['total_shares'] as int? ?? 0,
      totalAchievementsUnlocked:
          json['total_achievements_unlocked'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stat_date': statDate.toIso8601String(),
      'total_users': totalUsers,
      'new_users_today': newUsersToday,
      'active_users_today': activeUsersToday,
      'total_notes_created': totalNotesCreated,
      'total_shares': totalShares,
      'total_achievements_unlocked': totalAchievementsUnlocked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

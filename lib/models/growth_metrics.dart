class GrowthMetrics {
  final DateTime date;
  final int totalUsers;
  final int activeUsers;
  final int newUsers;
  final int totalNotes;
  final int notesCreatedToday;
  final int totalShares;
  final int sharesCreatedToday;
  final int onlineUsers;
  final int onlineGuests;

  GrowthMetrics({
    required this.date,
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsers,
    required this.totalNotes,
    required this.notesCreatedToday,
    required this.totalShares,
    required this.sharesCreatedToday,
    required this.onlineUsers,
    required this.onlineGuests,
  });

  factory GrowthMetrics.fromJson(Map<String, dynamic> json) {
    return GrowthMetrics(
      date: DateTime.parse(json['metric_date'] as String),
      totalUsers: json['total_users'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      newUsers: json['new_users'] as int? ?? 0,
      totalNotes: json['total_notes'] as int? ?? 0,
      notesCreatedToday: json['notes_created_today'] as int? ?? 0,
      totalShares: json['total_shares'] as int? ?? 0,
      sharesCreatedToday: json['shares_created_today'] as int? ?? 0,
      onlineUsers: json['online_users'] as int? ?? 0,
      onlineGuests: json['online_guests'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric_date': date.toIso8601String(),
      'total_users': totalUsers,
      'active_users': activeUsers,
      'new_users': newUsers,
      'total_notes': totalNotes,
      'notes_created_today': notesCreatedToday,
      'total_shares': totalShares,
      'shares_created_today': sharesCreatedToday,
      'online_users': onlineUsers,
      'online_guests': onlineGuests,
    };
  }

  @override
  String toString() {
    return 'GrowthMetrics(date: $date, totalUsers: $totalUsers, newUsers: $newUsers)';
  }
}

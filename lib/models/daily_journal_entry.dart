class DailyJournalEntry {
  const DailyJournalEntry({
    required this.id,
    required this.dateKey,
    required this.taskTitle,
    required this.summary,
    required this.completedAt,
    this.syncedToCloud = false,
  });

  final String id;
  final String dateKey;
  final String taskTitle;
  final String summary;
  final DateTime completedAt;
  final bool syncedToCloud;

  factory DailyJournalEntry.fromJson(Map<String, dynamic> json) {
    final completedRaw = json['completed_at']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(completedRaw) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return DailyJournalEntry(
      id: (json['id'] ?? '').toString(),
      dateKey: (json['date_key'] ?? '').toString(),
      taskTitle: (json['task_title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      completedAt: parsedDate,
      syncedToCloud: json['synced_to_cloud'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date_key': dateKey,
      'task_title': taskTitle,
      'summary': summary,
      'completed_at': completedAt.toUtc().toIso8601String(),
      'synced_to_cloud': syncedToCloud,
    };
  }
}

class UserStreakProfile {
  const UserStreakProfile({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletedTasks,
    required this.updatedAt,
    this.lastActiveDateKey,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalCompletedTasks;
  final String? lastActiveDateKey;
  final DateTime updatedAt;

  static UserStreakProfile empty({DateTime? now}) {
    return UserStreakProfile(
      currentStreak: 0,
      longestStreak: 0,
      totalCompletedTasks: 0,
      lastActiveDateKey: null,
      updatedAt: now ?? DateTime.now().toUtc(),
    );
  }

  factory UserStreakProfile.fromJson(Map<String, dynamic> json) {
    final rawLastKey = json['last_active_date_key']?.toString().trim() ?? '';
    final parsedUpdated =
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    return UserStreakProfile(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalCompletedTasks:
          (json['total_completed_tasks'] as num?)?.toInt() ?? 0,
      lastActiveDateKey: rawLastKey.isEmpty ? null : rawLastKey,
      updatedAt: parsedUpdated,
    );
  }

  Map<String, dynamic> toProfileJson() {
    return <String, dynamic>{
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_completed_tasks': totalCompletedTasks,
      'last_active_date_key': lastActiveDateKey,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

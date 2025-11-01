class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryId;
  final bool isFavorite;
  final DateTime? reminderDate;
  final bool isArchived;
  final DateTime? archivedAt;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.isFavorite = false,
    this.reminderDate,
    this.isArchived = false,
    this.archivedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      categoryId: json['category_id']?.toString(),
      isFavorite: json['is_favorite'] as bool? ?? false,
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String)
          : null,
      isArchived: json['is_archived'] as bool? ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'category_id': categoryId,
      'is_favorite': isFavorite,
      'reminder_date': reminderDate?.toIso8601String(),
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  // 期限切れかどうか
  bool get isOverdue {
    if (reminderDate == null) return false;
    return reminderDate!.isBefore(DateTime.now());
  }

  // 期限が近いかどうか（24時間以内）
  bool get isDueSoon {
    if (reminderDate == null) return false;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(hours: 24));
    return reminderDate!.isAfter(now) && reminderDate!.isBefore(tomorrow);
  }

  // 自動アーカイブ対象かどうか（期限切れから30日経過）
  bool get shouldAutoArchive {
    if (reminderDate == null || !isOverdue) return false;
    final daysSinceOverdue = DateTime.now().difference(reminderDate!).inDays;
    return daysSinceOverdue >= 30;
  }
}
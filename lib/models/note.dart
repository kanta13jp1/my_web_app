class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryId;
  final bool isFavorite;
  final DateTime? reminderDate;  // 追加

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.isFavorite = false,
    this.reminderDate,  // 追加
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'].toString(),
      userId: json['user_id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      categoryId: json['category_id']?.toString(),
      isFavorite: json['is_favorite'] ?? false,
      reminderDate: json['reminder_date'] != null  // 追加
          ? DateTime.parse(json['reminder_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
      'category_id': categoryId,
      'is_favorite': isFavorite,
      'reminder_date': reminderDate?.toIso8601String(),  // 追加
    };
  }

  // 期限切れかどうかを判定
  bool get isOverdue {
    if (reminderDate == null) return false;
    return reminderDate!.isBefore(DateTime.now());
  }

  // 期限が近いかどうかを判定（24時間以内）
  bool get isDueSoon {
    if (reminderDate == null) return false;
    final now = DateTime.now();
    final difference = reminderDate!.difference(now);
    return difference.inHours > 0 && difference.inHours <= 24;
  }
}
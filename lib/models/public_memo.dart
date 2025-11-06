class PublicMemo {
  final int id;
  final int noteId;
  final String userId;
  final String title;
  final String? content;
  final String? category;
  final int likeCount;
  final int viewCount;
  final bool isPublic;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PublicMemo({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.title,
    this.content,
    this.category,
    required this.likeCount,
    required this.viewCount,
    required this.isPublic,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PublicMemo.fromJson(Map<String, dynamic> json) {
    return PublicMemo(
      id: json['id'] as int,
      noteId: json['note_id'] as int,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      category: json['category'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'user_id': userId,
      'title': title,
      'content': content,
      'category': category,
      'like_count': likeCount,
      'view_count': viewCount,
      'is_public': isPublic,
      'published_at': publishedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

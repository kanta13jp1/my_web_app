class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryId;
  final bool isFavorite;  // 追加

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.isFavorite = false,  // 追加（デフォルトはfalse）
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
      isFavorite: json['is_favorite'] ?? false,  // 追加
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
      'category_id': categoryId,
      'is_favorite': isFavorite,  // 追加
    };
  }
}
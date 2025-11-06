class UserPresence {
  final int id;
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;
  final String? pagePath;
  final String sessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPresence({
    required this.id,
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
    this.pagePath,
    required this.sessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: DateTime.parse(json['last_seen'] as String),
      pagePath: json['page_path'] as String?,
      sessionId: json['session_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'is_online': isOnline,
      'last_seen': lastSeen.toIso8601String(),
      'page_path': pagePath,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

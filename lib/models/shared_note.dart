class SharedNote {
  final String id;
  final String noteId;
  final String shareToken;
  final String permission; // 'read' or 'write'
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int accessCount;
  final DateTime? lastAccessedAt;

  SharedNote({
    required this.id,
    required this.noteId,
    required this.shareToken,
    required this.permission,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.accessCount = 0,
    this.lastAccessedAt,
  });

  factory SharedNote.fromJson(Map<String, dynamic> json) {
    return SharedNote(
      id: json['id'].toString(),
      noteId: json['note_id'].toString(),
      shareToken: json['share_token'],
      permission: json['permission'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      accessCount: json['access_count'] ?? 0,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get canWrite => permission == 'write';
  bool get canOnlyRead => permission == 'read';
}
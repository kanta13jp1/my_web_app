/// ユーザープロフィールモデル
class UserProfile {
  final String userId;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? websiteUrl;
  final String? location;
  final String? twitterHandle;
  final String? githubHandle;
  final bool isPublic;

  // ✅ 追加: 死生観クロック用のフィールド
  final DateTime? birthDate;
  final int? targetDeathAge;
  final double? disposableTimeRatio;

  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.userId,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.websiteUrl,
    this.location,
    this.twitterHandle,
    this.githubHandle,
    this.isPublic = true,
    // ✅ 追加
    this.birthDate,
    this.targetDeathAge,
    this.disposableTimeRatio,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      location: json['location'] as String?,
      twitterHandle: json['twitter_handle'] as String?,
      githubHandle: json['github_handle'] as String?,
      isPublic: json['is_public'] as bool? ?? true,

      // ✅ 追加: JSONからのマッピング
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      targetDeathAge: json['target_death_age'] as int?,
      // 数値型は num として取得してから double に変換するのが安全
      disposableTimeRatio: (json['disposable_time_ratio'] as num?)?.toDouble(),

      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'website_url': websiteUrl,
      'location': location,
      'twitter_handle': twitterHandle,
      'github_handle': githubHandle,
      'is_public': isPublic,

      // ✅ 追加: JSONへの変換
      'birth_date': birthDate?.toIso8601String(),
      'target_death_age': targetDeathAge,
      'disposable_time_ratio': disposableTimeRatio,

      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? websiteUrl,
    String? location,
    String? twitterHandle,
    String? githubHandle,
    bool? isPublic,
    // ✅ 追加
    DateTime? birthDate,
    int? targetDeathAge,
    double? disposableTimeRatio,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      location: location ?? this.location,
      twitterHandle: twitterHandle ?? this.twitterHandle,
      githubHandle: githubHandle ?? this.githubHandle,
      isPublic: isPublic ?? this.isPublic,
      // ✅ 追加
      birthDate: birthDate ?? this.birthDate,
      targetDeathAge: targetDeathAge ?? this.targetDeathAge,
      disposableTimeRatio: disposableTimeRatio ?? this.disposableTimeRatio,

      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// フォロー情報
class UserFollow {
  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  UserFollow({
    required this.id,
    required this.followerId,
    required this.followingId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserFollow.fromJson(Map<String, dynamic> json) {
    return UserFollow(
      id: json['id'] as String,
      followerId: json['follower_id'] as String,
      followingId: json['following_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// メモコメント
class NoteComment {
  final String id;
  final String noteId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 追加情報
  String? userDisplayName;
  String? userAvatarUrl;

  NoteComment({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userDisplayName,
    this.userAvatarUrl,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NoteComment.fromJson(Map<String, dynamic> json) {
    return NoteComment(
      id: json['id'].toString(),
      noteId: json['note_id'].toString(),
      userId: json['user_id'].toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      userDisplayName: json['user_display_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// メモいいね
class NoteLike {
  final String id;
  final String noteId;
  final String userId;
  final DateTime createdAt;

  NoteLike({
    required this.id,
    required this.noteId,
    required this.userId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory NoteLike.fromJson(Map<String, dynamic> json) {
    return NoteLike(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

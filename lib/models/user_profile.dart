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
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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

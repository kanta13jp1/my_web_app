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
  final String? gender;
  final String? occupation;
  final double? annualIncome;
  final String? address;
  final String? education;
  final String? careerHistory;
  final String? hobbies;
  final String? alcoholUse;
  final String? smokingUse;
  final String? favoriteFoods;
  final bool isPublic;
  final bool voiceAiTrainingConsent;
  final DateTime? voiceAiConsentUpdatedAt;

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
    this.gender,
    this.occupation,
    this.annualIncome,
    this.address,
    this.education,
    this.careerHistory,
    this.hobbies,
    this.alcoholUse,
    this.smokingUse,
    this.favoriteFoods,
    this.isPublic = true,
    this.voiceAiTrainingConsent = false,
    this.voiceAiConsentUpdatedAt,
    // ✅ 追加
    this.birthDate,
    this.targetDeathAge,
    this.disposableTimeRatio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
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
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      annualIncome: (json['annual_income'] as num?)?.toDouble(),
      address: json['address'] as String?,
      education: json['education'] as String?,
      careerHistory: json['career_history'] as String?,
      hobbies: json['hobbies'] as String?,
      alcoholUse: json['alcohol_use'] as String?,
      smokingUse: json['smoking_use'] as String?,
      favoriteFoods: json['favorite_foods'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      voiceAiTrainingConsent:
          json['voice_ai_training_consent'] as bool? ?? false,
      voiceAiConsentUpdatedAt: json['voice_ai_consent_updated_at'] != null
          ? DateTime.parse(json['voice_ai_consent_updated_at'] as String)
          : null,

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
      'gender': gender,
      'occupation': occupation,
      'annual_income': annualIncome,
      'address': address,
      'education': education,
      'career_history': careerHistory,
      'hobbies': hobbies,
      'alcohol_use': alcoholUse,
      'smoking_use': smokingUse,
      'favorite_foods': favoriteFoods,
      'is_public': isPublic,
      'voice_ai_training_consent': voiceAiTrainingConsent,
      'voice_ai_consent_updated_at': voiceAiConsentUpdatedAt?.toIso8601String(),

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
    String? gender,
    String? occupation,
    double? annualIncome,
    String? address,
    String? education,
    String? careerHistory,
    String? hobbies,
    String? alcoholUse,
    String? smokingUse,
    String? favoriteFoods,
    bool? isPublic,
    bool? voiceAiTrainingConsent,
    DateTime? voiceAiConsentUpdatedAt,
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
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      annualIncome: annualIncome ?? this.annualIncome,
      address: address ?? this.address,
      education: education ?? this.education,
      careerHistory: careerHistory ?? this.careerHistory,
      hobbies: hobbies ?? this.hobbies,
      alcoholUse: alcoholUse ?? this.alcoholUse,
      smokingUse: smokingUse ?? this.smokingUse,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      isPublic: isPublic ?? this.isPublic,
      voiceAiTrainingConsent:
          voiceAiTrainingConsent ?? this.voiceAiTrainingConsent,
      voiceAiConsentUpdatedAt:
          voiceAiConsentUpdatedAt ?? this.voiceAiConsentUpdatedAt,
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
  }) : createdAt = createdAt ?? DateTime.now(),
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

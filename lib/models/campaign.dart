class Campaign {
  final String id;
  final String title;
  final String description;
  final String campaignType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Map<String, dynamic> rewards;
  final String? bannerImageUrl;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.campaignType,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.rewards,
    this.bannerImageUrl,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      campaignType: json['campaign_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: json['is_active'] as bool? ?? false,
      rewards: json['rewards'] as Map<String, dynamic>? ?? {},
      bannerImageUrl: json['banner_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'campaign_type': campaignType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'rewards': rewards,
      'banner_image_url': bannerImageUrl,
    };
  }

  /// キャンペーンが現在有効かどうか
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// 残り時間を取得
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) {
      return Duration.zero;
    }
    return endDate.difference(now);
  }

  /// 残り日数を取得
  int get daysRemaining {
    return timeRemaining.inDays;
  }

  /// デフォルトキャンペーン（サンプル）
  static Campaign createWelcomeCampaign() {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 7));

    return Campaign(
      id: 'welcome_2024',
      title: '🎉 新規登録キャンペーン',
      description: '期間限定！新規登録でボーナスポイント5倍！通常500pt → 2500pt',
      campaignType: 'registration_boost',
      startDate: now,
      endDate: endDate,
      isActive: true,
      rewards: {'points_multiplier': 5, 'base_points': 500},
    );
  }

  static Campaign createShareCampaign() {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14));

    return Campaign(
      id: 'share_boost_2024',
      title: '📱 シェアキャンペーン',
      description: 'SNSシェアでポイント5倍！通常10pt → 50pt',
      campaignType: 'share_boost',
      startDate: now,
      endDate: endDate,
      isActive: true,
      rewards: {'points_multiplier': 5, 'base_points': 10},
    );
  }

  static Campaign createReferralCampaign() {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));

    return Campaign(
      id: 'referral_2024',
      title: '👥 友達紹介キャンペーン',
      description: '友達を招待して両方に500ptプレゼント！通常100pt → 500pt',
      campaignType: 'referral_boost',
      startDate: now,
      endDate: endDate,
      isActive: true,
      rewards: {'points_multiplier': 5, 'base_points': 100},
    );
  }
}

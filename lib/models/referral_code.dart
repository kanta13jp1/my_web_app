class ReferralCode {
  final int id;
  final String userId;
  final String referralCode;
  final int totalReferrals;
  final int successfulReferrals;
  final int bonusPointsEarned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReferralCode({
    required this.id,
    required this.userId,
    required this.referralCode,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.bonusPointsEarned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReferralCode.fromJson(Map<String, dynamic> json) {
    return ReferralCode(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      referralCode: json['referral_code'] as String,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      successfulReferrals: json['successful_referrals'] as int? ?? 0,
      bonusPointsEarned: json['bonus_points_earned'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'referral_code': referralCode,
      'total_referrals': totalReferrals,
      'successful_referrals': successfulReferrals,
      'bonus_points_earned': bonusPointsEarned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

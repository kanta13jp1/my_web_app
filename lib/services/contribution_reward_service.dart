enum RewardTier {
  standard('standard', '一般メンバー', 0),
  contributor('contributor', '貢献コントリビューター', 100),
  curator('curator', 'ナレッジキュレーター', 400),
  steward('steward', 'コミュニティスチュワード', 1000);

  final String wireKey;
  final String labelJa;
  final int minPoints;

  const RewardTier(this.wireKey, this.labelJa, this.minPoints);

  static RewardTier fromPoints(int totalPoints) {
    if (totalPoints >= steward.minPoints) return RewardTier.steward;
    if (totalPoints >= curator.minPoints) return RewardTier.curator;
    if (totalPoints >= contributor.minPoints) return RewardTier.contributor;
    return RewardTier.standard;
  }
}

class ContributionPolicy {
  final Set<String> focusCategories;
  final double focusMultiplier;

  const ContributionPolicy({
    required this.focusCategories,
    this.focusMultiplier = ContributionRewardService.defaultFocusMultiplier,
  });

  ContributionPolicy copyWith({
    Set<String>? focusCategories,
    double? focusMultiplier,
  }) {
    return ContributionPolicy(
      focusCategories: focusCategories ?? this.focusCategories,
      focusMultiplier: focusMultiplier ?? this.focusMultiplier,
    );
  }
}

class ContributionRewardReceipt {
  final String userId;
  final String category;
  final int basePoints;
  final bool isFocusCategory;
  final double appliedMultiplier;
  final int awardedPoints;
  final int newTotalPoints;
  final RewardTier unlockedTier;

  const ContributionRewardReceipt({
    required this.userId,
    required this.category,
    required this.basePoints,
    required this.isFocusCategory,
    required this.appliedMultiplier,
    required this.awardedPoints,
    required this.newTotalPoints,
    required this.unlockedTier,
  });
}

/// Calculates focus-category 1.6x contribution rewards with inflation caps
/// and threshold-based tier unlocking.
class ContributionRewardService {
  static const double defaultFocusMultiplier = 1.6;
  static const double minMultiplier = 1.0;
  static const double maxSafeMultiplier = 2.0;

  ContributionPolicy _policy;

  ContributionRewardService({ContributionPolicy? initialPolicy})
      : _policy = initialPolicy ??
            const ContributionPolicy(
              focusCategories: <String>{'knowledge_guide', 'policy_fact'},
            );

  ContributionPolicy get policy => _policy;

  void updatePolicy({
    Iterable<String>? focusCategories,
    double? focusMultiplier,
  }) {
    _policy = _policy.copyWith(
      focusCategories: focusCategories
          ?.map((c) => c.trim().toLowerCase())
          .where((c) => c.isNotEmpty)
          .toSet(),
      focusMultiplier: focusMultiplier != null
          ? clampMultiplier(focusMultiplier)
          : _policy.focusMultiplier,
    );
  }

  static double clampMultiplier(double value) {
    if (!value.isFinite) return defaultFocusMultiplier;
    final bounded = value.clamp(minMultiplier, maxSafeMultiplier);
    return (bounded * 100).round() / 100;
  }

  ContributionRewardReceipt calculateReward({
    required String userId,
    required String category,
    required int basePoints,
    required int previousTotalPoints,
  }) {
    final safeBase = basePoints < 0 ? 0 : basePoints;
    final safePrev = previousTotalPoints < 0 ? 0 : previousTotalPoints;
    final normalizedCat = category.trim().toLowerCase();
    final isFocus = normalizedCat.isNotEmpty &&
        _policy.focusCategories
            .any((item) => item.trim().toLowerCase() == normalizedCat);
    final multiplier =
        isFocus ? clampMultiplier(_policy.focusMultiplier) : minMultiplier;
    final awarded = (safeBase * multiplier).round();
    final newTotal = safePrev + awarded;

    return ContributionRewardReceipt(
      userId: userId,
      category: category.trim(),
      basePoints: safeBase,
      isFocusCategory: isFocus,
      appliedMultiplier: multiplier,
      awardedPoints: awarded,
      newTotalPoints: newTotal,
      unlockedTier: RewardTier.fromPoints(newTotal),
    );
  }
}

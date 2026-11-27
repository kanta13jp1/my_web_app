import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/contribution_reward_service.dart';

void main() {
  test('calculateReward applies 1.6x to focus categories and unlocks tiers',
      () {
    final service = ContributionRewardService();

    final focusReceipt = service.calculateReward(
      userId: 'user-1',
      category: 'knowledge_guide',
      basePoints: 100,
      previousTotalPoints: 0,
    );
    expect(focusReceipt.isFocusCategory, isTrue);
    expect(focusReceipt.appliedMultiplier, 1.6);
    expect(focusReceipt.awardedPoints, 160);
    expect(focusReceipt.newTotalPoints, 160);
    expect(focusReceipt.unlockedTier, RewardTier.contributor);

    final normalReceipt = service.calculateReward(
      userId: 'user-1',
      category: 'general_note',
      basePoints: 100,
      previousTotalPoints: 0,
    );
    expect(normalReceipt.isFocusCategory, isFalse);
    expect(normalReceipt.appliedMultiplier, 1.0);
    expect(normalReceipt.awardedPoints, 100);
  });

  test('updatePolicy dynamically switches focus categories and caps multiplier',
      () {
    final service = ContributionRewardService();
    service.updatePolicy(
      focusCategories: ['ai_eval'],
      focusMultiplier: 5.0,
    );

    expect(service.policy.focusMultiplier, 2.0);
    final res = service.calculateReward(
      userId: 'user-2',
      category: 'ai_eval',
      basePoints: 500,
      previousTotalPoints: 0,
    );
    expect(res.appliedMultiplier, 2.0);
    expect(res.awardedPoints, 1000);
    expect(res.unlockedTier, RewardTier.steward);
  });
}

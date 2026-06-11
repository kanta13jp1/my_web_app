import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/konbini_udon_challenge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('KonbiniUdonChallengeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('can enable the challenge and complete all three meals', () async {
      final now = DateTime(2026, 6, 11, 8, 0);
      final service = KonbiniUdonChallengeService(nowProvider: () => now);

      var snapshot = await service.setEnabled(true, remainingDebt: 300000);

      expect(snapshot.isEnabled, isTrue);
      expect(snapshot.isReleased, isFalse);
      expect(snapshot.startedAt, isNotNull);
      expect(snapshot.isTodayCompliant, isFalse);

      for (final slot in KonbiniUdonMealSlot.values) {
        snapshot = await service.toggleMealSlot(
          slot,
          true,
          remainingDebt: 300000,
        );
      }

      expect(snapshot.todayUdonSlots, hasLength(3));
      expect(snapshot.isTodayCompliant, isTrue);
      expect(snapshot.currentStreakDays, 1);
      expect(snapshot.totalCompliantDays, 1);
    });

    test('a violation breaks today compliance and clears its meal slot',
        () async {
      final now = DateTime(2026, 6, 11, 12, 30);
      final service = KonbiniUdonChallengeService(nowProvider: () => now);

      await service.setEnabled(true, remainingDebt: 300000);
      for (final slot in KonbiniUdonMealSlot.values) {
        await service.toggleMealSlot(slot, true, remainingDebt: 300000);
      }

      final snapshot = await service.recordViolation(
        note: '牛丼を食べてしまった',
        amount: 580,
        slot: KonbiniUdonMealSlot.lunch,
        remainingDebt: 300000,
      );

      expect(snapshot.todayViolations, hasLength(1));
      expect(
        snapshot.todayViolations.first.mealSlot,
        KonbiniUdonMealSlot.lunch,
      );
      expect(snapshot.todayViolations.first.amount, 580);
      expect(
        snapshot.todayUdonSlots.contains(KonbiniUdonMealSlot.lunch),
        isFalse,
      );
      expect(snapshot.isTodayCompliant, isFalse);
      expect(snapshot.currentStreakDays, 0);
      expect(snapshot.recentViolations.first.note, '牛丼を食べてしまった');
    });

    test('releases the challenge automatically when debt reaches zero',
        () async {
      final service = KonbiniUdonChallengeService(
        nowProvider: () => DateTime(2026, 6, 11, 9, 0),
      );

      await service.setEnabled(true, remainingDebt: 120000);
      final snapshot = await service.loadSnapshot(remainingDebt: 0);

      expect(snapshot.isReleased, isTrue);
      expect(snapshot.isEnabled, isFalse);
      expect(snapshot.isActive, isFalse);
    });

    test('counts streak across consecutive fully compliant days', () async {
      var now = DateTime(2026, 6, 9, 7, 0);
      final service = KonbiniUdonChallengeService(nowProvider: () => now);

      await service.setEnabled(true, remainingDebt: 200000);
      for (final slot in KonbiniUdonMealSlot.values) {
        await service.toggleMealSlot(slot, true, remainingDebt: 200000);
      }

      now = now.add(const Duration(days: 1));
      for (final slot in KonbiniUdonMealSlot.values) {
        await service.toggleMealSlot(slot, true, remainingDebt: 200000);
      }

      var snapshot = await service.loadSnapshot(remainingDebt: 200000);
      expect(snapshot.currentStreakDays, 2);
      expect(snapshot.totalCompliantDays, 2);

      // 翌日まだ何も記録していない朝の時点では、昨日までの連続を保持する。
      now = now.add(const Duration(days: 1));
      snapshot = await service.loadSnapshot(remainingDebt: 200000);
      expect(snapshot.currentStreakDays, 2);
    });

    test('estimates monthly savings from config defaults', () {
      const estimate = KonbiniUdonSavingsEstimate(
        monthlyUdonCost: 0,
        monthlyBaselineFoodCost: 0,
        monthlySavings: 0,
      );
      expect(estimate.hasSavings, isFalse);

      final computed = KonbiniUdonChallengeService.estimateSavings(
        KonbiniUdonChallengeConfig.defaults,
      );

      // 200円 × 3食 × 30.4日 = 18,240円 / 月。
      expect(computed.monthlyUdonCost, closeTo(18240, 0.01));
      expect(computed.monthlyBaselineFoodCost, 45000);
      expect(computed.monthlySavings, closeTo(26760, 0.01));
      expect(computed.hasSavings, isTrue);
      expect(computed.dailySavings, closeTo(26760 / 30.4, 0.01));
    });

    test('clamps savings to zero when udon costs exceed the baseline', () {
      final computed = KonbiniUdonChallengeService.estimateSavings(
        const KonbiniUdonChallengeConfig(
          udonUnitPrice: 800,
          baselineMonthlyFoodCost: 30000,
        ),
      );

      expect(computed.monthlySavings, 0);
      expect(computed.hasSavings, isFalse);
    });

    test('escalates health advisory with consecutive days', () {
      expect(
        KonbiniUdonChallengeService.healthAdvisoryFor(2).level,
        KonbiniUdonHealthAdvisoryLevel.none,
      );
      expect(
        KonbiniUdonChallengeService.healthAdvisoryFor(3).level,
        KonbiniUdonHealthAdvisoryLevel.info,
      );
      expect(
        KonbiniUdonChallengeService.healthAdvisoryFor(7).level,
        KonbiniUdonHealthAdvisoryLevel.warning,
      );
      expect(
        KonbiniUdonChallengeService.healthAdvisoryFor(14).level,
        KonbiniUdonHealthAdvisoryLevel.danger,
      );
    });

    test('persists config updates and clamps negative values', () async {
      final service = KonbiniUdonChallengeService(
        nowProvider: () => DateTime(2026, 6, 11, 10, 0),
      );

      final snapshot = await service.updateConfig(
        udonUnitPrice: 250,
        baselineMonthlyFoodCost: -100,
        remainingDebt: 50000,
      );

      expect(snapshot.config.udonUnitPrice, 250);
      expect(snapshot.config.baselineMonthlyFoodCost, 0);
      expect(snapshot.savings.monthlySavings, 0);
    });

    test('tolerates corrupted history payloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'konbini_udon_challenge_history_v1': '{broken json',
        'konbini_udon_challenge_config_v1': '[]',
      });
      final service = KonbiniUdonChallengeService(
        nowProvider: () => DateTime(2026, 6, 11, 11, 0),
      );

      final snapshot = await service.loadSnapshot(remainingDebt: 80000);

      expect(snapshot.todayUdonSlots, isEmpty);
      expect(snapshot.todayViolations, isEmpty);
      expect(snapshot.currentStreakDays, 0);
      expect(
        snapshot.config.udonUnitPrice,
        KonbiniUdonChallengeService.defaultUdonUnitPrice,
      );
    });

    test('rejects an empty violation note', () async {
      final service = KonbiniUdonChallengeService(
        nowProvider: () => DateTime(2026, 6, 11, 12, 0),
      );

      await expectLater(
        service.recordViolation(
          note: '   ',
          amount: 100,
          remainingDebt: 10000,
        ),
        throwsArgumentError,
      );
    });
  });
}

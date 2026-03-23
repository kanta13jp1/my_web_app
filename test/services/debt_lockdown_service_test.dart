import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DebtLockdownService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('can enable mode, complete a rule, and record a violation', () async {
      final now = DateTime(2026, 3, 23, 8, 30);
      final service = DebtLockdownService(nowProvider: () => now);

      var snapshot = await service.setEnabled(true, remainingDebt: 250000);

      expect(snapshot.isEnabled, isTrue);
      expect(snapshot.isReleased, isFalse);

      snapshot = await service.toggleRule(
        'daily_debt_check',
        true,
        remainingDebt: 250000,
      );

      expect(snapshot.completedRuleIds, contains('daily_debt_check'));

      snapshot = await service.recordViolation(
        category: '飲酒',
        note: '缶ビールを買った',
        amount: 280,
        remainingDebt: 250000,
      );

      expect(snapshot.todayViolations, hasLength(1));
      expect(snapshot.recentViolations.first.category, '飲酒');
      expect(snapshot.recentViolations.first.amount, 280);
    });

    test('marks snapshot as released when remaining debt reaches zero',
        () async {
      final service = DebtLockdownService(
        nowProvider: () => DateTime(2026, 3, 23, 9, 0),
      );

      await service.setEnabled(true, remainingDebt: 80000);
      final snapshot = await service.loadSnapshot(remainingDebt: 0);

      expect(snapshot.isReleased, isTrue);
      expect(snapshot.isEnabled, isFalse);
    });

    test('counts compliant streak across consecutive fully completed days',
        () async {
      var now = DateTime(2026, 3, 23, 7, 0);
      final service = DebtLockdownService(nowProvider: () => now);

      await service.setEnabled(true, remainingDebt: 100000);
      for (final rule in DebtLockdownService.builtinRules) {
        await service.toggleRule(rule.id, true, remainingDebt: 100000);
      }

      now = now.add(const Duration(days: 1));
      for (final rule in DebtLockdownService.builtinRules) {
        await service.toggleRule(rule.id, true, remainingDebt: 100000);
      }

      final snapshot = await service.loadSnapshot(remainingDebt: 100000);

      expect(snapshot.currentCompliantStreakDays, 2);
      expect(snapshot.todayViolations, isEmpty);
    });
  });
}

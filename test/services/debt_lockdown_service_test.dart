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

    test(
      'marks snapshot as released when remaining debt reaches zero',
      () async {
        final service = DebtLockdownService(
          nowProvider: () => DateTime(2026, 3, 23, 9, 0),
        );

        await service.setEnabled(true, remainingDebt: 80000);
        final snapshot = await service.loadSnapshot(remainingDebt: 0);

        expect(snapshot.isReleased, isTrue);
        expect(snapshot.isEnabled, isFalse);
      },
    );

    test(
      'counts compliant streak across consecutive fully completed days',
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
      },
    );

    test('blocks annual rates above the statutory 20 percent line', () {
      final risk = DebtLockdownService.evaluateAnnualRate(
        accountName: 'Unregistered lender',
        annualRate: 0.205,
        principal: 50000,
      );

      expect(risk, isNotNull);
      expect(risk!.blocksRegistration, isTrue);
      expect(risk.legalCapAnnualRate, 0.20);
      expect(risk.severity, DebtSafetySeverity.danger);
    });

    test('warns when the principal based cap is exceeded below 20 percent', () {
      final risk = DebtLockdownService.evaluateAnnualRate(
        accountName: 'Large card loan',
        annualRate: 0.17,
        principal: 1200000,
      );

      expect(risk, isNotNull);
      expect(risk!.blocksRegistration, isFalse);
      expect(risk.legalCapAnnualRate, 0.15);
      expect(risk.severity, DebtSafetySeverity.warning);
    });

    test(
      'shows self-exclusion guidance and education notices at thresholds',
      () {
        final snapshot = DebtLockdownService.buildSafetySnapshot(
          debts: List<DebtSafetyDebtInput>.generate(
            5,
            (index) => DebtSafetyDebtInput(
              accountId: 'debt_$index',
              accountName: 'Debt $index',
              balance: 220000,
              annualRate: 0.18,
            ),
          ),
        );

        expect(snapshot.totalDebt, 1100000);
        expect(snapshot.shouldShowSelfExclusionGuidance, isTrue);
        expect(
          snapshot.guidanceCards.map((guidance) => guidance.id),
          containsAll(<String>[
            'lending_self_exclusion',
            'lending_consultation',
            'registered_lender_search',
          ]),
        );
        expect(
          snapshot.educationNotices.map((notice) => notice.id),
          containsAll(<String>[
            'name_lending',
            'credit_card_cashing',
            'registered_lender_check',
          ]),
        );
        expect(
          snapshot.guidanceCards
              .firstWhere((guidance) => guidance.id == 'lending_self_exclusion')
              .url,
          DebtLockdownService.selfExclusionGuidanceUrl,
        );
      },
    );

    test('keeps quiet when legal-rate debts are below guidance thresholds', () {
      final snapshot = DebtLockdownService.buildSafetySnapshot(
        debts: const <DebtSafetyDebtInput>[
          DebtSafetyDebtInput(
            accountId: 'small',
            accountName: 'Small balance',
            balance: 50000,
            annualRate: 0.18,
          ),
        ],
      );

      expect(snapshot.hasSignals, isFalse);
      expect(snapshot.shouldShowSelfExclusionGuidance, isFalse);
      expect(snapshot.annualRateRisks, isEmpty);
      expect(snapshot.educationNotices, isEmpty);
      expect(snapshot.guidanceCards, isEmpty);
    });
  });
}

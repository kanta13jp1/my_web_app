import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  group('AssetLiabilityPaymentReminderService.buildCandidates', () {
    const planner = AssetLiabilityPlanningService();
    const reminders = AssetLiabilityPaymentReminderService();

    test('matches unpaid due rows from the chronological cashflow', () {
      final now = DateTime(2026, 5, 14);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 25000,
          'アコムカードローン': -100000,
          'auPayカード': -10000,
          'モビット': -100000,
          'PayPayカード': -20000,
        },
        baseDate: now,
        monthlyPaymentOverrides: const <String, double>{
          'アコムカードローン': 5000,
          'auPayカード': 8000,
          'モビット': 9000,
          'PayPayカード': 12000,
        },
      );

      final candidates = reminders.buildCandidates(
        workbook: workbook,
        now: now,
      );
      final dueRows = workbook.cashflowRows.where((row) {
        return row.isPayment &&
            row.isDirectCashflowTarget &&
            !row.paid &&
            !row.paymentDate.isAfter(DateTime(2026, 5, 15));
      });

      expect(
        candidates.map((candidate) => candidate.cashflowRow.accountId),
        dueRows.map((row) => row.accountId),
      );
      expect(
        candidates.map((candidate) => candidate.status),
        <AssetLiabilityPaymentReminderStatus>[
          AssetLiabilityPaymentReminderStatus.overdue,
          AssetLiabilityPaymentReminderStatus.overdue,
          AssetLiabilityPaymentReminderStatus.dueTomorrow,
        ],
      );
    });

    test('excludes already paid rows', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 10000, 'モビット': -100000},
        baseDate: now,
        monthlyPaymentOverrides: const <String, double>{'モビット': 10000},
        paidAccountNames: const <String>{'モビット'},
      );

      expect(reminders.buildCandidates(workbook: workbook, now: now), isEmpty);
    });

    test('excludes zero-yen review-only rows', () {
      final now = DateTime(2026, 5, 29);
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 10000,
          'じぶん銀行カードローン': -100000,
        },
        baseDate: now,
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0,
        },
      );

      expect(workbook.cashflowRows.single.overdue, isFalse);
      expect(reminders.buildCandidates(workbook: workbook, now: now), isEmpty);
    });

    test('adds shortage risk text without mutating cashflow data', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 9000, 'モビット': -100000},
        baseDate: now,
        monthlyPaymentOverrides: const <String, double>{'モビット': 10000},
      );
      final before = workbook.cashflowRows
          .map((row) => '${row.accountId}:${row.cashAfterPayment}:${row.paid}')
          .toList();

      final candidates = reminders.buildCandidates(
        workbook: workbook,
        now: now,
      );
      final after = workbook.cashflowRows
          .map((row) => '${row.accountId}:${row.cashAfterPayment}:${row.paid}')
          .toList();

      expect(candidates, hasLength(1));
      expect(
        candidates.single.status,
        AssetLiabilityPaymentReminderStatus.dueToday,
      );
      expect(candidates.single.hasShortageRisk, isTrue);
      expect(candidates.single.detail, contains('不足'));
      expect(after, before);
    });
  });
}

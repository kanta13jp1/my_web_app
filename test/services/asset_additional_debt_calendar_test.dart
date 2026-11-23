import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/home_daily_cashflow_summary.dart';
import 'package:my_web_app/services/asset_debt_guard_calendar_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';
import 'package:my_web_app/utils/home_calendar_cashflow_aggregation.dart';

int _parseAmount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

void main() {
  group('AssetPaymentCalendarService additional debt projection', () {
    test(
      'projects revolving usage on usage date without altering cash or totals',
      () {
        final calendar = AssetPaymentCalendarService.buildRange(
          start: DateTime(2026, 7, 1),
          endExclusive: DateTime(2026, 7, 5),
          flows: const <Map<String, dynamic>>[],
          subscriptions: const <Map<String, dynamic>>[],
          debts: const <AssetCalendarDebtInput>[],
          startingCashBalance: 50000,
          revolvingUsages: <AssetCalendarRevolvingUsageInput>[
            AssetCalendarRevolvingUsageInput(
              date: DateTime(2026, 7, 3, 21, 30),
              accountName: 'ファミペイ',
              description: 'コンビニ買い物',
              amount: 4500,
              sourceId: 'revolving_cal_famipay_card_1',
            ),
          ],
        );

        final day = calendar.dayFor(DateTime(2026, 7, 3))!;
        expect(day.hasRevolvingUsage, isTrue);
        expect(day.hasAdditionalDebtActivity, isTrue);
        expect(day.revolvingUsageTotal, 4500);
        expect(day.expenseTotal, 0);
        expect(day.incomeTotal, 0);
        expect(day.scheduledOutflow, 0);
        expect(day.projectedBalance, 50000);
        expect(day.events, hasLength(1));
        expect(day.events.single.kind, AssetCalendarEventKind.revolvingUsage);
        expect(day.events.single.affectsCashProjection, isFalse);
        expect(day.events.single.label, contains('リボ利用（現金引落なし）'));
        expect(day.events.single.label, contains('ファミペイ'));
        expect(day.events.single.label, contains('コンビニ買い物'));
      },
    );

    test(
      'projects Debt Guard additional_borrowing violations without cash impact',
      () {
        final calendar = AssetPaymentCalendarService.buildRange(
          start: DateTime(2026, 7, 1),
          endExclusive: DateTime(2026, 7, 5),
          flows: const <Map<String, dynamic>>[],
          subscriptions: const <Map<String, dynamic>>[],
          debts: const <AssetCalendarDebtInput>[],
          startingCashBalance: 30000,
          debtGuardViolations: <AssetCalendarDebtGuardViolationInput>[
            AssetCalendarDebtGuardViolationInput(
              date: DateTime(2026, 7, 2),
              note: 'モビット: 追加借入 (10,000円)',
              sourceId: '42',
            ),
          ],
        );

        final day = calendar.dayFor(DateTime(2026, 7, 2))!;
        expect(day.hasDebtGuardBorrowingViolation, isTrue);
        expect(day.hasAdditionalDebtActivity, isTrue);
        expect(day.expenseTotal, 0);
        expect(day.incomeTotal, 0);
        expect(day.projectedBalance, 30000);
        expect(day.events, hasLength(1));
        expect(
          day.events.single.kind,
          AssetCalendarEventKind.debtGuardBorrowingViolation,
        );
        expect(day.events.single.amount, isNull);
        expect(day.events.single.affectsCashProjection, isFalse);
        expect(day.events.single.label, contains('追加借金ルール違反（Debt Guard）'));
        expect(day.events.single.label, contains('モビット'));
      },
    );

    test(
      'extractRevolvingUsages keeps revolving & manual lines and skips non-revolving/provisional/adjustment/undated',
      () {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          latestSnapshot: const <String, double>{
            '財布(現金)': 50000,
            'ファミペイ': -100000,
            'モビット': -200000,
          },
          baseDate: DateTime(2026, 7, 10),
          revolvingConfigs:
              const <String, AssetLiabilityRevolvingCreditConfig>{
            'famipay_card': AssetLiabilityRevolvingCreditConfig(
              monthlyAmount: 5000,
              newUsageAmount: 8000,
            ),
          },
        );
        final famipayId = workbook.debtMasterRows
            .firstWhere((row) => row.isRevolving)
            .id;

        final extracted = AssetPaymentCalendarService.extractRevolvingUsages(
          workbook: workbook,
          statementLines: <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'stmt_1',
              billingAccountId: famipayId,
              billingAccountName: 'ファミペイ',
              postedAt: DateTime(2026, 7, 4),
              description: 'スーパー',
              amount: 3200,
            ),
            AssetLiabilityCardStatementLine(
              id: 'revolving_cal_custom_1',
              billingAccountId: 'custom_card',
              billingAccountName: '別カード',
              postedAt: DateTime(2026, 7, 5),
              description: '手動リボ',
              amount: 1500,
            ),
            AssetLiabilityCardStatementLine(
              id: 'stmt_provisional',
              billingAccountId: famipayId,
              billingAccountName: 'ファミペイ',
              postedAt: DateTime(2026, 7, 6),
              description: '仮内訳',
              amount: 2000,
              isProvisional: true,
            ),
            AssetLiabilityCardStatementLine(
              id: 'stmt_adj',
              billingAccountId: famipayId,
              billingAccountName: 'ファミペイ',
              postedAt: DateTime(2026, 7, 6),
              description: '調整行',
              amount: 1000,
              isConfiguredAdjustment: true,
            ),
            AssetLiabilityCardStatementLine(
              id: 'stmt_undated',
              billingAccountId: famipayId,
              billingAccountName: 'ファミペイ',
              postedAt: null,
              description: '日付なし',
              amount: 1000,
            ),
            AssetLiabilityCardStatementLine(
              id: 'stmt_non_revolving',
              billingAccountId: 'mobit',
              billingAccountName: 'モビット',
              postedAt: DateTime(2026, 7, 7),
              description: '対象外',
              amount: 5000,
            ),
          ],
        );

        expect(extracted, hasLength(2));
        expect(extracted[0].sourceId, 'stmt_1');
        expect(extracted[0].date, DateTime(2026, 7, 4));
        expect(extracted[0].amount, 3200);
        expect(extracted[1].sourceId, 'revolving_cal_custom_1');
        expect(extracted[1].date, DateTime(2026, 7, 5));
        expect(extracted[1].amount, 1500);
      },
    );
  });

  group('AssetDebtGuardCalendarService.parseRows', () {
    test('parses valid rows and ignores invalid dates or other rules', () {
      final parsed = AssetDebtGuardCalendarService.parseRows(<dynamic>[
        <String, dynamic>{
          'id': 1,
          'rule_id': 'additional_borrowing',
          'event_type': 'violation',
          'event_date': '2026-07-08',
          'note': 'キャッシング 10,000円',
        },
        <String, dynamic>{
          'id': 2,
          'rule_id': 'eating_out',
          'event_type': 'violation',
          'event_date': '2026-07-08',
          'note': '別ルール',
        },
        <String, dynamic>{
          'id': 3,
          'rule_id': 'additional_borrowing',
          'event_type': 'check_in',
          'event_date': '2026-07-08',
          'note': 'チェックイン',
        },
        <String, dynamic>{
          'id': 4,
          'rule_id': 'additional_borrowing',
          'event_type': 'violation',
          'event_date': '2026-02-30',
          'note': '実在しない日付',
        },
        null,
        'malformed',
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single.sourceId, '1');
      expect(parsed.single.date, DateTime(2026, 7, 8));
      expect(parsed.single.note, 'キャッシング 10,000円');
    });
  });

  group('Home calendar borrowing cashflow aggregation', () {
    test(
      'tracks borrowing totals separately without changing recordCount or netTotal',
      () {
        final days = aggregateHomeCalendarCashflow(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'action_type': 'borrowing',
              'amount': 25000,
              'occurred_at': DateTime(2026, 7, 8, 12).toIso8601String(),
            },
            <String, dynamic>{
              'action_type': 'expense',
              'amount': 1200,
              'occurred_at': DateTime(2026, 7, 8, 18).toIso8601String(),
            },
          ],
          dateKeyFor: DateFormat('yyyy-MM-dd').format,
          amountFor: _parseAmount,
        );

        final day = days['2026-07-08']!;
        expect(day.borrowingTotal, 25000);
        expect(day.borrowingCount, 1);
        expect(day.hasBorrowing, isTrue);
        expect(day.expenseTotal, 1200);
        expect(day.expenseCount, 1);
        expect(day.incomeTotal, 0);
        expect(day.recordCount, 1);
        expect(day.netTotal, -1200);
        expect(day.hasCashflow, isTrue);
        expect(day.hasAnyEntry, isTrue);

        const borrowingOnly = HomeDailyCashflowSummary(
          borrowingTotal: 10000,
          borrowingCount: 1,
        );
        expect(borrowingOnly.recordCount, 0);
        expect(borrowingOnly.netTotal, 0);
        expect(borrowingOnly.hasCashflow, isFalse);
        expect(borrowingOnly.hasBorrowing, isTrue);
        expect(borrowingOnly.hasAnyEntry, isTrue);
      },
    );
  });
}

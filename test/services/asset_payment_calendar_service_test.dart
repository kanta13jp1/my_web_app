import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

void main() {
  group('AssetPaymentCalendarService', () {
    test('aggregates expenses and income per local day', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: <Map<String, dynamic>>[
          <String, dynamic>{
            'occurred_at': '2026-06-11T03:00:00Z',
            'amount': 580,
            'action_type': 'expense',
            'description': '牛丼',
          },
          <String, dynamic>{
            'occurred_at': '2026-06-11T09:30:00Z',
            'amount': 200,
            'action_type': 'expense',
            'description': 'うどん',
          },
          <String, dynamic>{
            'occurred_at': '2026-06-25T01:00:00Z',
            'amount': 280000,
            'action_type': 'conquer',
            'description': '給与',
          },
          <String, dynamic>{'amount': 999, 'action_type': 'expense'},
        ],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[],
      );

      final day11 = calendar.dayFor(DateTime(2026, 6, 11));
      expect(day11, isNotNull);
      expect(day11!.expenseTotal, 780);
      expect(day11.events, hasLength(2));

      final day25 = calendar.dayFor(DateTime(2026, 6, 25));
      expect(day25!.incomeTotal, 280000);
      expect(day25.hasIncome, isTrue);
    });

    test('clamps debt payment days into short months and skips paid rows', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 2),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'カードローン',
            balance: -300000,
            paymentDay: 31,
            scheduledPaymentAmount: 15000,
          ),
          AssetCalendarDebtInput(name: '完済済み', balance: 0, paymentDay: 10),
          AssetCalendarDebtInput(
            name: 'カード合算',
            balance: -5000,
            paymentDay: 5,
            isDirectCashflowTarget: false,
          ),
        ],
      );

      final day28 = calendar.dayFor(DateTime(2026, 2, 28));
      expect(day28!.hasDebtPayment, isTrue);
      expect(day28.events.single.label, 'カードローン 返済');
      expect(day28.events.single.amount, 15000);
      expect(calendar.dayFor(DateTime(2026, 2, 10))!.hasAnyEvent, isFalse);
      expect(calendar.dayFor(DateTime(2026, 2, 5))!.hasAnyEvent, isFalse);
    });

    test('places subscriptions and salary on their days', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': '家賃',
            'price': 65000,
            'due_date': '2026-06-27T00:00:00',
          },
          <String, dynamic>{
            'service_name': '先月分',
            'price': 1000,
            'due_date': '2026-05-27T00:00:00',
          },
        ],
        debts: const <AssetCalendarDebtInput>[],
        salaryDay: 25,
      );

      final day27 = calendar.dayFor(DateTime(2026, 6, 27));
      expect(day27!.hasSubscription, isTrue);
      expect(day27.events.single.amount, 65000);
      expect(calendar.dayFor(DateTime(2026, 6, 25))!.hasSalary, isTrue);
      final withSubscription =
          calendar.days.where((day) => day.hasSubscription).toList();
      expect(withSubscription, hasLength(1));
    });

    test('builds sunday-first weeks with blank padding', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[],
      );

      // 2026-06-01 は月曜 → 先頭の空きセルは1つ。
      expect(calendar.weeks.first.first, isNull);
      expect(calendar.weeks.first[1]!.date.day, 1);
      expect(calendar.weeks.length, 5);
      for (final week in calendar.weeks) {
        expect(week, hasLength(7));
      }
    });

    test('orders mixed events by kind priority', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: <Map<String, dynamic>>[
          <String, dynamic>{
            'occurred_at': '2026-06-25T05:00:00Z',
            'amount': 1200,
            'action_type': 'expense',
            'description': '昼食',
          },
        ],
        subscriptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': 'サブスク',
            'price': 980,
            'due_date': '2026-06-25T00:00:00',
          },
        ],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローン',
            balance: -100000,
            paymentDay: 25,
            scheduledPaymentAmount: 8000,
          ),
        ],
        salaryDay: 25,
      );

      final day = calendar.dayFor(DateTime(2026, 6, 25))!;
      expect(day.events, hasLength(4));
      expect(day.events[0].kind, AssetCalendarEventKind.salary);
      expect(day.events[1].kind, AssetCalendarEventKind.debtPayment);
      expect(day.events[2].kind, AssetCalendarEventKind.subscription);
      expect(day.events[3].kind, AssetCalendarEventKind.expense);
    });

    test('sums scheduled outflow and projects the first shortfall day', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': '家賃',
            'price': 10000,
            'due_date': '2026-06-10T00:00:00',
          },
        ],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローン',
            balance: -300000,
            paymentDay: 5,
            scheduledPaymentAmount: 15000,
          ),
        ],
        startingCashBalance: 20000,
      );

      expect(calendar.scheduledDebtPaymentTotal, 15000);
      expect(calendar.subscriptionTotal, 10000);
      expect(calendar.scheduledOutflowTotal, 25000);

      final day5 = calendar.dayFor(DateTime(2026, 6, 5))!;
      expect(day5.scheduledOutflow, 15000);
      expect(day5.projectedBalance, 5000);
      expect(day5.isShortfall, isFalse);

      final day10 = calendar.dayFor(DateTime(2026, 6, 10))!;
      expect(day10.projectedBalance, -5000);
      expect(day10.isShortfall, isTrue);
      expect(calendar.firstShortfallDate, DateTime(2026, 6, 10));

      final day30 = calendar.dayFor(DateTime(2026, 6, 30))!;
      expect(day30.projectedBalance, -5000);
    });

    test('keeps shortfall fields empty without a starting balance', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローン',
            balance: -300000,
            paymentDay: 5,
            scheduledPaymentAmount: 15000,
          ),
        ],
      );

      expect(calendar.firstShortfallDate, isNull);
      final day5 = calendar.dayFor(DateTime(2026, 6, 5))!;
      expect(day5.projectedBalance, isNull);
      expect(day5.isShortfall, isFalse);
    });

    test('expected inflows lift the projection and clear shortfalls', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローン',
            balance: -300000,
            paymentDay: 5,
            scheduledPaymentAmount: 15000,
          ),
        ],
        startingCashBalance: 5000,
        expectedInflows: <AssetCalendarInflowInput>[
          AssetCalendarInflowInput(
            date: DateTime(2026, 6, 3),
            amount: 20000,
            label: '振込',
          ),
          AssetCalendarInflowInput(
            date: DateTime(2026, 7, 3),
            amount: 99999,
            label: '対象外の月',
          ),
        ],
      );

      expect(calendar.firstShortfallDate, isNull);
      final day3 = calendar.dayFor(DateTime(2026, 6, 3))!;
      expect(day3.hasExpectedInflow, isTrue);
      expect(day3.projectedBalance, 25000);
      final day5 = calendar.dayFor(DateTime(2026, 6, 5))!;
      expect(day5.projectedBalance, 10000);
      expect(day5.isShortfall, isFalse);
    });

    test('same-day inflow is applied before the payment', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローン',
            balance: -300000,
            paymentDay: 25,
            scheduledPaymentAmount: 15000,
          ),
        ],
        startingCashBalance: 0,
        expectedInflows: <AssetCalendarInflowInput>[
          AssetCalendarInflowInput(
            date: DateTime(2026, 6, 25),
            amount: 15000,
            label: '給料',
          ),
        ],
      );

      expect(calendar.firstShortfallDate, isNull);
      expect(calendar.dayFor(DateTime(2026, 6, 25))!.projectedBalance, 0);
    });
  });
}

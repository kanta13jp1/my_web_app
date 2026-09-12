import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

void main() {
  group('AssetPaymentCalendarService', () {
    test(
        'Issue #5190: handles paid debt without adding to scheduled outflow and labels (支払済)',
        () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 8),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'acom',
            name: 'アコム',
            balance: -100000,
            paymentDay: 26,
            scheduledPaymentAmount: 10000,
            paid: true,
          ),
          AssetCalendarDebtInput(
            id: 'mobit',
            name: 'モビット',
            balance: -50000,
            paymentDay: 26,
            scheduledPaymentAmount: 5000,
            paid: false,
          ),
        ],
      );

      final day26 = calendar.dayFor(DateTime(2026, 8, 26));
      expect(day26, isNotNull);
      expect(day26!.events, hasLength(2));
      final acomEvent = day26.events.firstWhere((e) => e.sourceId == 'acom');
      expect(acomEvent.label, 'アコム (支払済)');
      expect(acomEvent.isPaid, isTrue);
      expect(acomEvent.amount, isNull);

      final mobitEvent = day26.events.firstWhere((e) => e.sourceId == 'mobit');
      expect(mobitEvent.label, 'モビット 返済');
      expect(mobitEvent.isPaid, isFalse);
      expect(mobitEvent.amount, 5000);

      expect(calendar.scheduledDebtPaymentTotal, 5000);
    });

    test('maps utility workbook rows to fixed-cost calendar inputs', () {
      final workbook = const AssetLiabilityPlanningService().buildWorkbook(
        latestSnapshot: const <String, double>{'現金': 100000},
        baseDate: DateTime(2026, 8, 1),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'notion',
            name: 'Notion',
            amount: 3712,
            paymentDay: 17,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
      );
      final row = workbook.debtMasterRows.singleWhere(
        (candidate) => candidate.name == 'Notion',
      );

      final input = AssetCalendarDebtInput.fromDebtRow(row);

      expect(input.isFixedCost, isTrue);
      expect(input.scheduledPaymentAmount, 3712);
    });

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
            id: 'debt_card_loan',
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
      expect(day28.events.single.sourceId, 'debt_card_loan');
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

    test('reports the worst dip as the shortfall recovery amount', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            name: 'ローンA',
            balance: -100000,
            paymentDay: 5,
            scheduledPaymentAmount: 8000,
          ),
          AssetCalendarDebtInput(
            name: 'ローンB',
            balance: -100000,
            paymentDay: 10,
            scheduledPaymentAmount: 7000,
          ),
        ],
        startingCashBalance: 10000,
      );

      expect(calendar.worstProjectedBalance, -5000);
      expect(calendar.shortfallRecoveryAmount, 5000);
      expect(calendar.firstShortfallDate, DateTime(2026, 6, 10));
    });

    test('recovery amount is zero when the month stays positive', () {
      final calendar = AssetPaymentCalendarService.buildMonth(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[],
        startingCashBalance: 1000,
      );

      expect(calendar.worstProjectedBalance, 1000);
      expect(calendar.shortfallRecoveryAmount, 0);
    });

    test('findMinimalShiftSet prefers the smallest total shifted amount', () {
      const debts = <AssetCalendarDebtInput>[
        AssetCalendarDebtInput(
          id: 'a',
          name: 'A',
          balance: -100000,
          paymentDay: 5,
          scheduledPaymentAmount: 100,
        ),
        AssetCalendarDebtInput(
          id: 'b',
          name: 'B',
          balance: -100000,
          paymentDay: 5,
          scheduledPaymentAmount: 50,
        ),
        AssetCalendarDebtInput(
          id: 'c',
          name: 'C',
          balance: -100000,
          paymentDay: 5,
          scheduledPaymentAmount: 60,
        ),
      ];
      final inflows = <AssetCalendarInflowInput>[
        AssetCalendarInflowInput(
          date: DateTime(2026, 6, 10),
          amount: 120,
          label: '入金',
        ),
      ];

      final minimal = AssetPaymentCalendarService.findMinimalShiftSet(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: debts,
        candidateIds: const <String>['a', 'b', 'c'],
        shiftToDay: 26,
        startingCashBalance: 100,
        expectedInflows: inflows,
      );

      // 単独移動では5日の残額が現金100を超えるため不可。ペアでは
      // {b,c}(残A=100)・{a,b}(残C=60)・{a,c}(残B=50)が全て成立し、
      // 移動額合計が最小の {b,c}=110 が選ばれる。
      expect(minimal, isNotNull);
      expect(minimal!.toSet(), <String>{'b', 'c'});
    });

    test('findMinimalShiftSet returns null when no subset clears', () {
      const debts = <AssetCalendarDebtInput>[
        AssetCalendarDebtInput(
          id: 'a',
          name: 'A',
          balance: -100000,
          paymentDay: 5,
          scheduledPaymentAmount: 500,
        ),
        AssetCalendarDebtInput(
          id: 'b',
          name: 'B',
          balance: -100000,
          paymentDay: 5,
          scheduledPaymentAmount: 500,
        ),
      ];

      final minimal = AssetPaymentCalendarService.findMinimalShiftSet(
        month: DateTime(2026, 6),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: debts,
        candidateIds: const <String>['a', 'b'],
        shiftToDay: 26,
        startingCashBalance: 100,
      );

      expect(minimal, isNull);
    });
  });

  group('AssetPaymentCalendarService.buildRange (給料日サイクル窓)', () {
    test('classifies fixed-cost debt rows separately from debt repayments', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 8, 1),
        endExclusive: DateTime(2026, 9, 1),
        asOf: DateTime(2026, 8, 1),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'notion',
            name: 'Notion',
            balance: -3712,
            paymentDay: 17,
            scheduledPaymentAmount: 3712,
            isFixedCost: true,
          ),
          AssetCalendarDebtInput(
            id: 'loan',
            name: 'ローン',
            balance: -100000,
            paymentDay: 20,
            scheduledPaymentAmount: 5000,
          ),
        ],
      );

      expect(calendar.subscriptionTotal, 3712);
      expect(calendar.scheduledDebtPaymentTotal, 5000);
      expect(calendar.dayFor(DateTime(2026, 8, 17))!.hasSubscription, isTrue);
      expect(calendar.dayFor(DateTime(2026, 8, 17))!.hasDebtPayment, isFalse);
      expect(calendar.dayFor(DateTime(2026, 8, 20))!.hasDebtPayment, isTrue);
    });

    test('does not double count matching legacy and current fixed costs', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 8, 1),
        endExclusive: DateTime(2026, 9, 1),
        asOf: DateTime(2026, 8, 1),
        flows: const <Map<String, dynamic>>[],
        subscriptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': 'Notion',
            'price': 3712,
            'due_date': '2026-08-17T00:00:00',
          },
        ],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'notion',
            name: 'Notion',
            balance: -3712,
            paymentDay: 17,
            scheduledPaymentAmount: 3712,
            isFixedCost: true,
          ),
        ],
      );

      expect(calendar.subscriptionTotal, 3712);
      expect(
        calendar.dayFor(DateTime(2026, 8, 17))!.events.where(
              (event) => event.kind == AssetCalendarEventKind.subscription,
            ),
        hasLength(1),
      );
      expect(calendar.dayFor(DateTime(2026, 8, 17))!.scheduledOutflow, 3712);
    });

    test('asOf still excludes fixed costs whose payment day has passed', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 8, 1),
        endExclusive: DateTime(2026, 9, 1),
        asOf: DateTime(2026, 8, 18),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'notion',
            name: 'Notion',
            balance: -3712,
            paymentDay: 17,
            scheduledPaymentAmount: 3712,
            isFixedCost: true,
          ),
        ],
      );

      expect(calendar.subscriptionTotal, 0);
      expect(
        calendar.dayFor(DateTime(2026, 8, 17))!.hasSubscription,
        isFalse,
      );
      expect(calendar.scheduledOutflowTotal, 0);
    });

    test('cycle window spans two months and resolves payment days', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 6, 25),
        endExclusive: DateTime(2026, 7, 25),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'late',
            name: '給料日直後',
            balance: -100000,
            paymentDay: 27,
            scheduledPaymentAmount: 8000,
          ),
          AssetCalendarDebtInput(
            id: 'early',
            name: '月前半',
            balance: -100000,
            paymentDay: 10,
            scheduledPaymentAmount: 7000,
          ),
        ],
        salaryDay: 25,
      );

      expect(calendar.rangeStart, DateTime(2026, 6, 25));
      expect(calendar.rangeEndExclusive, DateTime(2026, 7, 25));
      expect(calendar.days.first.date, DateTime(2026, 6, 25));
      expect(calendar.days.last.date, DateTime(2026, 7, 24));
      expect(calendar.days, hasLength(30));

      // 支払日は窓内に落ちる暦月へ解決される (27→6/27 / 10→7/10)。
      expect(calendar.dayFor(DateTime(2026, 6, 27))!.hasDebtPayment, isTrue);
      expect(calendar.dayFor(DateTime(2026, 7, 10))!.hasDebtPayment, isTrue);
      expect(calendar.scheduledDebtPaymentTotal, 15000);

      // 給料日マーカーはサイクル開始日のみ (7/25 は窓外)。
      expect(calendar.dayFor(DateTime(2026, 6, 25))!.hasSalary, isTrue);
      expect(
        calendar.days.where((day) => day.hasSalary).toList(),
        hasLength(1),
      );

      // 週グリッドは開始日の曜日で先頭を空ける (2026-06-25 は木曜)。
      expect(calendar.weeks.first[4]!.date, DateTime(2026, 6, 25));
      for (var i = 0; i < 4; i++) {
        expect(calendar.weeks.first[i], isNull);
      }
    });

    test('asOf excludes already-passed scheduled items from the projection',
        () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 6, 25),
        endExclusive: DateTime(2026, 7, 25),
        asOf: DateTime(2026, 7, 10),
        flows: const <Map<String, dynamic>>[],
        subscriptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': '過去の家賃',
            'price': 65000,
            'due_date': '2026-06-27T00:00:00',
          },
          <String, dynamic>{
            'service_name': 'サブスク',
            'price': 980,
            'due_date': '2026-07-20T00:00:00',
          },
        ],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'past',
            name: '支払済み側',
            balance: -100000,
            paymentDay: 27,
            scheduledPaymentAmount: 8000,
          ),
          AssetCalendarDebtInput(
            id: 'future',
            name: 'これから',
            balance: -100000,
            paymentDay: 15,
            scheduledPaymentAmount: 7000,
          ),
        ],
        salaryDay: 25,
        startingCashBalance: 10000,
      );

      // 6/27 の返済・家賃は今日(7/10)より前 → 予定に計上しない
      // (現在残高に織り込み済みとみなす)。
      expect(calendar.dayFor(DateTime(2026, 6, 27))!.hasDebtPayment, isFalse);
      expect(calendar.dayFor(DateTime(2026, 6, 27))!.hasSubscription, isFalse);
      expect(calendar.scheduledDebtPaymentTotal, 7000);
      expect(calendar.subscriptionTotal, 980);

      // 見込み残高は今日以降の予定だけを差し引く: 7/15 に 10000-7000=3000。
      expect(
        calendar.dayFor(DateTime(2026, 7, 15))!.projectedBalance,
        3000,
      );
      expect(calendar.firstShortfallDate, isNull);
    });

    test('moving a payment to just after payday defers it to the next cycle',
        () {
      AssetPaymentCalendarMonth build(int paymentDay) {
        return AssetPaymentCalendarService.buildRange(
          start: DateTime(2026, 6, 25),
          endExclusive: DateTime(2026, 7, 25),
          asOf: DateTime(2026, 7, 10),
          flows: const <Map<String, dynamic>>[],
          subscriptions: const <Map<String, dynamic>>[],
          debts: <AssetCalendarDebtInput>[
            AssetCalendarDebtInput(
              id: 'mobit',
              name: 'モビット',
              balance: -300000,
              paymentDay: paymentDay,
              scheduledPaymentAmount: 15000,
            ),
          ],
          salaryDay: 25,
          startingCashBalance: 10000,
        );
      }

      // 15日のままだと 7/15 にショート。
      expect(build(15).firstShortfallDate, DateTime(2026, 7, 15));

      // 26日へ移すと次回は 7/26 = 窓外(次サイクル=給料日後)→ 当サイクルの
      // 支払が消えショートも消える(「26日へ移動」提案の根拠)。
      final shifted = build(26);
      expect(shifted.firstShortfallDate, isNull);
      expect(shifted.scheduledDebtPaymentTotal, 0);
    });

    test('February cycle clamps day-30 payments into the short month', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 2, 25),
        endExclusive: DateTime(2026, 3, 25),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[
          AssetCalendarDebtInput(
            id: 'd30',
            name: '30日払い',
            balance: -100000,
            paymentDay: 30,
            scheduledPaymentAmount: 5000,
          ),
        ],
        salaryDay: 25,
      );

      // 2月は28日まで → 2/28 へ丸め、3/30 は窓外なので1回だけ。
      expect(calendar.dayFor(DateTime(2026, 2, 28))!.hasDebtPayment, isTrue);
      expect(
        calendar.days.where((day) => day.hasDebtPayment).toList(),
        hasLength(1),
      );
      expect(calendar.scheduledDebtPaymentTotal, 5000);
    });

    test('flows aggregate across the month boundary within the window', () {
      final calendar = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 6, 25),
        endExclusive: DateTime(2026, 7, 25),
        flows: <Map<String, dynamic>>[
          <String, dynamic>{
            'occurred_at': '2026-06-20T03:00:00',
            'amount': 999,
            'action_type': 'expense',
            'description': '窓より前',
          },
          <String, dynamic>{
            'occurred_at': '2026-06-26T03:00:00',
            'amount': 580,
            'action_type': 'expense',
            'description': '前半月',
          },
          <String, dynamic>{
            'occurred_at': '2026-07-10T03:00:00',
            'amount': 200,
            'action_type': 'expense',
            'description': '後半月',
          },
          <String, dynamic>{
            'occurred_at': '2026-07-25T03:00:00',
            'amount': 999,
            'action_type': 'expense',
            'description': '窓より後',
          },
        ],
        subscriptions: const <Map<String, dynamic>>[],
        debts: const <AssetCalendarDebtInput>[],
      );

      expect(calendar.dayFor(DateTime(2026, 6, 20)), isNull);
      expect(calendar.dayFor(DateTime(2026, 6, 26))!.expenseTotal, 580);
      expect(calendar.dayFor(DateTime(2026, 7, 10))!.expenseTotal, 200);
      expect(calendar.dayFor(DateTime(2026, 7, 25)), isNull);
    });

    test('findMinimalShiftSet honors the cycle window and asOf', () {
      const debts = <AssetCalendarDebtInput>[
        AssetCalendarDebtInput(
          id: 'a',
          name: 'A',
          balance: -100000,
          paymentDay: 15,
          scheduledPaymentAmount: 8000,
        ),
        AssetCalendarDebtInput(
          id: 'b',
          name: 'B',
          balance: -100000,
          paymentDay: 18,
          scheduledPaymentAmount: 7000,
        ),
      ];

      final minimal = AssetPaymentCalendarService.findMinimalShiftSet(
        month: DateTime(2026, 6, 25),
        rangeStart: DateTime(2026, 6, 25),
        rangeEndExclusive: DateTime(2026, 7, 25),
        asOf: DateTime(2026, 7, 10),
        flows: const <Map<String, dynamic>>[],
        subscriptions: const <Map<String, dynamic>>[],
        debts: debts,
        candidateIds: const <String>['a', 'b'],
        shiftToDay: 26,
        salaryDay: 25,
        startingCashBalance: 10000,
      );

      // 両方を26日へ移すと次回支払が 7/26(窓外) になりショート解消。
      expect(minimal, isNotNull);
      expect(minimal!.toSet(), <String>{'a', 'b'});
    });
  });
}

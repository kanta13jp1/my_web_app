import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';
import 'package:my_web_app/widgets/asset_calendar_shortfall_details.dart';

AssetPaymentCalendarMonth example({bool withIncomePlan = false}) {
  return AssetPaymentCalendarService.buildRange(
    start: DateTime(2026, 10),
    endExclusive: DateTime(2026, 11),
    asOf: DateTime(2026, 10, 15),
    startingCashBalance: 5000,
    flows: const [],
    subscriptions: const [],
    expectedInflows: [
      if (withIncomePlan)
        AssetCalendarInflowInput(
          date: DateTime(2026, 10, 19),
          amount: 2000,
          label: 'Synthetic future income',
        ),
    ],
    debts: const [
      AssetCalendarDebtInput(
        id: 'first',
        name: 'Synthetic confirmed invoice',
        balance: -20000,
        paymentDay: 20,
        scheduledPaymentAmount: 6000,
        paymentSourceAccountName: 'Synthetic bank',
        paymentAmountEstimated: false,
        billingConfirmed: true,
      ),
      AssetCalendarDebtInput(
        id: 'second',
        name: 'Synthetic estimated payment',
        balance: -20000,
        paymentDay: 22,
        scheduledPaymentAmount: 10000,
      ),
    ],
  );
}

Future<void> pumpEvidence(
  WidgetTester tester, {
  AssetPaymentCalendarMonth? calendarOverride,
  bool withIncomePlan = false,
  DateTime? balanceRecordedOn,
  VoidCallback? onReview,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AssetCalendarShortfallDetails(
            calendar:
                calendarOverride ?? example(withIncomePlan: withIncomePlan),
            asOf: DateTime(2026, 10, 15),
            startingCashBalance: 5000,
            balanceRecordedOn: balanceRecordedOn,
            onReviewPayments: onReview,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('unresolved legacy payment lowers forecast certainty',
      (tester) async {
    final calendar = AssetPaymentCalendarService.buildRange(
      start: DateTime(2026, 10),
      endExclusive: DateTime(2026, 11),
      asOf: DateTime(2026, 10, 15),
      startingCashBalance: 100,
      flows: const [],
      debts: const [],
      subscriptions: const [
        {
          'id': 'unlinked',
          'service_name': 'Synthetic unresolved service',
          'price': 1000,
          'due_date': '2026-10-20',
        },
      ],
    );
    await pumpEvidence(tester, calendarOverride: calendar);
    expect(find.textContaining('条件付き試算です。確定した不足ではありません。'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('asset_calendar_shortfall_payment_evidence')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('支払方法未照合・現金支出を仮置き'), findsOneWidget);
  });

  testWidgets(
      'distinguishes first deficit from maximum deficit and unknown time',
      (tester) async {
    await pumpEvidence(tester);
    expect(find.text('現金・預金合計の資金繰り見込み'), findsOneWidget);
    expect(find.text('10/20の不足見込み: ¥1,000'), findsOneWidget);
    expect(find.text('期間内の最大不足: 10/22に¥11,000'), findsOneWidget);
    expect(find.text('残高の記録日時: 未確認'), findsOneWidget);
    expect(find.textContaining('口座別の引落可否'), findsOneWidget);
  });

  testWidgets(
      '390px evidence reveals source and estimate without financial action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var reviewed = false;
    await pumpEvidence(tester, onReview: () => reviewed = true);
    await tester.tap(
      find.byKey(const Key('asset_calendar_shortfall_payment_evidence')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('支払元: Synthetic bank / 確定請求額'),
      findsOneWidget,
    );
    expect(
      find.textContaining('支払元: 未設定・未確認 / 予定額（未照合）'),
      findsOneWidget,
    );
    expect(reviewed, isFalse);
    final action = find.byKey(
      const Key('asset_calendar_review_shortfall_evidence'),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    expect(reviewed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planned income is visibly unconfirmed', (tester) async {
    await pumpEvidence(tester, withIncomePlan: true);
    expect(
      find.text('この見込みには入金予定¥2,000を含みます（着金未確認）。'),
      findsOneWidget,
    );
  });

  testWidgets('date-only balances do not claim a midnight observation',
      (tester) async {
    await pumpEvidence(tester, balanceRecordedOn: DateTime(2026, 10, 14));
    expect(find.text('残高記録日: 2026/10/14（時刻不明）'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
  });
}

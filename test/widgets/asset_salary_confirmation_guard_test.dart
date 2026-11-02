import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_salary_amount_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:my_web_app/services/asset_salary_reconciliation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> pumpSalaryCandidate(
  WidgetTester tester, {
  required bool balanceJump,
  bool payslipOnly = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AssetSalaryResetMarkerStore.prefsKey: '2026-04',
    AssetSalaryAmountStore.prefsKey: 200000.0,
  });
  const store = AssetLiabilityMonthlyStateStore();
  await store.saveMonth(
    month: DateTime(2026, 4),
    state: const AssetLiabilityMonthlyState(
      paidAccountNames: {'synthetic_rent'},
      actualPaymentAmounts: {'synthetic_rent': 10000},
    ),
  );
  await store.saveMonth(
    month: DateTime(2026, 5),
    state: AssetLiabilityMonthlyState(
      incomePlans: [
        AssetLiabilityIncomePlan(
          id: 'synthetic_salary_plan',
          name: '給料',
          date: DateTime(2026, 5, 25),
          amount: 200000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: false,
        ),
      ],
    ),
  );
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: DateTime(2026, 6, 20),
        debugInitialAssetData: {
          '2026-05-24': const {'銀行A': 1000, '現金': 0},
          '2026-06-20': {'銀行A': balanceJump ? 201000 : 1000, '現金': 0},
        },
        debugInitialPayslipSalaryIncomes: payslipOnly
            ? const [
                {'pay_date': '2026-05-25', 'amount': 200000},
              ]
            : const [],
        debugInitialRecentFlows: balanceJump || payslipOnly
            ? const []
            : const [
                {
                  'id': 1,
                  'action_type': 'conquer',
                  'amount': 200000,
                  'description': '給与とは未確認の別種入金',
                  'occurred_at': '2026-06-10T04:00:00Z',
                },
              ],
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> expectUnconfirmedState() async {
  expect(await const AssetSalaryResetMarkerStore().load(), '2026-04');
  const store = AssetLiabilityMonthlyStateStore();
  expect(
    (await store.loadMonth(DateTime(2026, 4))).paidAccountNames,
    contains('synthetic_rent'),
  );
  expect(
    (await store.loadMonth(DateTime(2026, 5))).incomePlans.single.received,
    isFalse,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  for (final balanceJump in [false, true]) {
    testWidgets(
        'salary candidate does not confirm payment, balanceJump=$balanceJump',
        (tester) async {
      await pumpSalaryCandidate(tester, balanceJump: balanceJump);
      expect(find.text('給与の口座入金は未確認です'), findsOneWidget);
      expect(
        find.byKey(const Key('asset_salary_deposit_candidate')),
        findsOneWidget,
      );
      await expectUnconfirmedState();
      final reset = find.text('給料を受け取った（リセット）');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await tester.pump(const Duration(milliseconds: 400));
      await expectUnconfirmedState();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('only explicit local confirmation advances the salary cycle',
      (tester) async {
    await pumpSalaryCandidate(tester, balanceJump: false);
    await expectUnconfirmedState();
    final reset = find.text('給料を受け取った（リセット）');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'リセット'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await const AssetSalaryResetMarkerStore().load(), '2026-05');
    const store = AssetLiabilityMonthlyStateStore();
    expect(
      (await store.loadMonth(DateTime(2026, 4))).paidAccountNames,
      contains('synthetic_rent'),
    );
    expect(
      (await store.loadMonth(DateTime(2026, 5))).incomePlans.single.received,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('payslip accounting does not confirm a bank deposit',
      (tester) async {
    await pumpSalaryCandidate(tester, balanceJump: false, payslipOnly: true);
    expect(find.text('給与の口座入金は未確認です'), findsOneWidget);
    expect(await const AssetSalaryResetMarkerStore().load(), '2026-04');
    final accounting = AssetSalaryReconciliationService.reconcile(
      monthlyIncomePlans: const [],
      payslipRows: const [],
      payslipSalaryIncomes: const [
        {'pay_date': '2026-05-25', 'amount': 200000},
      ],
      baseDate: DateTime(2026, 6, 20),
    );
    expect(accounting.single.received, isTrue);
    expect(accounting.single.amount, 200000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

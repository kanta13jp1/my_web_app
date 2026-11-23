import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_spending_value_classification_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';
import 'package:my_web_app/widgets/asset_payment_reminder_and_late_fee_card.dart';
import 'package:my_web_app/widgets/asset_spending_value_ratio_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemorySpendingReminderRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemorySpendingReminderRepository(this._state);

  final AssetLiabilityMonthlyState _state;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return _state;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {}
}

Future<void> _unmountPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        const headers = <String, String>{'content-type': 'application/json'};
        final isExternalPointsRead = request.method == 'GET' &&
            request.url.path == '/rest/v1/asset_pref_mirror' &&
            request.url.queryParameters['pref_key'] == 'eq.external_points_v1';
        if (isExternalPointsRead) {
          return http.Response('[]', 200, headers: headers, request: request);
        }
        return http.Response(
          '{"message":"Unexpected HTTP request during spending/reminder UI test"}',
          400,
          headers: headers,
          request: request,
        );
      }),
    );
  });

  group('AssetSpendingValueRatioDashboard (#1368)', () {
    testWidgets(
        'renders pie chart, supports reclassification and CSV import on 390x844 mobile',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final baseEntries = <SalarySpendingEntry>[
        SalarySpendingEntry(
          date: DateTime(2026, 6, 1),
          amount: 50000,
          description: 'スーパー食費',
          sourceLabel: '収支履歴',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 6, 2),
          amount: 10000,
          description: 'ATM手数料',
          sourceLabel: '銀行',
        ),
        SalarySpendingEntry(
          date: DateTime(2026, 6, 3),
          amount: 10000,
          description: '使途不明金（自動記録）',
          sourceLabel: '残高差分',
        ),
      ];
      final overrides = <String, SpendingValueCategory>{};
      final customEntries = <AssetSpendingValueCustomEntry>[];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final report =
                  AssetSpendingValueClassificationService.buildReport(
                entries: baseEntries,
                customEntries: customEntries,
                overrides: overrides,
              );
              return Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: AssetSpendingValueRatioDashboard(
                    report: report,
                    onReclassifyEntry: (fp, cat) {
                      setState(() => overrides[fp] = cat);
                    },
                    onAddCustomEntries: (added) {
                      setState(() => customEntries.addAll(added));
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const Key('asset_spending_value_ratio_dashboard_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('spending_value_ratio_pie_chart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('spending_value_needs_review_chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('spending_value_advice_box')),
        findsOneWidget,
      );

      final unknownFp = AssetSpendingValueClassificationService.fingerprintFor(
        baseEntries[2],
      );
      final chip = find.byKey(
        Key('spending_value_set_${unknownFp}_investment'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('spending_value_needs_review_chip')),
        findsNothing,
      );

      final addBtn = find.byKey(
        const Key('spending_value_add_or_import_button'),
      );
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('spending_value_csv_field')),
        '2026-06-05,20000,技術書,投資',
      );
      final importBtn = find.byKey(
        const Key('spending_value_csv_import_button'),
      );
      await tester.ensureVisible(importBtn);
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('技術書'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AssetPaymentReminderBanner (#2749)', () {
    testWidgets(
        'renders overdue late-fee guidance, triggers early contact/guide callbacks, and saves custom rate on mobile',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var contactOpened = false;
      var guideOpened = false;
      var notifyCount = 0;
      var settings = const AssetPaymentReminderSettings(
        daysBefore: <int>[3, 1, 0],
        customLateFeeAnnualRates: <String, double>{'mobit': 0.20},
      );
      final delivered = <String>{};

      final workbook = AssetLiabilityWorkbook(
        baseDate: DateTime(2026, 6, 10),
        accounts: const <AssetLiabilityAccount>[],
        debtMasterRows: <AssetLiabilityDebtRow>[
          const AssetLiabilityDebtRow(
            id: 'mobit',
            name: 'モビット',
            kind: AssetLiabilityAccountKind.cardLoan,
            balance: -200000,
            paymentDay: 5,
            paymentSourceAccountId: 'smbc_otsuka',
            paymentSourceAccountName: '三井住友銀行大塚支店',
            paymentMethod: AssetLiabilityPaymentMethod.direct,
            paymentMethodLabel: '直接支払い',
            paymentMethodSettingSource:
                AssetLiabilityPaymentMethodSettingSource.builtInDefault,
            billingAccountId: null,
            billingAccountName: null,
            includedInBillingAccount: false,
            annualRate: 0.146,
            minimumPaymentEstimate: 36500,
            manualPaymentAmount: 36500,
            scheduledPaymentAmount: 36500,
            monthlyInterestEstimate: 2400,
            principalPaymentEstimate: 34100,
            balanceAfterPaymentEstimate: -165900,
            liabilityShare: 1.0,
            priorityLabel: '最優先',
            paymentAmountEstimated: false,
            billingConfirmed: true,
            paid: false,
            requiresAction: true,
            lateFeeAnnualRate: 0.20,
            overdueDays: 5,
            estimatedLateFeeAmount: 100,
          ),
        ],
        repaymentPriorityRows: const <AssetLiabilityDebtRow>[],
        paymentDayRisks: const <AssetLiabilityPaymentDayRisk>[],
        cashflowRows: const <AssetLiabilityCashflowRow>[],
        incomePlans: const <AssetLiabilityIncomePlan>[],
        transferTasks: const <AssetLiabilityTransferTask>[],
        accountCashflowSummaries: const <AssetLiabilityAccountCashflowSummary>[],
        transferSuggestions: const <AssetLiabilityTransferSuggestion>[],
        cardBillingReview: const AssetLiabilityCardBillingReviewData(
          directPaymentItems: <AssetLiabilityCardBillingReviewItem>[],
          cardBillingGroups: <AssetLiabilityCardBillingGroup>[],
          missingBillingAccountItems: <AssetLiabilityCardBillingReviewItem>[],
          needsReviewItems: <AssetLiabilityCardBillingReviewItem>[],
          doubleCountingRiskItems: <AssetLiabilityCardBillingReviewItem>[],
        ),
        cardStatementReconciliation:
            const AssetLiabilityCardStatementReconciliationData(
          groups: <AssetLiabilityCardStatementReconciliationGroup>[],
          unmatchedStatementLines: <AssetLiabilityCardStatementLine>[],
        ),
        cashLikeTotal: 100000,
        securitiesTotal: 0,
        positiveAssetTotal: 100000,
        liabilityTotal: -200000,
        netWorth: -100000,
        monthlyMinimumPaymentEstimateTotal: 36500,
        monthlyScheduledPaymentTotal: 36500,
        monthlyActualPaymentTotal: 0,
        monthlyPaymentDifferenceTotal: 0,
        monthlyUnpaidPaymentTotal: 36500,
        monthlyUnreceivedIncomeTotal: 0,
        cashAfterMinimumPayments: 63500,
        cashAfterScheduledPayments: 63500,
        debtToAssetRatio: 2.0,
        topFourDebtShare: 1.0,
        manualPaymentCount: 1,
        estimatedPaymentCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final schedule = AssetPaymentReminderService.buildSchedule(
                workbook: workbook,
                salaryDay: 25,
                settings: settings,
              );
              return Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: AssetPaymentReminderBanner(
                    workbook: workbook,
                    schedule: schedule,
                    settings: settings,
                    deliveredKeys: delivered,
                    onSettingsChanged: (next) =>
                        setState(() => settings = next),
                    onTriggerNotifications: () async {
                      final next =
                          await AssetPaymentReminderService.dispatchUndelivered(
                        schedule: schedule,
                        alreadyDeliveredKeys: delivered,
                        notifier: (_) async {
                          notifyCount++;
                          return true;
                        },
                      );
                      setState(() => delivered.addAll(next));
                    },
                    onOpenCreditorContact: () => contactOpened = true,
                    onOpenConsultationGuide: () => guideOpened = true,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const Key('asset_payment_reminder_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('payment_reminder_overdue_guidance_box')),
        findsOneWidget,
      );
      expect(find.textContaining('5日超過'), findsOneWidget);

      await tester
          .tap(find.byKey(const Key('payment_reminder_send_now_button')));
      await tester.pump();
      expect(notifyCount, 1);

      await tester.tap(
        find.byKey(const Key('payment_reminder_open_creditor_contact_button')),
      );
      await tester.tap(
        find.byKey(
          const Key('payment_reminder_open_consultation_guide_button'),
        ),
      );
      expect(contactOpened, isTrue);
      expect(guideOpened, isTrue);

      await tester
          .tap(find.byKey(const Key('payment_reminder_settings_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('payment_reminder_rate_field_mobit')),
        '18.0',
      );
      await tester.tap(
        find.byKey(const Key('payment_reminder_settings_save_button')),
      );
      await tester.pumpAndSettle();
      expect(settings.customRateFor('mobit'), closeTo(0.18, 0.001));
    });
  });

  group('AssetManagementPage #1368 & #2749 integration', () {
    testWidgets(
        'renders spending value dashboard and overdue payment reminder banner on desktop',
        (tester) async {
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      AssetRecurringTombstoneSyncService.resetSharedForTest();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'full',
      });

      final now = DateTime(2026, 6, 16);
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final repo = _InMemorySpendingReminderRepository(
        const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 25000},
          confirmedPaymentDays: <String, double>{'mobit': 5},
        ),
      );
      final notifiedAccounts = <String>[];

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: now,
            assetLiabilityRepository: repo,
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '三井住友銀行大塚支店': 500000,
                'モビット': -200000,
              },
            },
            debugPaymentReminderNotifier: (item) async {
              notifiedAccounts.add(item.accountId);
              return true;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final dashboard = find.byKey(
        const Key('asset_spending_value_ratio_dashboard_card'),
      );
      expect(dashboard, findsOneWidget);

      final reminderBanner = find.byKey(
        const Key('asset_payment_reminder_banner'),
      );
      expect(reminderBanner, findsOneWidget);
      await tester.ensureVisible(reminderBanner);
      await tester.pump();
      await tester
          .tap(find.byKey(const Key('payment_reminder_send_now_button')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(notifiedAccounts, contains('mobit'));
      expect(tester.takeException(), isNull);

      await _unmountPage(tester);
    });
  });
}

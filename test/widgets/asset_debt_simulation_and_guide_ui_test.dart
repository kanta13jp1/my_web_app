import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_debt_danger_service.dart';
import 'package:my_web_app/services/asset_debt_simulation_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_debt_simulation_and_guide_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryDebtGuideRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemoryDebtGuideRepository(this._state);

  AssetLiabilityMonthlyState _state;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return _state;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    _state = state;
  }
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
          '{"message":"Unexpected HTTP request during debt sim test"}',
          400,
          headers: headers,
          request: request,
        );
      }),
    );
  });

  group('MultiDebtPrepaymentSimulatorDialog (#1369)', () {
    testWidgets(
      'adds debt item, shows daily interest, and calculates avalanche savings',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const initialDebts = <MultiDebtInputItem>[
          MultiDebtInputItem(
            id: 'acom',
            name: 'アコム',
            balance: 300000,
            annualRate: 0.15,
            monthlyPayment: 12000,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => MultiDebtPrepaymentSimulatorDialog.show(
                    context,
                    initialDebts: initialDebts,
                  ),
                  child: const Text('open_multi'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_multi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const Key('multi_debt_daily_interest_section')),
          findsOneWidget,
        );
        expect(find.textContaining('アコム'), findsWidgets);

        await tester.tap(find.byKey(const Key('multi_debt_add_button')));
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('multi_debt_name_field')),
          'モビット',
        );
        await tester.enterText(
          find.byKey(const Key('multi_debt_balance_field')),
          '400000',
        );
        await tester.enterText(
          find.byKey(const Key('multi_debt_rate_field')),
          '18.0',
        );
        await tester.enterText(
          find.byKey(const Key('multi_debt_payment_field')),
          '15000',
        );
        await tester.ensureVisible(
          find.byKey(const Key('multi_debt_add_confirm_button')),
        );
        await tester
            .tap(find.byKey(const Key('multi_debt_add_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('モビット'), findsWidgets);
        await tester.ensureVisible(
          find.byKey(const Key('multi_debt_extra_amount_field')),
        );
        await tester.enterText(
          find.byKey(const Key('multi_debt_extra_amount_field')),
          '50000',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('multi_debt_allocation_summary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('multi_debt_savings_summary')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('DebtConsolidationSimulatorDialog (#2750)', () {
    testWidgets(
      'displays comparison bars, neutral overpayment notice, and long-term warning',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const debts = <MultiDebtInputItem>[
          MultiDebtInputItem(
            id: 'mobit',
            name: 'モビット',
            balance: 500000,
            annualRate: 0.18,
            monthlyPayment: 20000,
          ),
          MultiDebtInputItem(
            id: 'acom',
            name: 'アコム',
            balance: 400000,
            annualRate: 0.15,
            monthlyPayment: 15000,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => DebtConsolidationSimulatorDialog.show(
                    context,
                    initialDebts: debts,
                  ),
                  child: const Text('open_consolidation'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_consolidation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const Key('consolidation_comparison_chart')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('consolidation_legal_disclaimer')),
          findsOneWidget,
        );
        expect(find.textContaining('過払い金'), findsWidgets);

        await tester.enterText(
          find.byKey(const Key('consolidation_rate_field')),
          '14.5',
        );
        await tester.enterText(
          find.byKey(const Key('consolidation_term_field')),
          '120',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('consolidation_interest_increase_warning')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AssetManagementPage debt danger & simulators (#1369/#2750/#1370)', () {
    testWidgets(
      'renders danger banner from stagnant snapshots, persists threshold, and launches consultation link',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });

        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemoryDebtGuideRepository(
          const AssetLiabilityMonthlyState(),
        );
        final openedUrls = <Uri>[];
        final snapshots = <AssetLiabilityMonthlySnapshot>[
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-04',
            savedAt: DateTime(2026, 4, 30),
            positiveAssetTotal: 100000,
            liabilityTotal: -500000,
            netWorth: -400000,
            cashLikeTotal: 100000,
            monthlyScheduledPaymentTotal: 25000,
            monthlyPaidPaymentTotal: 0,
            monthlyUnpaidPaymentTotal: 25000,
            overduePaymentCount: 0,
          ),
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-05',
            savedAt: DateTime(2026, 5, 31),
            positiveAssetTotal: 100000,
            liabilityTotal: -510000,
            netWorth: -410000,
            cashLikeTotal: 100000,
            monthlyScheduledPaymentTotal: 25000,
            monthlyPaidPaymentTotal: 0,
            monthlyUnpaidPaymentTotal: 25000,
            overduePaymentCount: 0,
          ),
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-06',
            savedAt: DateTime(2026, 6, 10),
            positiveAssetTotal: 100000,
            liabilityTotal: -520000,
            netWorth: -420000,
            cashLikeTotal: 100000,
            monthlyScheduledPaymentTotal: 25000,
            monthlyPaidPaymentTotal: 0,
            monthlyUnpaidPaymentTotal: 25000,
            overduePaymentCount: 0,
          ),
        ];

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo,
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '三井住友銀行大塚支店': 50000,
                  'モビット': -520000,
                },
              },
              debugInitialMonthlySnapshots: snapshots,
              debugOpenExternalUrl: (uri) async {
                openedUrls.add(uri);
                return true;
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('asset_debt_danger_consultation_banner')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('asset_debt_danger_open_guide_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('debt_relief_overview_section')),
          findsOneWidget,
        );
        expect(find.textContaining('任意整理'), findsWidgets);
        expect(find.textContaining('個人再生'), findsWidgets);
        expect(find.textContaining('自己破産'), findsWidgets);

        final houterasuFinder = find.byKey(
          const Key('debt_consultation_link_houterasu'),
        );
        await tester.ensureVisible(houterasuFinder);
        await tester.pump();
        await tester.tap(houterasuFinder);
        await tester.pump();

        expect(openedUrls, isNotEmpty);
        expect(openedUrls.first.toString(), 'https://www.houterasu.or.jp/');

        final months6Chip = find.byKey(const Key('debt_danger_months_chip_6'));
        await tester.ensureVisible(months6Chip);
        await tester.pump();
        await tester.tap(months6Chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final persisted = await AssetDebtDangerSettingsStore.load();
        expect(persisted.stagnantMonthsThreshold, 6);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('閉じる'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('asset_debt_danger_consultation_banner')),
          findsNothing,
        );

        final multiBtn = find.byKey(
          const Key('asset_open_multi_debt_simulator_button'),
        );
        await tester.ensureVisible(multiBtn);
        await tester.pump();
        await tester.tap(multiBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('multi_debt_daily_interest_section')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('閉じる'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final consolidationBtn = find.byKey(
          const Key('asset_open_consolidation_simulator_button'),
        );
        await tester.ensureVisible(consolidationBtn);
        await tester.pump();
        await tester.tap(consolidationBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('consolidation_comparison_chart')),
          findsOneWidget,
        );

        await _unmountPage(tester);
      },
    );
  });
}

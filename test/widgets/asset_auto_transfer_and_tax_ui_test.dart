import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_auto_transfer_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/services/asset_tax_deduction_service.dart';
import 'package:my_web_app/widgets/asset_auto_transfer_and_tax_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryAutoTransferTaxRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemoryAutoTransferTaxRepository(this._state);

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
          '{"message":"Unexpected HTTP request during auto transfer/tax test"}',
          400,
          headers: headers,
          request: request,
        );
      }),
    );
  });

  group('FurusatoTaxCalculatorDialog (#2490)', () {
    testWidgets(
        'shows 61,000 limit for 5M salary and updates cleanly on mobile', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => FurusatoTaxCalculatorDialog.show(context),
                child: const Text('open_furusato'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open_furusato'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('furusato_result_card')), findsOneWidget);
      expect(find.textContaining('61,000円'), findsOneWidget);

      await tester.tap(find.byKey(const Key('furusato_marital_spouse')));
      await tester.pump();
      expect(find.textContaining('61,000円'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('MedicalExpenseTrackerDialog (#2491)', () {
    testWidgets('tracks entries and updates threshold alert banner', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var saved = <MedicalExpenseEntry>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => MedicalExpenseTrackerDialog.show(
                  context,
                  initialEntries: const <MedicalExpenseEntry>[],
                  taxYear: 2026,
                  onEntriesChanged: (next) => saved = next,
                ),
                child: const Text('open_medical'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open_medical'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const Key('medical_entry_amount_field')),
      );
      await tester.enterText(
        find.byKey(const Key('medical_entry_amount_field')),
        '85000',
      );
      await tester.ensureVisible(
        find.byKey(const Key('medical_entry_add_button')),
      );
      await tester.tap(find.byKey(const Key('medical_entry_add_button')));
      await tester.pump();

      expect(
        find.byKey(const Key('medical_expense_threshold_alert')),
        findsOneWidget,
      );
      expect(find.textContaining('あと 15,000円'), findsOneWidget);

      await tester.tap(find.byKey(const Key('medical_category_chip_pharmacy')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('medical_entry_amount_field')),
        '30000',
      );
      await tester.ensureVisible(
        find.byKey(const Key('medical_entry_add_button')),
      );
      await tester.tap(find.byKey(const Key('medical_entry_add_button')));
      await tester.pump();

      expect(saved, hasLength(2));
      expect(find.textContaining('15,000円'), findsWidgets);
      expect(find.byKey(const Key('medical_expense_category_breakdown')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AssetManagementPage auto-transfer & tax flag (#3443/#2490/#2491)', () {
    testWidgets(
      'keeps tax tools OFF by default, toggles ON, and auto-creates audited transfer task once',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });

        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemoryAutoTransferTaxRepository(
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'aupay_card': 50000},
            paymentSourceAccountIds: <String, String>{
              'aupay_card': 'jibun_bank',
            },
          ),
        );

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo,
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '三井住友銀行大塚支店': 500000,
                  'auじぶん銀行': 10000,
                  'auPayカード': -50000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // #2490 / #2491 tax tools are hidden behind OFF-default feature flag.
        expect(
          find.byKey(const Key('asset_open_furusato_calculator_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('asset_open_medical_expense_tracker_button')),
          findsNothing,
        );

        final flagToggle = find.byKey(
          const Key('asset_tax_tools_feature_flag_toggle'),
        );
        await tester.ensureVisible(flagToggle);
        await tester.pump();
        await tester.tap(flagToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('asset_open_furusato_calculator_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('asset_open_medical_expense_tracker_button')),
          findsOneWidget,
        );
        expect(await AssetTaxToolsFeatureFlagStore.load(), isTrue);

        // #3443: Open auto-transfer settings from shortage card, enable autoCreateTask.
        final autoBtn = find.byKey(
          const Key('asset_auto_transfer_settings_button'),
        );
        await tester.ensureVisible(autoBtn);
        await tester.pump();
        await tester.tap(autoBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('auto_transfer_candidates_section')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('auto_transfer_enabled_switch')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('auto_transfer_mode_auto')));
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('閉じる'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 200));

        final auditLogs = await AssetAutoTransferStore.loadAuditLogs();
        expect(auditLogs, hasLength(1));
        expect(auditLogs.first.status, 'auto_created');
        expect(auditLogs.first.toAccountId, 'jibun_bank');
        expect(repo._state.transferTasks, hasLength(1));

        await _unmountPage(tester);
      },
    );
  });
}

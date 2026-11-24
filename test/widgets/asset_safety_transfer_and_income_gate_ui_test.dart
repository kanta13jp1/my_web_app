import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_safety_transfer_suggestion_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_safety_transfer_and_income_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _safetyCardKey = Key('asset_safety_transfer_suggestions_card');
const _incomeMissingBannerKey = Key('asset_income_plan_missing_banner');
const _incomeOpenWizardBtnKey = Key('asset_income_plan_open_wizard_button');
const _incomeConfirmDialogKey = Key('asset_income_missing_confirm_dialog');
const _incomeCancelBtnKey = Key('asset_income_missing_cancel_button');
const _incomeWizardDayKey = Key('income_wizard_day_field');
const _incomeWizardAmountKey = Key('income_wizard_amount_field');
const _incomeWizardSaveKey = Key('income_wizard_save_button');
const _mobitSeverityKey = Key('asset_missing_source_severity_mobit');
const _mobitGuideBtnKey = Key('asset_missing_source_guide_mobit');
const _openJibunWizardKey = Key('asset_safety_transfer_wizard_open_jibun_bank');
const _safetyAmountKey = Key('safety_transfer_amount_field');
const _safetySubmitKey = Key('safety_transfer_submit_button');
const _applySmbcGuideKey = Key('missing_source_guide_apply_smbc_otsuka_branch');

class _InMemorySafetyGateRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemorySafetyGateRepository(this._state);

  AssetLiabilityMonthlyState _state;
  List<AssetLiabilityRecurringIncomeTemplate> savedTemplates =
      <AssetLiabilityRecurringIncomeTemplate>[];

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

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {
    savedTemplates =
        List<AssetLiabilityRecurringIncomeTemplate>.from(templates);
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
          '{"message":"Unexpected HTTP request during safety gate widget test"}',
          400,
          headers: headers,
          request: request,
        );
      }),
    );
  });

  group('Safety transfer, income gate & funding guide dialogs', () {
    testWidgets(
      'AssetSafetyTransferWizardDialog edits amount and submits (#3350)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        AssetLiabilityTransferSuggestion? submitted;
        final suggestion = AssetSafetyTransferSuggestion(
          fromAccountId: 'smbc_otsuka_branch',
          fromAccountName: '三井住友銀行大塚支店',
          toAccountId: 'jibun_bank',
          toAccountName: 'じぶん銀行',
          amount: 7000,
          neededBy: DateTime(2026, 6, 20),
          projectedBalanceBefore: 3000,
          minimumSafetyBalance: 10000,
          isSameBankFreeTransfer: false,
          reason: 'じぶん銀行の見込み残高が安全残高を下回っています',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    submitted =
                        await showDialog<AssetLiabilityTransferSuggestion>(
                      context: context,
                      builder: (_) => AssetSafetyTransferWizardDialog(
                        suggestion: suggestion,
                        donorOptions: const <AssetLiabilityAccount>[
                          AssetLiabilityAccount(
                            id: 'smbc_otsuka_branch',
                            name: '三井住友銀行大塚支店',
                            balance: 100000,
                            kind: AssetLiabilityAccountKind.deposit,
                          ),
                          AssetLiabilityAccount(
                            id: 'yokohama_bank',
                            name: '横浜銀行',
                            balance: 80000,
                            kind: AssetLiabilityAccountKind.deposit,
                          ),
                        ],
                        baseDate: DateTime(2026, 6, 10),
                      ),
                    );
                  },
                  child: const Text('open_wizard'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_wizard'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(_safetyAmountKey), '12000');
        await tester.pump();
        final submitBtn = find.byKey(_safetySubmitKey);
        await tester.ensureVisible(submitBtn);
        await tester.pump();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(submitted, isNotNull);
        expect(submitted!.amount, 12000);
        expect(submitted!.fromAccountId, 'smbc_otsuka_branch');
        expect(submitted!.toAccountId, 'jibun_bank');
      },
    );

    testWidgets(
      'AssetIncomePlanPaydayWizardDialog validates invalid & returns draft (#3291)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        AssetIncomePlanPaydayDraft? draft;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    draft = await showDialog<AssetIncomePlanPaydayDraft>(
                      context: context,
                      builder: (_) => AssetIncomePlanPaydayWizardDialog(
                        destinationOptions: const <AssetLiabilityAccount>[
                          AssetLiabilityAccount(
                            id: 'smbc_otsuka_branch',
                            name: '三井住友銀行大塚支店',
                            balance: 50000,
                            kind: AssetLiabilityAccountKind.deposit,
                          ),
                        ],
                        baseDate: DateTime(2026, 6, 10),
                      ),
                    );
                  },
                  child: const Text('open_income'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_income'));
        await tester.pumpAndSettle();

        // Missing amount triggers inline error instead of popping dialog.
        await tester.tap(find.byKey(_incomeWizardSaveKey));
        await tester.pump();
        expect(
          find.byKey(const Key('income_wizard_error_text')),
          findsOneWidget,
        );
        expect(draft, isNull);

        await tester.enterText(find.byKey(_incomeWizardDayKey), '25');
        await tester.enterText(find.byKey(_incomeWizardAmountKey), '260000');
        await tester.pump();
        await tester.tap(find.byKey(_incomeWizardSaveKey));
        await tester.pumpAndSettle();

        expect(draft, isNotNull);
        expect(draft!.dayOfMonth, 25);
        expect(draft!.amount, 260000);
        expect(draft!.registerAsRecurring, isTrue);
        expect(draft!.destinationAccountId, 'smbc_otsuka_branch');
      },
    );

    testWidgets(
      'MissingPaymentSourceGuideDialog applies selected candidate (#4059)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? chosenId;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    chosenId = await showDialog<String>(
                      context: context,
                      builder: (_) => const MissingPaymentSourceGuideDialog(
                        accountName: 'モビット',
                        paymentDay: 26,
                        scheduledAmount: 20000,
                        options: <MissingPaymentSourceGuideOption>[
                          MissingPaymentSourceGuideOption(
                            accountId: 'smbc_otsuka_branch',
                            accountName: '三井住友銀行大塚支店',
                            currentBalance: 120000,
                            projectedAfterPayment: 100000,
                            recommended: true,
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('open_guide'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_guide'));
        await tester.pumpAndSettle();

        expect(find.text('余裕あり'), findsOneWidget);
        await tester.tap(find.byKey(_applySmbcGuideKey));
        await tester.pumpAndSettle();

        expect(chosenId, 'smbc_otsuka_branch');
      },
    );
  });

  group('AssetManagementPage end-to-end UX flows', () {
    testWidgets(
      'Safety balance transfer card creates task and clears suggestion (#3350)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemorySafetyGateRepository(
          const AssetLiabilityMonthlyState(),
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
                  'じぶん銀行': 3000,
                  '三井住友銀行大塚支店': 150000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_safetyCardKey), findsOneWidget);
        final openBtn = find.byKey(_openJibunWizardKey);
        await tester.ensureVisible(openBtn);
        await tester.pump();
        await tester.tap(openBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(_safetySubmitKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_safetyCardKey), findsNothing);
        await _unmountPage(tester);
      },
    );

    testWidgets(
      'Income gate warns before billing confirmation and clears via payday wizard (#3291)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemorySafetyGateRepository(
          const AssetLiabilityMonthlyState(),
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
                  '三井住友銀行大塚支店': 150000,
                  'モビット': -100000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_incomeMissingBannerKey), findsOneWidget);

        // Tapping 'この額で確定' shows cancelable warning dialog while income is unset.
        final confirmBtn = find.text('この額で確定').first;
        await tester.ensureVisible(confirmBtn);
        await tester.pump();
        await tester.tap(confirmBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_incomeConfirmDialogKey), findsOneWidget);
        await tester.tap(find.byKey(_incomeCancelBtnKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('この額で確定'), findsOneWidget);

        // Opening payday wizard from top banner and saving hides banner.
        final wizardOpenBtn = find.byKey(_incomeOpenWizardBtnKey);
        await tester.ensureVisible(wizardOpenBtn);
        await tester.pump();
        await tester.tap(wizardOpenBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(find.byKey(_incomeWizardAmountKey), '250000');
        await tester.pump();
        await tester.tap(find.byKey(_incomeWizardSaveKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_incomeMissingBannerKey), findsNothing);
        expect(repo.savedTemplates, hasLength(1));

        await _unmountPage(tester);
      },
    );

    testWidgets(
      'Missing payment source guide resolves unset source via 1-tap (#4059)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemorySafetyGateRepository(
          const AssetLiabilityMonthlyState(),
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
                  '三井住友銀行大塚支店': 200000,
                  'モビット': -90000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_mobitSeverityKey), findsOneWidget);
        final guideBtn = find.byKey(_mobitGuideBtnKey);
        await tester.ensureVisible(guideBtn);
        await tester.pump();
        await tester.tap(guideBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(_applySmbcGuideKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_mobitGuideBtnKey), findsNothing);
        await _unmountPage(tester);
      },
    );
  });
}

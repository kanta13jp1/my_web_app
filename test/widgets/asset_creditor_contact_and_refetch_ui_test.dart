import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/contact_log.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/services/card_statement_refetch_service.dart';
import 'package:my_web_app/widgets/asset_creditor_contact_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _openContactBtnKey = Key('asset_payment_consultation_contact_mobit');
const _contactedBadgeKey = Key('asset_payment_consultation_contacted_mobit');
const _reminderBannerKey = Key('asset_creditor_contact_reminder_banner');
const _reduceMinChipKey = Key('creditor_template_kind_reduceMinimum');
const _contactAgreementFieldKey = Key('creditor_contact_agreement_field');
const _contactSaveBtnKey = Key('creditor_contact_save_button');
const _contactRetryBtnKey = Key('creditor_contact_retry_button');
const _contactErrorTextKey = Key('creditor_contact_error_text');
const _refetchBtnKey = Key('asset_card_statement_refetch_aupay_card');
const _refetchStatusKey = Key('asset_card_statement_import_status_aupay_card');
const _refetchManualBtnKey =
    Key('asset_card_statement_refetch_manual_aupay_card');
const _reconBannerKey = Key('asset_card_reconciliation_needs_review_banner');

class _InMemoryContactRefetchRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemoryContactRefetchRepository(this._state);

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
          '{"message":"Unexpected HTTP request during contact/refetch test"}',
          400,
          headers: headers,
          request: request,
        );
      }),
    );
  });

  group('Creditor contact & bulk log dialogs (#3292 / #3288)', () {
    testWidgets(
      'CreditorContactTemplateAndLogDialog switches template and retries on error',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var shouldFail = true;
        CreditorContactLog? savedLog;
        const row = AssetLiabilityDebtRow(
          id: 'mobit',
          name: 'モビット',
          kind: AssetLiabilityAccountKind.cardLoan,
          balance: -100000,
          paymentDay: 12,
          paymentSourceAccountId: 'smbc_otsuka_branch',
          paymentSourceAccountName: '三井住友銀行大塚支店',
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentMethodLabel: '直接支払',
          paymentMethodSettingSource:
              AssetLiabilityPaymentMethodSettingSource.builtInDefault,
          billingAccountId: null,
          billingAccountName: null,
          includedInBillingAccount: false,
          annualRate: 0.18,
          minimumPaymentEstimate: 5000,
          manualPaymentAmount: null,
          scheduledPaymentAmount: 5000,
          monthlyInterestEstimate: 1500,
          principalPaymentEstimate: 3500,
          balanceAfterPaymentEstimate: -96500,
          liabilityShare: 1.0,
          priorityLabel: '高',
          paymentAmountEstimated: false,
          billingConfirmed: true,
          paid: false,
          requiresAction: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    savedLog = await showDialog<CreditorContactLog>(
                      context: context,
                      builder: (_) => CreditorContactTemplateAndLogDialog(
                        row: row,
                        dueDate: DateTime(2026, 6, 12),
                        baseDate: DateTime(2026, 6, 10),
                        existingLogs: const <CreditorContactLog>[],
                        onSaveLog: (_) async {
                          if (shouldFail) {
                            throw StateError('temporary error');
                          }
                        },
                      ),
                    );
                  },
                  child: const Text('open_contact'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_contact'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_reduceMinChipKey));
        await tester.pump();
        final previewField = tester.widget<TextField>(
          find.byKey(const Key('creditor_template_preview')),
        );
        expect(previewField.controller!.text, contains('最低返済額'));

        await tester.enterText(
          find.byKey(_contactAgreementFieldKey),
          '今月最低額を減額相談済み',
        );
        await tester.tap(find.byKey(_contactSaveBtnKey));
        await tester.pump();

        expect(find.byKey(_contactErrorTextKey), findsOneWidget);
        expect(find.byKey(_contactRetryBtnKey), findsOneWidget);
        expect(savedLog, isNull);

        shouldFail = false;
        await tester.ensureVisible(find.byKey(_contactRetryBtnKey));
        await tester.pump();
        await tester.tap(find.byKey(_contactRetryBtnKey));
        await tester.pumpAndSettle();

        expect(savedLog, isNotNull);
        expect(savedLog!.agreedSummary, '今月最低額を減額相談済み');
        expect(
          savedLog!.templateKind,
          CreditorContactTemplateKind.reduceMinimum,
        );
      },
    );

    testWidgets(
      'BulkCreditorContactDialog records batch log and opens history tab (#3288)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final sentLogs = <CreditorContactLog>[];
        final tasks = <CreditorContactTask>[
          CreditorContactTask(
            accountId: 'mobit',
            accountName: 'モビット',
            dueDate: DateTime(2026, 6, 9),
            annualRate: 0.18,
            scheduledPaymentAmount: 5000,
            isOverdue: true,
            isHighInterest: true,
            status: CreditorContactTaskStatus.pending,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => BulkCreditorContactDialog(
                        tasks: tasks,
                        debtRows: const <AssetLiabilityDebtRow>[],
                        baseDate: DateTime(2026, 6, 10),
                        allLogs: const <CreditorContactLog>[],
                        onSaveLog: (log) async => sentLogs.add(log),
                      ),
                    );
                  },
                  child: const Text('open_bulk'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_bulk'));
        await tester.pumpAndSettle();

        expect(find.text('未連絡'), findsOneWidget);
        await tester.tap(find.byKey(const Key('bulk_contact_send_mobit')));
        await tester.pumpAndSettle();

        expect(sentLogs, hasLength(1));
        await tester.tap(find.byKey(const Key('bulk_contact_history_tab')));
        await tester.pump();
        expect(find.textContaining('モビット'), findsWidgets);
      },
    );
  });

  group('AssetManagementPage contact persistence & refetch flows', () {
    testWidgets(
      'Saving contact agreement shows badge/banner and persists across reopen (#3292 / #3288)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo1 = _InMemoryContactRefetchRepository(
          const AssetLiabilityMonthlyState(),
        );

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo1,
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '三井住友銀行大塚支店': 50000,
                  'モビット': -150000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final contactBtn = find.byKey(_openContactBtnKey);
        await tester.ensureVisible(contactBtn);
        await tester.pump();
        await tester.tap(contactBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(
          find.byKey(_contactAgreementFieldKey),
          '支払日を28日へ変更合意',
        );
        await tester.tap(find.byKey(_contactSaveBtnKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_contactedBadgeKey), findsOneWidget);
        expect(find.byKey(_reminderBannerKey), findsOneWidget);
        expect(find.textContaining('支払日を28日へ変更合意'), findsWidgets);

        await _unmountPage(tester);

        // Reopen AssetManagementPage and verify persisted agreement banner reloads.
        final repo2 = _InMemoryContactRefetchRepository(
          const AssetLiabilityMonthlyState(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo2,
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '三井住友銀行大塚支店': 50000,
                  'モビット': -150000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_reminderBannerKey), findsOneWidget);
        expect(find.textContaining('支払日を28日へ変更合意'), findsWidgets);

        await _unmountPage(tester);
      },
    );

    testWidgets(
      'Card statement refetch shows failure guide and clears needsReview on success (#3299)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemoryContactRefetchRepository(
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{
              'aupay_card': 40163,
              'au': 32152,
            },
            cardBillingAccountIds: <String, String>{
              'au': 'aupay_card',
            },
          ),
        );
        var shouldFail = true;

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo,
              debugCardStatementRefetchHandler: (group, attemptAt) async {
                if (shouldFail) {
                  return CardStatementRefetchResult(
                    status: CardStatementImportStatus(
                      billingAccountId: group.billingAccountId,
                      billingAccountName: group.billingAccountName,
                      lastAttemptAt: attemptAt,
                      lastResult: CardStatementImportResultStatus.failed,
                      provider: 'test_provider',
                      failureReason: '接続タイムアウトテスト',
                    ),
                    importedLines: const <AssetLiabilityCardStatementLine>[],
                    message: '再取得失敗: 接続タイムアウトテスト',
                  );
                }
                return CardStatementRefetchResult(
                  status: CardStatementImportStatus(
                    billingAccountId: group.billingAccountId,
                    billingAccountName: group.billingAccountName,
                    lastAttemptAt: attemptAt,
                    lastResult: CardStatementImportResultStatus.success,
                    provider: 'test_provider',
                    importedCount: 2,
                  ),
                  importedLines: <AssetLiabilityCardStatementLine>[
                    AssetLiabilityCardStatementLine(
                      id: 'refetch_line_1',
                      billingAccountId: group.billingAccountId,
                      billingAccountName: group.billingAccountName,
                      postedAt: attemptAt,
                      description: 'au利用分',
                      amount: 32152,
                    ),
                    AssetLiabilityCardStatementLine(
                      id: 'refetch_line_2',
                      billingAccountId: group.billingAccountId,
                      billingAccountName: group.billingAccountName,
                      postedAt: attemptAt,
                      description: '再取得調整明細',
                      amount: 8011,
                      isConfiguredAdjustment: true,
                    ),
                  ],
                  message: '2件を再取得しました。',
                );
              },
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '財布(現金)': 100000,
                  'auPayカード': -40163,
                  'au': -32152,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_reconBannerKey), findsOneWidget);
        final refetchBtn = find.byKey(_refetchBtnKey);
        await tester.ensureVisible(refetchBtn);
        await tester.pump();
        await tester.tap(refetchBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_refetchStatusKey), findsOneWidget);
        expect(find.textContaining('接続タイムアウトテスト'), findsWidgets);
        final manualBtn = find.byKey(_refetchManualBtnKey);
        expect(manualBtn, findsOneWidget);

        // Clicking manual entry fallback CTA opens CardManualStatementEntryDialog.
        await tester.ensureVisible(manualBtn);
        await tester.pump();
        await tester.tap(manualBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('card_manual_entry_amount_0')),
          findsOneWidget,
        );
        await tester.tap(find.text('キャンセル').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Subsequent successful refetch resolves the missing breakdown & clears banner.
        shouldFail = false;
        await tester.ensureVisible(find.byKey(_refetchBtnKey));
        await tester.pump();
        await tester.tap(find.byKey(_refetchBtnKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_reconBannerKey), findsNothing);
        await _unmountPage(tester);
      },
    );
  });
}

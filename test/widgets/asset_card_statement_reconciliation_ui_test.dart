import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_card_statement_reconciliation_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryCardReconRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _InMemoryCardReconRepository(this._state);

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

AssetLiabilityCardStatementReconciliationGroup _sampleMismatchGroup() {
  return const AssetLiabilityCardStatementReconciliationGroup(
    billingAccountId: 'aupay_card',
    billingAccountName: 'auPayカード',
    billedAmount: 40163,
    configuredDetailTotal: 32152,
    statementLineTotal: 0,
    configuredItems: <AssetLiabilityCardBillingReviewItem>[],
    statementLines: <AssetLiabilityCardStatementLine>[],
    alerts: <String>[
      AssetLiabilityPlanningService.cardStatementMissingImportAlert,
      AssetLiabilityPlanningService.cardStatementConfiguredMismatchAlert,
    ],
  );
}

Future<void> _unmountPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('Card statement reconciliation dialogs & page flows', () {
    testWidgets(
      'CardStatementManualReconciliationWizardDialog completes 3 steps (#3329)',
      (tester) async {
        CardManualReconciliationWizardResult? result;
        final group = _sampleMismatchGroup();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result =
                        await showDialog<CardManualReconciliationWizardResult>(
                      context: context,
                      builder: (_) =>
                          CardStatementManualReconciliationWizardDialog(
                        needsReviewGroups: [group],
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('1. 請求額確認'), findsOneWidget);
        expect(find.text('¥40,163'), findsOneWidget);
        expect(find.text('¥32,152'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('card_recon_wizard_next_step1')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('請求額と一致します。保存するとアラートが解消されます。'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('card_recon_wizard_next_step2')),
        );
        await tester.pumpAndSettle();

        expect(find.text('保存して照合完了'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('card_recon_wizard_save_button')),
        );
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.billingAccountId, 'aupay_card');
        expect(result!.amount, 8011);
        expect(result!.adjustConfiguredTotal, isTrue);
      },
    );

    testWidgets(
      'CardManualStatementEntryDialog blocks mismatch until override and saves balanced rows (#3326)',
      (tester) async {
        List<AssetLiabilityCardStatementLine>? savedLines;
        final group = _sampleMismatchGroup();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    savedLines =
                        await showDialog<List<AssetLiabilityCardStatementLine>>(
                      context: context,
                      builder: (_) => CardManualStatementEntryDialog(
                        group: group,
                        initialDate: DateTime(2026, 6, 10),
                      ),
                    );
                  },
                  child: const Text('open_manual'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_manual'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('card_manual_entry_amount_0')),
          '5000',
        );
        await tester.enterText(
          find.byKey(const Key('card_manual_entry_desc_0')),
          '食料品',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('card_manual_entry_mismatch_warning')),
          findsOneWidget,
        );
        FilledButton saveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('card_manual_entry_save_button')),
        );
        expect(saveBtn.onPressed, isNull);

        await tester.tap(
          find.byKey(const Key('card_manual_entry_allow_mismatch_checkbox')),
        );
        await tester.pump();
        saveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('card_manual_entry_save_button')),
        );
        expect(saveBtn.onPressed, isNotNull);

        await tester.tap(
          find.byKey(const Key('card_manual_entry_allow_mismatch_checkbox')),
        );
        await tester.enterText(
          find.byKey(const Key('card_manual_entry_amount_0')),
          '8011',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('card_manual_entry_mismatch_warning')),
          findsNothing,
        );
        saveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('card_manual_entry_save_button')),
        );
        expect(saveBtn.onPressed, isNotNull);

        await tester.tap(
          find.byKey(const Key('card_manual_entry_save_button')),
        );
        await tester.pumpAndSettle();

        expect(savedLines, hasLength(1));
        expect(savedLines!.first.amount, 8011);
        expect(savedLines!.first.description, '食料品');
      },
    );

    testWidgets(
      'CardProvisionalDetailDialog pre-fills difference and returns draft (#3349)',
      (tester) async {
        CardProvisionalDetailDraft? draft;
        final group = _sampleMismatchGroup();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    draft = await showDialog<CardProvisionalDetailDraft>(
                      context: context,
                      builder: (_) => CardProvisionalDetailDialog(group: group),
                    );
                  },
                  child: const Text('open_prov'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_prov'));
        await tester.pumpAndSettle();

        expect(find.text('8011'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('card_provisional_memo_field')),
          'auPAY仮内訳',
        );
        await tester.tap(find.byKey(const Key('card_provisional_save_button')));
        await tester.pumpAndSettle();

        expect(draft, isNotNull);
        expect(draft!.amount, 8011);
        expect(draft!.memo, 'auPAY仮内訳');
      },
    );

    testWidgets(
      'AssetManagementPage banner clears after completing 3-step manual wizard',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemoryCardReconRepository(
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

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo,
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

        expect(
          find.byKey(
              const Key('asset_card_reconciliation_needs_review_banner')),
          findsOneWidget,
        );

        final startBtn = find.byKey(
          const Key('asset_card_reconciliation_start_wizard_button'),
        );
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('card_recon_wizard_next_step1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const Key('card_recon_wizard_next_step2')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester
            .tap(find.byKey(const Key('card_recon_wizard_save_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(
              const Key('asset_card_reconciliation_needs_review_banner')),
          findsNothing,
        );

        await _unmountPage(tester);
      },
    );

    testWidgets(
      'AssetManagementPage adds provisional detail and promotes it to clear alert (#3349)',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        final now = DateTime(2026, 6, 10);
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        final repo = _InMemoryCardReconRepository(
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

        await tester.binding.setSurfaceSize(const Size(1200, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugNow: now,
              assetLiabilityRepository: repo,
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

        final addProvBtn = find.byKey(
          const Key('asset_card_provisional_add_aupay_card'),
        );
        await tester.ensureVisible(addProvBtn);
        await tester.tap(addProvBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('card_provisional_save_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('仮内訳'), findsOneWidget);
        expect(find.text('正式内訳へ昇格'), findsOneWidget);
        expect(
          find.byKey(
              const Key('asset_card_reconciliation_needs_review_banner')),
          findsOneWidget,
        );

        final promoteBtn = find.text('正式内訳へ昇格');
        await tester.ensureVisible(promoteBtn);
        await tester.tap(promoteBtn);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('正式内訳へ昇格'), findsNothing);
        expect(
          find.byKey(
              const Key('asset_card_reconciliation_needs_review_banner')),
          findsNothing,
        );

        await _unmountPage(tester);
      },
    );
  });
}

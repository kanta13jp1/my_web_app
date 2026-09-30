import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_analysis_history_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MonthlyRepository extends SharedPreferencesAssetLiabilityRepository {
  AssetLiabilityMonthlyState state = AssetLiabilityMonthlyState(
    incomePlans: <AssetLiabilityIncomePlan>[
      AssetLiabilityIncomePlan(
        id: 'synthetic-income',
        date: DateTime(2026, 9, 5),
        name: 'Synthetic salary',
        amount: 40000,
        destinationAccountId: 'bank',
        destinationAccountName: 'bank',
        received: false,
      ),
    ],
  );

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return state;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    this.state = state;
  }
}

class _DelayedMonthlyRepository extends _MonthlyRepository {
  final restored = Completer<AssetLiabilityMonthlyState>();
  int loads = 0;
  int failures = 0;
  bool failRestoration = false;
  bool ownershipCurrent = true;

  @override
  bool isMonthVerifiedForAi(DateTime month) => ownershipCurrent;

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async {
    return <String, int>{'synthetic debt': 5};
  }

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    loads++;
    final state = await restored.future;
    if (failRestoration) {
      failures++;
      throw StateError('synthetic restore failed');
    }
    return state;
  }
}

class _CountingHistory extends _EmptyHistory {
  int reads = 0;
  int saves = 0;

  @override
  Future<AssetManagementAiAnalysisHistoryEntry?> loadLatestForBaseDate({
    required String reportBaseDate,
  }) async {
    reads++;
    return null;
  }

  @override
  Future<void> saveResult({
    required AssetManagementAiSummaryResult result,
    required AssetManagementInsightReport report,
    required String requestFingerprint,
  }) async {
    saves++;
  }
}

class _EmptyHistory extends AssetManagementAiAnalysisHistoryService {
  @override
  Future<List<AssetManagementAiAnalysisHistoryEntry>> loadRecent({
    int limit = 5,
  }) async {
    return <AssetManagementAiAnalysisHistoryEntry>[];
  }

  @override
  Future<AssetManagementAiAnalysisHistoryEntry?> loadLatestForBaseDate({
    required String reportBaseDate,
  }) async {
    return null;
  }

  @override
  Future<void> saveResult({
    required AssetManagementAiSummaryResult result,
    required AssetManagementInsightReport report,
    required String requestFingerprint,
  }) async {}
}

class _StaleHistory extends _EmptyHistory {
  AssetManagementAiAnalysisHistoryEntry? firstSaved;
  int reads = 0;

  @override
  Future<AssetManagementAiAnalysisHistoryEntry?> loadLatestForBaseDate({
    required String reportBaseDate,
  }) async {
    reads++;
    return firstSaved;
  }

  @override
  Future<void> saveResult({
    required AssetManagementAiSummaryResult result,
    required AssetManagementInsightReport report,
    required String requestFingerprint,
  }) async {
    // Model a history store whose newest visible record is still the old one.
    firstSaved ??= AssetManagementAiAnalysisHistoryEntry(
      id: 'synthetic-history',
      requestFingerprint: requestFingerprint,
      summaryText: result.text,
      status: result.status.name,
      source: result.source,
      generatedAt: result.generatedAt,
      createdAt: result.generatedAt,
      reportBaseDate: report.workbook.baseDate,
      providerChoiceReason: null,
      providerRoute: const <String, dynamic>{},
      inputPayload: result.payload,
    );
  }
}

class _ControlledAi extends AssetManagementAiSummaryService {
  _ControlledAi() : super(aiEnabled: true);

  final requests = <AssetManagementInsightReport>[];
  final responses = <Completer<AssetManagementAiSummaryResult>>[];

  @override
  Future<AssetManagementAiSummaryResult> generateSummary({
    required AssetManagementInsightReport report,
    List<AssetManagementAiAnalysisHistoryEntry> previousAnalyses =
        const <AssetManagementAiAnalysisHistoryEntry>[],
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) {
    requests.add(report);
    final response = Completer<AssetManagementAiSummaryResult>();
    responses.add(response);
    return response.future;
  }

  void complete(
    int index,
    String text, {
    List<AssetManagementDeveloperRequest> proposals = const [],
  }) {
    responses[index].complete(
      AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.aiGenerated,
        text: text,
        source: 'synthetic provider',
        errorMessage: null,
        generatedAt: DateTime(2026, 9, 6, 12),
        payload: buildPayload(requests[index]),
        aiDeveloperRequests: proposals,
      ),
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: 'Expected UI transition within ten seconds');
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

  testWidgets('card discrepancy edit resolves mismatch but keeps import alert',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const providerId = AssetLiabilityPlanningService.kddiProviderAccountId;
    final repository = _MonthlyRepository()
      ..state = const AssetLiabilityMonthlyState(
        paymentOverrides: <String, double>{
          providerId: 5764,
          'paypay_card': 20000,
        },
        cardBillingAccountIds: <String, String>{providerId: 'paypay_card'},
      );
    final ai = _ControlledAi();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: _EmptyHistory(),
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{
              'cash': 50000,
              'KDDI': -5764,
              'PayPay': -20000,
            },
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.requests.isNotEmpty);
    final before = ai.requests.first.workbook.cardStatementReconciliation.groups
        .singleWhere((group) => group.billingAccountId == 'paypay_card');
    expect(before.hasConfiguredMismatchFix, isTrue);
    expect(
      before.fixActions
          .singleWhere(
            (action) =>
                action.kind ==
                AssetLiabilityCardStatementFixActionKind
                    .adjustConfiguredBreakdown,
          )
          .amount,
      -14236,
    );
    ai.complete(0, 'Synthetic card discrepancy');
    final importButton = find.byKey(
      const Key('asset_card_recon_fix_importStatement_paypay_card'),
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();
    expect(find.textContaining('を選択しました。カード明細を貼り付けて'), findsOneWidget);
    final editButton = find.byKey(
      const Key('asset_card_recon_fix_adjustConfiguredBreakdown_paypay_card'),
    );
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 400));
    final amountInput = find.byKey(
      const ValueKey('monthly-payment:$providerId'),
    );
    expect(amountInput, findsOneWidget);
    expect(tester.widget<TextField>(amountInput).controller?.text, '5764');
    await tester.ensureVisible(amountInput);
    await tester.enterText(amountInput, '20000');
    await _pumpUntil(tester, () => ai.requests.length == 2);
    final after = ai.requests.last.workbook.cardStatementReconciliation.groups
        .singleWhere((group) => group.billingAccountId == 'paypay_card');
    expect(after.hasConfiguredMismatchFix, isFalse);
    expect(
      after.alerts,
      contains(AssetLiabilityPlanningService.cardStatementMissingImportAlert),
    );
    expect(repository.state.paymentOverrides[providerId], 20000);
    ai.complete(1, 'Synthetic discrepancy resolved');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: _EmptyHistory(),
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{
              'cash': 50000,
              'KDDI': -5764,
              'PayPay': -20000,
            },
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.requests.length == 3);
    final restored = ai
        .requests.last.workbook.cardStatementReconciliation.groups
        .singleWhere((group) => group.billingAccountId == 'paypay_card');
    expect(restored.configuredDetailTotal, 20000);
    expect(restored.hasConfiguredMismatchFix, isFalse);
    expect(
      restored.alerts,
      contains(AssetLiabilityPlanningService.cardStatementMissingImportAlert),
    );
    ai.complete(2, 'Restored synthetic discrepancy remains resolved');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final mode in <int>[0, 1, 2]) {
    final failRestoration = mode == 1;
    final ownershipChanges = mode == 2;
    testWidgets(
        failRestoration
            ? 'failed monthly restoration never generates or saves AI input'
            : ownershipChanges
                ? 'changed user never displays or saves an in-flight AI response'
                : 'slow monthly restoration blocks automatic and manual AI input',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'full',
      });
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      AssetRecurringTombstoneSyncService.resetSharedForTest();
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _DelayedMonthlyRepository();
      final ai = _ControlledAi();
      final history = _CountingHistory();
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repository,
            aiSummaryService: ai,
            aiAnalysisHistoryService: history,
            debugNow: DateTime(2026, 9, 6, 12),
            debugInitialAssetData: const <String, Map<String, double>>{
              '2026-09-06': <String, double>{
                'bank': 30000,
                'synthetic debt': -10000,
              },
            },
          ),
        ),
      );
      await _pumpUntil(tester, () => repository.loads > 0);
      // Longer than the old 2.5-second debounce, with an unresolved loader.
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ai.requests, isEmpty);
      expect(history.reads, 0);
      expect(history.saves, 0);
      final updateButton = find.ancestor(
        of: find.text('AI要約を更新'),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(updateButton).onPressed, isNull);
      if (failRestoration) {
        // Raise the error in the requesting widget's error zone. A failed
        // Completer created in the test zone cannot cross error-zone boundaries.
        repository.failRestoration = true;
        repository.restored.complete(const AssetLiabilityMonthlyState());
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(repository.failures, 1);
        expect(ai.requests, isEmpty);
        expect(history.reads, 0);
        expect(history.saves, 0);
        expect(tester.widget<OutlinedButton>(updateButton).onPressed, isNull);
      } else {
        repository.restored.complete(
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'synthetic debt': 1000},
            paidAccountNames: <String>{'synthetic debt'},
            actualPaymentAmounts: <String, double>{'synthetic debt': 1000},
          ),
        );
        await _pumpUntil(tester, () => ai.requests.isNotEmpty);
        expect(ai.requests, hasLength(1));
        final debt = ai.requests.single.workbook.debtMasterRows
            .singleWhere((row) => row.name == 'synthetic debt');
        expect(debt.paid, isTrue);
        expect(ai.requests.single.workbook.monthlyActualPaymentTotal, 1000);
        if (ownershipChanges) repository.ownershipCurrent = false;
        ai.complete(0, 'Restored synthetic payment is paid');
        if (ownershipChanges) {
          for (var frame = 0; frame < 60; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(history.saves, 0);
          expect(
            find.textContaining('Restored synthetic payment is paid'),
            findsNothing,
          );
        } else {
          await _pumpUntil(tester, () => history.saves == 1);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('received income removes old AI prose before regeneration',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final repository = _MonthlyRepository();
    final ai = _ControlledAi();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: _EmptyHistory(),
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{'bank': 30000},
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.responses.isNotEmpty);
    expect(ai.requests.first.workbook.incomePlans.single.received, isFalse);
    const oldProposalTitle = 'Synthetic obsolete receipt proposal';
    ai.complete(
      0,
      'Old synthetic income is unreceived',
      proposals: const <AssetManagementDeveloperRequest>[
        AssetManagementDeveloperRequest(
          title: oldProposalTitle,
          description: 'Synthetic proposal for the previous receipt state.',
          severity: AssetManagementInsightSeverity.warning,
        ),
      ],
    );
    final oldText = find.text(
      'Old synthetic income is unreceived',
      findRichText: true,
    );
    await _pumpUntil(tester, () => oldText.evaluate().isNotEmpty);
    final oldProposal = find.text(oldProposalTitle);
    await _pumpUntil(tester, () => oldProposal.evaluate().isNotEmpty);
    expect(oldProposal, findsOneWidget);
    final copy = find.text('分析結果をコピー');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, 'Old synthetic income is unreceived');
    final received = find.byKey(
      const Key('asset_income_received_synthetic-income'),
    );
    await tester.ensureVisible(received);
    await tester.tap(received);
    await tester.pump();
    expect(oldText, findsNothing);
    expect(oldProposal, findsNothing);
    clipboardText = null;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, isNotNull);
    expect(clipboardText, isNot(isEmpty));
    expect(
      clipboardText,
      isNot(contains('Old synthetic income is unreceived')),
    );
    await _pumpUntil(tester, () => ai.responses.length == 2);
    expect(ai.requests.last.workbook.incomePlans.single.received, isTrue);
    expect(repository.state.incomePlans.single.received, isTrue);
    ai.complete(1, 'Current synthetic income is received');
    final newText = find.text(
      'Current synthetic income is received',
      findRichText: true,
    );
    await _pumpUntil(tester, () => newText.evaluate().isNotEmpty);
    expect(oldText, findsNothing);
    expect(oldProposal, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('a late old response stays hidden after a receipt edit',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MonthlyRepository();
    final ai = _ControlledAi();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: _EmptyHistory(),
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{'bank': 30000},
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.responses.isNotEmpty);
    expect(ai.requests.first.workbook.incomePlans.single.received, isFalse);
    final received = find.byKey(
      const Key('asset_income_received_synthetic-income'),
    );
    await tester.ensureVisible(received);
    await tester.tap(received);
    await tester.pump();
    await _pumpUntil(
      tester,
      () => repository.state.incomePlans.single.received,
    );
    ai.complete(0, 'Late obsolete income is unreceived');
    final obsolete = find.text(
      'Late obsolete income is unreceived',
      findRichText: true,
    );
    // Check every frame while the new request is scheduled: old output must
    // never flash as current merely because its request finished last.
    for (var frame = 0; frame < 100 && ai.responses.length < 2; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(obsolete, findsNothing);
    }
    expect(ai.responses, hasLength(2));
    expect(ai.requests.last.workbook.incomePlans.single.received, isTrue);
    ai.complete(1, 'Fresh synthetic income is received');
    final fresh = find.text(
      'Fresh synthetic income is received',
      findRichText: true,
    );
    await _pumpUntil(tester, () => fresh.evaluate().isNotEmpty);
    expect(obsolete, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('failed regeneration keeps fallback and retry recovers',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final repository = _MonthlyRepository();
    final ai = _ControlledAi();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: _EmptyHistory(),
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{'bank': 30000},
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.responses.isNotEmpty);
    expect(ai.requests.first.workbook.incomePlans.single.received, isFalse);
    ai.complete(0, 'Old synthetic income is unreceived');
    final oldText = find.text(
      'Old synthetic income is unreceived',
      findRichText: true,
    );
    await _pumpUntil(tester, () => oldText.evaluate().isNotEmpty);
    final copy = find.text('分析結果をコピー');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, 'Old synthetic income is unreceived');
    final received = find.byKey(
      const Key('asset_income_received_synthetic-income'),
    );
    await tester.ensureVisible(received);
    await tester.tap(received);
    await tester.pump();
    expect(oldText, findsNothing);
    clipboardText = null;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, isNotNull);
    expect(clipboardText, isNot(isEmpty));
    expect(
      clipboardText,
      isNot(contains('Old synthetic income is unreceived')),
    );
    await _pumpUntil(tester, () => ai.responses.length == 2);
    expect(ai.requests.last.workbook.incomePlans.single.received, isTrue);
    expect(repository.state.incomePlans.single.received, isTrue);
    ai.responses[1].complete(
      AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.fallback,
        text: ai.buildDeterministicSummary(ai.requests[1]),
        source: 'deterministic fallback / ai-hub failed',
        errorMessage: 'Synthetic provider unavailable',
        generatedAt: DateTime(2026, 9, 6, 12),
        payload: ai.buildPayload(ai.requests[1]),
      ),
    );
    final failure = find.text('Synthetic provider unavailable');
    await _pumpUntil(tester, () => failure.evaluate().isNotEmpty);
    expect(oldText, findsNothing);
    clipboardText = null;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, ai.buildDeterministicSummary(ai.requests[1]).trim());
    final retry = find.text('AI要約を更新');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await _pumpUntil(tester, () => ai.responses.length == 3);
    expect(ai.requests.last.workbook.incomePlans.single.received, isTrue);
    ai.complete(2, 'Current synthetic income is received');
    final newText = find.text(
      'Current synthetic income is received',
      findRichText: true,
    );
    await _pumpUntil(tester, () => newText.evaluate().isNotEmpty);
    expect(oldText, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('page remount rejects an obsolete persisted summary',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final repository = _MonthlyRepository();
    final ai = _ControlledAi();
    final history = _StaleHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: ai,
          aiAnalysisHistoryService: history,
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{'bank': 30000},
          },
        ),
      ),
    );
    await _pumpUntil(tester, () => ai.responses.isNotEmpty);
    expect(ai.requests.first.workbook.incomePlans.single.received, isFalse);
    ai.complete(0, 'Old synthetic income is unreceived');
    final oldText = find.text(
      'Old synthetic income is unreceived',
      findRichText: true,
    );
    await _pumpUntil(tester, () => oldText.evaluate().isNotEmpty);
    final copy = find.text('分析結果をコピー');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, 'Old synthetic income is unreceived');
    final received = find.byKey(
      const Key('asset_income_received_synthetic-income'),
    );
    await tester.ensureVisible(received);
    await tester.tap(received);
    await tester.pump();
    expect(oldText, findsNothing);
    clipboardText = null;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(clipboardText, isNotNull);
    expect(clipboardText, isNot(isEmpty));
    expect(
      clipboardText,
      isNot(contains('Old synthetic income is unreceived')),
    );
    await _pumpUntil(tester, () => ai.responses.length == 2);
    expect(ai.requests.last.workbook.incomePlans.single.received, isTrue);
    expect(repository.state.incomePlans.single.received, isTrue);
    ai.complete(1, 'Current synthetic income is received');
    final newText = find.text(
      'Current synthetic income is received',
      findRichText: true,
    );
    await _pumpUntil(tester, () => newText.evaluate().isNotEmpty);
    expect(oldText, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(
      history.firstSaved?.summaryText,
      'Old synthetic income is unreceived',
    );
    final previousReads = history.reads;
    final reloadedAi = _ControlledAi();
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repository,
          aiSummaryService: reloadedAi,
          aiAnalysisHistoryService: history,
          debugNow: DateTime(2026, 9, 6, 12),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-09-06': <String, double>{'bank': 30000},
          },
        ),
      ),
    );
    for (var frame = 0; frame < 100 && reloadedAi.responses.isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(oldText, findsNothing);
    }
    expect(history.reads, greaterThan(previousReads));
    expect(reloadedAi.responses, hasLength(1));
    expect(
      reloadedAi.requests.single.workbook.incomePlans.single.received,
      isTrue,
    );
    expect(tester.widget<Checkbox>(received).value, isTrue);
    reloadedAi.complete(0, 'Reloaded current income is received');
    final reloadedText = find.text(
      'Reloaded current income is received',
      findRichText: true,
    );
    await _pumpUntil(tester, () => reloadedText.evaluate().isNotEmpty);
    expect(oldText, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}

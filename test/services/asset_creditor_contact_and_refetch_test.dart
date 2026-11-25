import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/contact_log.dart';
import 'package:my_web_app/services/asset_creditor_contact_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/card_statement_refetch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const insightService = AssetManagementInsightService();
  final aiSummaryService = AssetManagementAiSummaryService();

  group('AssetCreditorContactService & Store (#3292 / #3288)', () {
    test('generates tailored templates for all 3 consultation kinds', () {
      const row = AssetLiabilityDebtRow(
        id: 'mobit',
        name: 'モビット',
        kind: AssetLiabilityAccountKind.cardLoan,
        balance: -120000,
        paymentDay: 15,
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
        minimumPaymentEstimate: 8000,
        manualPaymentAmount: null,
        scheduledPaymentAmount: 10000,
        monthlyInterestEstimate: 1800,
        principalPaymentEstimate: 8200,
        balanceAfterPaymentEstimate: -111800,
        liabilityShare: 1.0,
        priorityLabel: '高',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: false,
        requiresAction: true,
      );
      final dueDate = DateTime(2026, 6, 15);

      for (final kind in CreditorContactTemplateKind.values) {
        final text = AssetCreditorContactService.buildTemplateText(
          row: row,
          dueDate: dueDate,
          kind: kind,
        );
        expect(text, contains('モビット'));
        expect(text, contains('2026/06/15'));
        expect(text, contains('18.0%'));
      }
      final dueChangeText = AssetCreditorContactService.buildTemplateText(
        row: row,
        dueDate: dueDate,
        kind: CreditorContactTemplateKind.changeDueDate,
      );
      expect(dueChangeText, contains('次回入金後'));
      final reduceText = AssetCreditorContactService.buildTemplateText(
        row: row,
        dueDate: dueDate,
        kind: CreditorContactTemplateKind.reduceMinimum,
      );
      expect(reduceText, contains('最低返済額'));
      final graceText = AssetCreditorContactService.buildTemplateText(
        row: row,
        dueDate: dueDate,
        kind: CreditorContactTemplateKind.installmentOrGrace,
      );
      expect(graceText, contains('支払猶予または分割'));
    });

    test('saveLog persists & propagates error (#3292)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = AssetContactLogStore();
      final log = CreditorContactLog(
        id: 'c_1',
        accountId: 'mobit',
        accountName: 'モビット',
        contactedAt: DateTime(2026, 6, 10, 14, 30),
        channel: CreditorContactChannel.phone,
        templateKind: CreditorContactTemplateKind.changeDueDate,
        representative: '佐藤様',
        agreedSummary: '6/28へ支払日変更を合意',
        nextFollowUpDate: DateTime(2026, 6, 26),
        note: '受付番号12345',
      );

      await expectLater(
        () => store.saveLog(
          log,
          remoteSubmitter: (_) async => throw StateError('network failed'),
        ),
        throwsStateError,
      );
      expect(await store.loadLogs(), isEmpty);

      final saved = await store.saveLog(
        log,
        remoteSubmitter: (_) async {},
      );
      expect(saved, hasLength(1));
      final loaded = await store.loadLogs();
      expect(loaded, hasLength(1));
      expect(loaded.single.agreedSummary, '6/28へ支払日変更を合意');
      expect(loaded.single.representative, '佐藤様');
    });

    test('wires contact tasks, reminders, and AI payload', () {
      final log = CreditorContactLog(
        id: 'log_mobit_1',
        accountId: 'mobit',
        accountName: 'モビット',
        contactedAt: DateTime(2026, 6, 10),
        channel: CreditorContactChannel.phone,
        templateKind: CreditorContactTemplateKind.changeDueDate,
        agreedSummary: '6/26に支払変更合意済み',
        nextFollowUpDate: DateTime(2026, 6, 13),
      );
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 50000,
          'モビット': -150000,
          'アコム（カードローン）': -120000,
        },
        baseDate: DateTime(2026, 6, 10),
        paymentDayOverrides: const <String, int>{
          'mobit': 12,
          'acom_card_loan': 8,
        },
        contactLogs: <CreditorContactLog>[log],
      );

      expect(workbook.creditorContactTasks.length, greaterThanOrEqualTo(2));
      final mobitTask = workbook.creditorContactTasks.singleWhere(
        (t) => t.accountId == 'mobit',
      );
      expect(mobitTask.isContacted, isTrue);
      expect(mobitTask.nextFollowUpDate, DateTime(2026, 6, 13));

      final acomTask = workbook.creditorContactTasks.singleWhere(
        (t) => t.accountId == 'acom_card_loan',
      );
      expect(acomTask.isContacted, isFalse);
      expect(acomTask.isOverdue, isTrue);

      final report = insightService.buildReport(
        workbook: workbook,
        contactLogs: <CreditorContactLog>[log],
      );
      expect(report.recommendCreditorContactTemplate, isTrue);
      expect(report.creditorContactReminders, hasLength(1));
      expect(report.creditorContactReminders.single.isUrgent, isTrue);
      expect(
        report.creditorContactReminders.single.agreedSummary,
        '6/26に支払変更合意済み',
      );

      final payload = aiSummaryService.buildAiDetailedPayload(report);
      final workbookJson = payload['workbook'] as Map<String, dynamic>;
      expect(workbookJson['contact_log_ids'], contains('log_mobit_1'));
      expect(workbookJson['creditor_contact_tasks'], isA<List<dynamic>>());
    });
  });

  group('CardStatementRefetchService (#3299)', () {
    const group = AssetLiabilityCardStatementReconciliationGroup(
      billingAccountId: 'aupay_card',
      billingAccountName: 'auPayカード',
      billedAmount: 40163,
      configuredDetailTotal: 32152,
      statementLineTotal: 0,
      configuredItems: <AssetLiabilityCardBillingReviewItem>[],
      statementLines: <AssetLiabilityCardStatementLine>[],
      alerts: <String>[],
    );

    test('returns failure when no provider or CSV exists', () async {
      final result = await CardStatementRefetchService.refetchForGroup(
        group: group,
        now: DateTime(2026, 6, 10, 12),
      );
      expect(result.status.lastResult, CardStatementImportResultStatus.failed);
      expect(result.status.failureReason, contains('自動連携プロバイダが未接続'));
      expect(result.importedLines, isEmpty);
    });

    test('parses CSV & turns handler error into failed', () async {
      final ok = await CardStatementRefetchService.refetchForGroup(
        group: group,
        now: DateTime(2026, 6, 10, 12),
        rawImportText: '食料品,8011,2026-06-05',
      );
      expect(ok.status.lastResult, CardStatementImportResultStatus.success);
      expect(ok.importedLines, hasLength(1));
      expect(ok.importedLines.single.amount, 8011);

      final err = await CardStatementRefetchService.refetchForGroup(
        group: group,
        now: DateTime(2026, 6, 10, 12),
        customHandler: (_, __) async => throw StateError('upstream timeout'),
      );
      expect(err.status.lastResult, CardStatementImportResultStatus.failed);
      expect(err.status.failureReason, contains('upstream timeout'));
    });

    test('includes statement_import_status inside AI detailed payload', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 50000},
        baseDate: DateTime(2026, 6, 10),
        statementImportStatuses: <String, CardStatementImportStatus>{
          'aupay_card': CardStatementImportStatus(
            billingAccountId: 'aupay_card',
            billingAccountName: 'auPayカード',
            lastAttemptAt: DateTime(2026, 6, 10, 12),
            lastResult: CardStatementImportResultStatus.failed,
            provider: 'external_provider',
            failureReason: 'upstream timeout',
          ),
        },
      );
      final report = insightService.buildReport(workbook: workbook);
      final payload = aiSummaryService.buildAiDetailedPayload(report);
      final workbookJson = payload['workbook'] as Map<String, dynamic>;
      final recon =
          workbookJson['card_statement_reconciliation'] as Map<String, dynamic>;
      final importStatus =
          recon['statement_import_status'] as Map<String, dynamic>;
      expect(importStatus.containsKey('aupay_card'), isTrue);
      final entry = importStatus['aupay_card'] as Map<String, dynamic>;
      expect(entry['last_result'], 'failed');
      expect(entry['failure_reason'], 'upstream timeout');
    });
  });
}

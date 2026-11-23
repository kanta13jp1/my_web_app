import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_auto_transfer_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_tax_deduction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetAutoTransferService (#3443)', () {
    const planner = AssetLiabilityPlanningService();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('builds shortage candidate while protecting donor reserve', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 250000,
          'auじぶん銀行': 10000,
          'auPayカード': -50000,
        },
        monthlyPaymentOverrides: const <String, double>{'aupay_card': 50000},
        paymentSourceAccountIds: const <String, String>{
          'aupay_card': 'jibun_bank',
        },
        baseDate: DateTime(2026, 6, 10),
      );

      final candidates = AssetAutoTransferService.buildCandidates(
        workbook: workbook,
        minimumSafetyBalance: 50000,
        settings: const AutoTransferSettings(
          enabled: true,
          executionMode: AutoTransferExecutionMode.autoCreateTask,
          extraSafetyBuffer: 5000,
        ),
      );

      expect(candidates, isNotEmpty);
      final candidate = candidates.firstWhere(
        (c) => c.suggestion.toAccountId == 'jibun_bank',
      );
      expect(candidate.suggestion.fromAccountId, 'smbc_otsuka_branch');
      expect(candidate.donorRemainingProjectedBalance,
          greaterThanOrEqualTo(50000));
      expect(
          candidate.projectedBalanceAfterTransfer, greaterThanOrEqualTo(50000));
      expect(candidate.alreadyTracked, isFalse);

      final bundle = AssetAutoTransferService.buildTransferTaskAndAudit(
        candidate: candidate,
        mode: AutoTransferExecutionMode.autoCreateTask,
        now: DateTime(2026, 6, 10, 12, 0),
      );
      expect(bundle.task.dedupeKey, candidate.suggestion.dedupeKey);
      expect(bundle.audit.status, 'auto_created');

      final resolvedWorkbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 250000,
          'auじぶん銀行': 10000,
          'auPayカード': -50000,
        },
        monthlyPaymentOverrides: const <String, double>{'aupay_card': 50000},
        paymentSourceAccountIds: const <String, String>{
          'aupay_card': 'jibun_bank',
        },
        transferTasks: <AssetLiabilityTransferTask>[bundle.task],
        baseDate: DateTime(2026, 6, 10),
      );
      final afterCandidates = AssetAutoTransferService.buildCandidates(
        workbook: resolvedWorkbook,
        minimumSafetyBalance: 50000,
        settings: const AutoTransferSettings(
          enabled: true,
          executionMode: AutoTransferExecutionMode.autoCreateTask,
          extraSafetyBuffer: 5000,
        ),
      );
      expect(afterCandidates, isEmpty);
    });

    test('skips donor when donor projected balance is below safety floor', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 45000,
          'auじぶん銀行': 10000,
          'auPayカード': -50000,
        },
        monthlyPaymentOverrides: const <String, double>{'aupay_card': 50000},
        paymentSourceAccountIds: const <String, String>{
          'aupay_card': 'jibun_bank',
        },
        baseDate: DateTime(2026, 6, 10),
      );

      final candidates = AssetAutoTransferService.buildCandidates(
        workbook: workbook,
        minimumSafetyBalance: 50000,
        settings: const AutoTransferSettings(enabled: true),
      );
      expect(candidates, isEmpty);
    });

    test('persists AutoTransferSettings and audit logs via SharedPreferences',
        () async {
      const settings = AutoTransferSettings(
        enabled: true,
        executionMode: AutoTransferExecutionMode.autoCreateTask,
        notifyOnExecution: false,
        extraSafetyBuffer: 10000,
      );
      await AssetAutoTransferStore.saveSettings(settings);
      final loadedSettings = await AssetAutoTransferStore.loadSettings();
      expect(loadedSettings.enabled, isTrue);
      expect(
        loadedSettings.executionMode,
        AutoTransferExecutionMode.autoCreateTask,
      );
      expect(loadedSettings.notifyOnExecution, isFalse);
      expect(loadedSettings.extraSafetyBuffer, 10000);

      final entry = AutoTransferAuditEntry(
        id: 'audit_1',
        executedAt: DateTime(2026, 6, 10, 14, 30),
        fromAccountId: 'smbc_otsuka_branch',
        fromAccountName: '三井住友銀行大塚支店',
        toAccountId: 'jibun_bank',
        toAccountName: 'auじぶん銀行',
        amount: 95000,
        projectedBalanceBefore: -40000,
        donorRemainingBalanceAfter: 155000,
        executionMode: AutoTransferExecutionMode.autoCreateTask,
        status: 'auto_created',
        dedupeKey: 'smbc_otsuka_branch__jibun_bank__95000__any',
        reason: '自動補填テスト',
      );
      await AssetAutoTransferStore.appendAuditLog(entry);
      final logs = await AssetAutoTransferStore.loadAuditLogs();
      expect(logs, hasLength(1));
      expect(logs.first.id, 'audit_1');
      expect(logs.first.amount, 95000);
    });
  });

  group('AssetFurusatoTaxCalculator (#2490)', () {
    test('matches official NTA/MIC benchmark for 5M JPY single earner', () {
      final single5M = AssetFurusatoTaxCalculator.estimate(
        const FurusatoTaxInput(annualSalaryIncome: 5000000),
      );
      expect(single5M.salaryDeduction, 1440000);
      expect(single5M.salaryIncome, 3560000);
      expect(single5M.socialInsuranceUsed, 750000);
      expect(single5M.socialInsuranceEstimated, isTrue);
      expect(single5M.estimatedLimitYen, 61000);
      expect(single5M.selfBurdenYen, 2000);
    });

    test('reduces limit for spouse deduction & dependents and handles 0 income',
        () {
      final single5M = AssetFurusatoTaxCalculator.estimate(
        const FurusatoTaxInput(annualSalaryIncome: 5000000),
      );
      final spouse5M = AssetFurusatoTaxCalculator.estimate(
        const FurusatoTaxInput(
          annualSalaryIncome: 5000000,
          maritalStatus: FurusatoMaritalStatus.marriedWithSpouseDeduction,
          specificDependentsCount: 1,
        ),
      );
      expect(spouse5M.estimatedLimitYen, lessThan(single5M.estimatedLimitYen));

      final zero = AssetFurusatoTaxCalculator.estimate(
        const FurusatoTaxInput(annualSalaryIncome: 0),
      );
      expect(zero.estimatedLimitYen, 0);
      expect(zero.selfBurdenYen, 0);

      final customSoc = AssetFurusatoTaxCalculator.estimate(
        const FurusatoTaxInput(
          annualSalaryIncome: 5000000,
          socialInsuranceOverride: 800000,
        ),
      );
      expect(customSoc.socialInsuranceEstimated, isFalse);
      expect(customSoc.socialInsuranceUsed, 800000);
    });
  });

  group('AssetMedicalExpenseService & Store (#2491)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('computes thresholds (100k, low-income 5%, 2M cap) and category sums',
        () {
      final approaching = AssetMedicalExpenseService.summarizeYear(
        taxYear: 2026,
        entries: <MedicalExpenseEntry>[
          MedicalExpenseEntry(
            id: 'm1',
            date: DateTime(2026, 3, 15),
            category: MedicalExpenseCategory.hospital,
            amount: 85000,
          ),
        ],
      );
      expect(approaching.isApproachingThreshold, isTrue);
      expect(approaching.isDeductionEligible, isFalse);
      expect(approaching.amountToThreshold, 15000);

      final eligible = AssetMedicalExpenseService.summarizeYear(
        taxYear: 2026,
        entries: <MedicalExpenseEntry>[
          MedicalExpenseEntry(
            id: 'm1',
            date: DateTime(2026, 3, 15),
            category: MedicalExpenseCategory.hospital,
            amount: 120000,
            reimbursementAmount: 20000,
          ),
          MedicalExpenseEntry(
            id: 'm2',
            date: DateTime(2026, 4, 15),
            category: MedicalExpenseCategory.pharmacy,
            amount: 25000,
          ),
          MedicalExpenseEntry(
            id: 'm3',
            date: DateTime(2026, 5, 15),
            category: MedicalExpenseCategory.transport,
            amount: 5000,
          ),
        ],
      );
      expect(eligible.grossTotal, 150000);
      expect(eligible.reimbursementTotal, 20000);
      expect(eligible.netTotal, 130000);
      expect(eligible.deductionThreshold, 100000);
      expect(eligible.isDeductionEligible, isTrue);
      expect(eligible.estimatedDeduction, 30000);
      expect(eligible.categoryTotals[MedicalExpenseCategory.hospital], 100000);
      expect(eligible.categoryTotals[MedicalExpenseCategory.pharmacy], 25000);
      expect(eligible.categoryTotals[MedicalExpenseCategory.transport], 5000);

      final lowIncome = AssetMedicalExpenseService.summarizeYear(
        taxYear: 2026,
        annualTotalIncome: 1600000,
        entries: <MedicalExpenseEntry>[
          MedicalExpenseEntry(
            id: 'm4',
            date: DateTime(2026, 6, 1),
            category: MedicalExpenseCategory.hospital,
            amount: 95000,
          ),
        ],
      );
      expect(lowIncome.deductionThreshold, 80000);
      expect(lowIncome.isDeductionEligible, isTrue);
      expect(lowIncome.estimatedDeduction, 15000);

      final capped = AssetMedicalExpenseService.summarizeYear(
        taxYear: 2026,
        entries: <MedicalExpenseEntry>[
          MedicalExpenseEntry(
            id: 'm5',
            date: DateTime(2026, 6, 1),
            category: MedicalExpenseCategory.hospital,
            amount: 2500000,
          ),
        ],
      );
      expect(capped.isAtCap, isTrue);
      expect(capped.estimatedDeduction, 2000000);
    });

    test('persists feature flag OFF by default and stores medical entries',
        () async {
      expect(await AssetTaxToolsFeatureFlagStore.load(), isFalse);
      await AssetTaxToolsFeatureFlagStore.save(true);
      expect(await AssetTaxToolsFeatureFlagStore.load(), isTrue);

      await AssetMedicalExpenseStore.save(<MedicalExpenseEntry>[
        MedicalExpenseEntry(
          id: 'med_test_1',
          date: DateTime(2026, 6, 15),
          category: MedicalExpenseCategory.pharmacy,
          amount: 4200,
          memo: '処方箋',
        ),
      ]);
      final loaded = await AssetMedicalExpenseStore.load();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'med_test_1');
      expect(loaded.first.category, MedicalExpenseCategory.pharmacy);
    });
  });
}

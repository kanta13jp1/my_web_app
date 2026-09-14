import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_salary_reconciliation_service.dart';

void main() {
  group('AssetSalaryReconciliationService.reconcile', () {
    test(
      'reconciles unreceived phantom salary plan (450,000) with confirmed payslip (421,277)',
      () {
        final plans = [
          AssetLiabilityIncomePlan(
            id: 'recurring_salary_2026-08',
            date: DateTime(2026, 8, 25),
            name: '給料',
            amount: 450000,
            destinationAccountId: 'smbc',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
          AssetLiabilityIncomePlan(
            id: 'side_job',
            date: DateTime(2026, 8, 15),
            name: '副業',
            amount: 50000,
            destinationAccountId: 'smbc',
            destinationAccountName: '三井住友銀行大塚支店',
            received: true,
          ),
        ];

        final payslipRows = [
          {
            'id': 'ps-1',
            'pay_date': '2026-08-25',
            'company_name': 'マイティリンク',
            'net_amount': 421277,
          },
        ];

        final reconciled = AssetSalaryReconciliationService.reconcile(
          monthlyIncomePlans: plans,
          payslipRows: payslipRows,
          payslipSalaryIncomes: const [],
          salaryDay: 25,
        );

        expect(reconciled, hasLength(2));

        final salaryPlan =
            reconciled.firstWhere((p) => p.date == DateTime(2026, 8, 25));
        expect(salaryPlan.amount, 421277);
        expect(salaryPlan.received, isTrue);
        expect(salaryPlan.name, 'マイティリンク給与');
        expect(salaryPlan.destinationAccountId, 'smbc');

        final sideJobPlan =
            reconciled.firstWhere((p) => p.date == DateTime(2026, 8, 15));
        expect(sideJobPlan.amount, 50000);
        expect(sideJobPlan.received, isTrue);
      },
    );

    test(
      'deduplicates duplicate unreceived salary plans on the same day when payslip confirms receipt',
      () {
        final plans = <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'plan-1',
            date: DateTime(2026, 8, 25),
            name: '給料',
            amount: 450000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
          AssetLiabilityIncomePlan(
            id: 'plan-2',
            date: DateTime(2026, 8, 25),
            name: '給料予定',
            amount: 450000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
        ];

        final payslipRows = [
          {
            'id': 'ps-1',
            'pay_date': '2026-08-25',
            'company_name': 'マイティリンク',
            'net_amount': 421277,
          },
        ];

        final reconciled = AssetSalaryReconciliationService.reconcile(
          monthlyIncomePlans: plans,
          payslipRows: payslipRows,
          payslipSalaryIncomes: const [],
          salaryDay: 25,
        );

        // Only 1 reconciled salary plan should remain, duplicate discarded
        expect(reconciled, hasLength(1));
        expect(reconciled.single.amount, 421277);
        expect(reconciled.single.received, isTrue);
      },
    );

    test('adds payslip as received income if no salary plan exists', () {
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'bonus',
          date: DateTime(2026, 8, 10),
          name: '賞与',
          amount: 100000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: true,
        ),
      ];

      final payslipRows = [
        {
          'id': 'ps-1',
          'pay_date': '2026-08-25',
          'company_name': 'マイティリンク',
          'net_amount': 421277,
        },
      ];

      final reconciled = AssetSalaryReconciliationService.reconcile(
        monthlyIncomePlans: plans,
        payslipRows: payslipRows,
        payslipSalaryIncomes: const [],
        salaryDay: 25,
      );

      expect(reconciled, hasLength(2));
      final salaryPlan =
          reconciled.firstWhere((p) => p.date == DateTime(2026, 8, 25));
      expect(salaryPlan.amount, 421277);
      expect(salaryPlan.received, isTrue);
      expect(salaryPlan.name, 'マイティリンク給与');
    });

    test('returns unmodified list when payslips are empty', () {
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'plan-1',
          date: DateTime(2026, 8, 25),
          name: '給料',
          amount: 450000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: false,
        ),
      ];

      final reconciled = AssetSalaryReconciliationService.reconcile(
        monthlyIncomePlans: plans,
        payslipRows: const [],
        payslipSalaryIncomes: const [],
      );

      expect(reconciled, hasLength(1));
      expect(reconciled.single.amount, 450000);
      expect(reconciled.single.received, isFalse);
    });

    test(
        'reconciles using salary_incomes table format when payslipRows is empty',
        () {
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'plan-salary',
          date: DateTime(2026, 8, 25),
          name: '給与',
          amount: 450000,
          destinationAccountId: 'smbc',
          destinationAccountName: '三井住友銀行',
          received: false,
        ),
      ];

      final salaryIncomes = [
        {
          'id': 'si-1',
          'pay_date': '2026-08-25',
          'description': 'マイティリンク',
          'amount': 421277,
        },
      ];

      final reconciled = AssetSalaryReconciliationService.reconcile(
        monthlyIncomePlans: plans,
        payslipRows: const [],
        payslipSalaryIncomes: salaryIncomes,
        salaryDay: 25,
      );

      expect(reconciled, hasLength(1));
      expect(reconciled.single.amount, 421277);
      expect(reconciled.single.received, isTrue);
      expect(reconciled.single.name, 'マイティリンク給与');
      expect(reconciled.single.destinationAccountId, 'smbc');
    });

    test('reconciles multiple months of payslips matching respective cycles',
        () {
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'plan-jul',
          date: DateTime(2026, 7, 25),
          name: '給料',
          amount: 450000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: false,
        ),
        AssetLiabilityIncomePlan(
          id: 'plan-aug',
          date: DateTime(2026, 8, 25),
          name: '給料',
          amount: 450000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: false,
        ),
      ];

      final payslipRows = [
        {
          'id': 'ps-jul',
          'pay_date': '2026-07-25',
          'company_name': 'マイティリンク',
          'net_amount': 418500,
        },
        {
          'id': 'ps-aug',
          'pay_date': '2026-08-25',
          'company_name': 'マイティリンク',
          'net_amount': 421277,
        },
      ];

      final reconciled = AssetSalaryReconciliationService.reconcile(
        monthlyIncomePlans: plans,
        payslipRows: payslipRows,
        payslipSalaryIncomes: const [],
        salaryDay: 25,
      );

      expect(reconciled, hasLength(2));
      expect(reconciled[0].date, DateTime(2026, 7, 25));
      expect(reconciled[0].amount, 418500);
      expect(reconciled[0].received, isTrue);

      expect(reconciled[1].date, DateTime(2026, 8, 25));
      expect(reconciled[1].amount, 421277);
      expect(reconciled[1].received, isTrue);
    });
  });
}

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

    test(
        'does not inject past months confirmed payslips (e.g. May) when baseDate is in August/September cycle',
        () {
      // 計画には8月給与のみが存在する状態
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'plan-aug',
          date: DateTime(2026, 8, 25),
          name: '給料',
          amount: 450000,
          destinationAccountId: 'smbc',
          destinationAccountName: '三井住友銀行大塚支店',
          received: false,
        ),
      ];

      // 給与明細テーブルには5月の古い明細と8月の確定明細の両方が存在
      final payslipRows = [
        {
          'id': 'ps-may',
          'pay_date': '2026-05-25',
          'company_name': 'MightyLINK',
          'net_amount': 452815,
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
        baseDate: DateTime(2026, 8, 25), // 8月25日サイクル
      );

      // 5月の明細は注入されず、8月の1件のみとなること
      expect(reconciled, hasLength(1));
      expect(reconciled.single.date, DateTime(2026, 8, 25));
      expect(reconciled.single.amount, 421277);
      expect(reconciled.single.name, 'マイティリンク給与');
      expect(
        reconciled.any((p) => p.name.contains('MightyLINK')),
        isFalse,
      );
    });

    test(
        'purges legacy auto-injected past months salary plans (e.g. May) already in monthlyIncomePlans when baseDate is in August/September cycle',
        () {
      // 以前の不具合で保存されてしまっていた「5月給料」と「8月給料」の両方がplansに存在
      final plans = <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'payslip_2026-05-25',
          date: DateTime(2026, 5, 25),
          name: 'MightyLINK給与',
          amount: 452815,
          destinationAccountId: null,
          destinationAccountName: null,
          received: true,
        ),
        AssetLiabilityIncomePlan(
          id: 'plan-aug',
          date: DateTime(2026, 8, 25),
          name: '給料',
          amount: 450000,
          destinationAccountId: 'smbc',
          destinationAccountName: '三井住友銀行大塚支店',
          received: false,
        ),
      ];

      final payslipRows = [
        {
          'id': 'ps-may',
          'pay_date': '2026-05-25',
          'company_name': 'MightyLINK',
          'net_amount': 452815,
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
        baseDate: DateTime(2026, 9, 15), // 9月15日 (8/25〜9/24サイクル)
      );

      // 5月のプランは除外され、8月の確定給与1件のみとなること
      expect(reconciled, hasLength(1));
      expect(reconciled.single.date, DateTime(2026, 8, 25));
      expect(reconciled.single.amount, 421277);
      expect(reconciled.single.name, 'マイティリンク給与');
      expect(reconciled.single.received, isTrue);
      expect(
        reconciled.any((p) => p.name.contains('MightyLINK')),
        isFalse,
      );
    });

    test(
      'excludes future payslipRows and payslipSalaryIncomes before pay_date',
      () {
        final plans = <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'plan-oct',
            date: DateTime(2026, 10, 23),
            name: '給料',
            amount: 450000,
            destinationAccountId: 'smbc',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
          AssetLiabilityIncomePlan(
            id: 'plan-nov-unpaid',
            date: DateTime(2026, 11, 24),
            name: '給料予定',
            amount: 450000,
            destinationAccountId: 'smbc',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
        ];

        final payslipRows = [
          {
            'id': 'ps-oct',
            'pay_date': '2026-10-23',
            'company_name': 'マイティリンク',
            'net_amount': 421286,
          },
          {
            'id': 'ps-nov-same-cycle-future',
            'pay_date': '2026-11-24',
            'company_name': 'Future Same Cycle',
            'net_amount': 419000,
          },
          {
            'id': 'ps-nov-next-cycle-future',
            'pay_date': '2026-11-25',
            'company_name': 'Future Next Cycle',
            'net_amount': 420000,
          },
        ];

        final salaryIncomes = [
          {
            'id': 'si-nov-future',
            'pay_date': '2026-11-24',
            'description': 'Future Salary Income',
            'amount': 419000,
          },
        ];

        final beforePayday = AssetSalaryReconciliationService.reconcile(
          monthlyIncomePlans: plans,
          payslipRows: payslipRows,
          payslipSalaryIncomes: salaryIncomes,
          salaryDay: 25,
          baseDate: DateTime(2026, 11, 23, 23, 59),
        );

        expect(
          beforePayday.any((p) => p.name.contains('Future')),
          isFalse,
        );
        final novPlan = beforePayday.singleWhere(
          (p) => p.id == 'plan-nov-unpaid',
        );
        expect(novPlan.received, isFalse);
        expect(novPlan.amount, 450000);

        final onPayday = AssetSalaryReconciliationService.reconcile(
          monthlyIncomePlans: <AssetLiabilityIncomePlan>[
            AssetLiabilityIncomePlan(
              id: 'plan-nov-payday',
              date: DateTime(2026, 11, 25),
              name: '給料',
              amount: 450000,
              destinationAccountId: 'smbc',
              destinationAccountName: '三井住友銀行大塚支店',
              received: false,
            ),
          ],
          payslipRows: payslipRows,
          payslipSalaryIncomes: const [],
          salaryDay: 25,
          baseDate: DateTime(2026, 11, 25, 9, 0),
        );

        expect(onPayday, hasLength(1));
        expect(onPayday.single.amount, 420000);
        expect(onPayday.single.received, isTrue);
        expect(onPayday.single.name, 'Future Next Cycle給与');
      },
    );
  });
}

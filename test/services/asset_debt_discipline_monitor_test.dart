import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_discipline_monitor.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const monitor = AssetDebtDisciplineMonitor();
  final baseDate = DateTime(2026, 6, 1);

  String debtId(AssetLiabilityWorkbook workbook, String name) {
    return workbook.debtMasterRows.firstWhere((row) => row.name == name).id;
  }

  group('AssetDebtDisciplineMonitor — 誓約① 追加借入ゼロ', () {
    test('flags new borrowing on a loan that grew beyond interest', () {
      // モビット 前月10万→今月20万、返済5千。利息3千 → 新規利用 約10.2万。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -200000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'モビット': 5000},
      );
      final id = debtId(workbook, 'モビット');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 100000},
      );

      expect(report.newBorrowingViolations, hasLength(1));
      expect(report.revolvingCardViolations, isEmpty); // cardLoan は一括対象外
      expect(report.zeroNewBorrowingAchieved, isFalse);
      expect(report.newBorrowingViolations.single.amount > 90000, isTrue);
      expect(
        report.newBorrowingViolations.single.problem.contains('新規借入'),
        isTrue,
      );
      expect(report.hasPriorMonthData, isTrue);
    });

    test('does NOT flag interest-only growth as new borrowing', () {
      // 残高がほぼ利息分だけ増えた（新規利用なし）→ 違反にしない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -200500,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'モビット': 2000},
      );
      final id = debtId(workbook, 'モビット');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 200000},
      );

      expect(report.newBorrowingViolations, isEmpty);
    });

    test('does NOT flag a loan being paid down with no new usage', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -150000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'モビット': 50000},
      );
      final id = debtId(workbook, 'モビット');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 200000},
      );

      expect(report.isCompliant, isTrue);
      expect(report.zeroNewBorrowingAchieved, isTrue);
    });
  });

  group('AssetDebtDisciplineMonitor — 誓約② 新規利用分は25日に全額返済', () {
    test('does not flag an existing revolving balance paid at the minimum', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        baseDate: baseDate,
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
          ),
        },
      );

      final report = monitor.evaluate(workbook: workbook);

      expect(report.revolvingCardViolations, isEmpty);
      expect(report.newUsageRepaymentAchieved, isTrue);
      expect(report.totalCarriedOver, greaterThan(0));
    });

    test('accepts minimum payment plus all imported new usage on the 25th', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -130000,
        },
        baseDate: baseDate,
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
          ),
        },
        cardStatementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_1',
            billingAccountId: 'famipay_card',
            billingAccountName: 'ファミペイ',
            postedAt: null,
            description: '当月利用',
            amount: 30000,
          ),
        ],
      );

      final row = workbook.debtMasterRows.singleWhere(
        (row) => row.id == 'famipay_card',
      );
      final report = monitor.evaluate(workbook: workbook);

      expect(row.scheduledPaymentAmount, 35000);
      expect(row.paymentDay, 25);
      expect(report.revolvingCardViolations, isEmpty);
    });

    test('flags an actual payment that does not cover all new usage', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -130000,
        },
        baseDate: baseDate,
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 30000,
          ),
        },
        actualPaymentAmounts: const <String, double>{'famipay_card': 20000},
        paidAccountNames: const <String>{'famipay_card'},
      );

      final report = monitor.evaluate(workbook: workbook);
      final violation = report.revolvingCardViolations.single;

      expect(violation.amount, 15000);
      expect(violation.action, contains('不足15,000円'));
      expect(violation.action, contains('既存残高130,000円の一括返済は求めません'));
      expect(violation.problem, contains('返済日25日'));
    });

    test('flags even a one-yen repayment shortfall', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -130000,
        },
        baseDate: baseDate,
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 30000,
          ),
        },
        actualPaymentAmounts: const <String, double>{'famipay_card': 34999},
        paidAccountNames: const <String>{'famipay_card'},
      );

      final report = monitor.evaluate(workbook: workbook);

      expect(report.revolvingCardViolations.single.amount, 1);
    });
  });

  group('AssetDebtDisciplineMonitor — 統合', () {
    test('card usage covered on the 25th does not violate either pledge', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -300000,
        },
        baseDate: baseDate,
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 3000,
            newUsageAmount: 100000,
          ),
        },
      );
      final id = debtId(workbook, 'ファミペイ');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 200000},
      );

      expect(report.zeroNewBorrowingAchieved, isTrue);
      expect(report.newUsageRepaymentAchieved, isTrue);
      expect(report.isCompliant, isTrue);
      expect(report.newBorrowingViolations, isEmpty);
      expect(report.revolvingCardViolations, isEmpty);
      expect(report.totalCarriedOver, greaterThan(190000));
    });

    test('excludes full-payment fixed costs (rent/utility)', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          '家賃': -80000,
        },
        baseDate: baseDate,
      );
      final id = debtId(workbook, '家賃');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 0},
      );

      expect(report.isCompliant, isTrue);
    });

    test('exposes kind classification helpers', () {
      expect(
        AssetDebtDisciplineMonitor.isLumpSumCardKind(
          AssetLiabilityAccountKind.creditCard,
        ),
        isTrue,
      );
      expect(
        AssetDebtDisciplineMonitor.isLumpSumCardKind(
          AssetLiabilityAccountKind.cardLoan,
        ),
        isFalse,
      );
      expect(
        AssetDebtDisciplineMonitor.isBorrowingKind(
          AssetLiabilityAccountKind.utility,
        ),
        isFalse,
      );
    });
  });
}

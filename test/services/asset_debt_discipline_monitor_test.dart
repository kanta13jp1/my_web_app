import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_discipline_monitor.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';
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
        report.newBorrowingViolations.single.problem.contains('新規利用'),
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

  group('AssetDebtDisciplineMonitor — 誓約② カードは必ず一括', () {
    test('flags a credit card carrying a revolving balance', () {
      // ファミペイ 残高10万、返済は最低額のみ → 繰越=リボ → 違反。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        baseDate: baseDate,
      );

      final report = monitor.evaluate(workbook: workbook);

      expect(report.revolvingCardViolations, hasLength(1));
      expect(report.lumpSumAchieved, isFalse);
      expect(
        report.revolvingCardViolations.single.severity,
        AssetDebtTrendSeverity.critical,
      );
      expect(
        report.revolvingCardViolations.single.action.contains('一括'),
        isTrue,
      );
      // 前月データ未提供なので新規利用判定は走らない。
      expect(report.hasPriorMonthData, isFalse);
      expect(report.newBorrowingViolations, isEmpty);
    });

    test('does NOT flag a credit card paid in full this month', () {
      // 残高10万を全額返済 → 一括 → 違反なし。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'ファミペイ': 100000},
      );

      final report = monitor.evaluate(workbook: workbook);

      expect(report.revolvingCardViolations, isEmpty);
      expect(report.lumpSumAchieved, isTrue);
    });
  });

  group('AssetDebtDisciplineMonitor — 統合', () {
    test('the FamiPay example violates BOTH pledges', () {
      // 前月20万→今月30万(+10万)、返済3千 → 新規利用 約10万 かつ リボ繰越。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -300000,
        },
        baseDate: baseDate,
        monthlyPaymentOverrides: const <String, double>{'ファミペイ': 3000},
      );
      final id = debtId(workbook, 'ファミペイ');

      final report = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 200000},
      );

      expect(report.zeroNewBorrowingAchieved, isFalse);
      expect(report.lumpSumAchieved, isFalse);
      expect(report.isCompliant, isFalse);
      expect(report.newBorrowingViolations, hasLength(1));
      expect(report.revolvingCardViolations, hasLength(1));
      expect(report.totalNewBorrowing > 90000, isTrue);
      expect(report.totalCarriedOver > 200000, isTrue);
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

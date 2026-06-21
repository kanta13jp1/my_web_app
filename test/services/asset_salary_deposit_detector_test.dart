import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_deposit_detector.dart';

void main() {
  SalaryDepositFlowObservation flow(double amount, [int day = 26]) {
    return SalaryDepositFlowObservation(
      amount: amount,
      occurredAt: DateTime(2026, 6, day),
    );
  }

  group('AssetSalaryDepositDetector.detect', () {
    test('(A) flow within tolerance of expected salary → high', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(295000)],
        balances: MainAccountBalanceWindow.unknown,
        expectedSalaryAmount: 300000,
      );
      expect(result.confidence, SalaryDepositConfidence.high);
      expect(result.signal, SalaryDepositSignal.flowAmountMatch);
      expect(result.matchedAmount, 295000);
      expect(result.detected, isTrue);
    });

    test('flow outside tolerance does not match by amount', () {
      // 300000 ± 15% = [255000, 345000]。200000 は範囲外。
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(200000)],
        balances: MainAccountBalanceWindow.unknown,
        expectedSalaryAmount: 300000,
      );
      expect(result.detected, isFalse);
      expect(result.signal, SalaryDepositSignal.none);
    });

    test('(B) balance jump matching expected → high when no flow matched', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: const [],
        balances: const MainAccountBalanceWindow(
          previousCycleEndBalance: 50000,
          currentBalance: 50000 + 270000,
        ),
        expectedSalaryAmount: 300000,
      );
      expect(result.confidence, SalaryDepositConfidence.high);
      expect(result.signal, SalaryDepositSignal.balanceJump);
      expect(result.matchedAmount, 270000);
    });

    test('balance drop never counts as a deposit', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: const [],
        balances: const MainAccountBalanceWindow(
          previousCycleEndBalance: 400000,
          currentBalance: 100000,
        ),
        expectedSalaryAmount: 300000,
      );
      expect(result.detected, isFalse);
    });

    test('balance jump below expected band does not match', () {
      // 300000 * 0.85 = 255000 が下限。250000 増は未満。
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: const [],
        balances: const MainAccountBalanceWindow(
          previousCycleEndBalance: 0,
          currentBalance: 250000,
        ),
        expectedSalaryAmount: 300000,
      );
      expect(result.detected, isFalse);
    });

    test('expected known but no signal → none (heuristic suppressed)', () {
      // 登録給料額がある場合は floor 超えのフローでもヒューリスティックを使わない
      // (部分入金などでの早すぎるリセットを避ける)。
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(150000)],
        balances: MainAccountBalanceWindow.unknown,
        expectedSalaryAmount: 300000,
      );
      expect(result.detected, isFalse);
    });

    test('(C1) heuristic flow above floor when expected unknown → medium', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(120000)],
        balances: MainAccountBalanceWindow.unknown,
      );
      expect(result.confidence, SalaryDepositConfidence.medium);
      expect(result.signal, SalaryDepositSignal.heuristicFlow);
      expect(result.matchedAmount, 120000);
    });

    test('(C2) heuristic balance jump above floor when expected unknown', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: const [],
        balances: const MainAccountBalanceWindow(
          previousCycleEndBalance: 10000,
          currentBalance: 10000 + 130000,
        ),
      );
      expect(result.confidence, SalaryDepositConfidence.medium);
      expect(result.signal, SalaryDepositSignal.heuristicBalance);
      expect(result.matchedAmount, 130000);
    });

    test('flow below floor with no expected amount → none', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(50000)],
        balances: MainAccountBalanceWindow.unknown,
      );
      expect(result.detected, isFalse);
    });

    test('empty inputs → none', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: const [],
        balances: MainAccountBalanceWindow.unknown,
      );
      expect(result, same(SalaryDepositDetection.none));
    });

    test('custom floor boundary is inclusive', () {
      final atFloor = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(80000)],
        balances: MainAccountBalanceWindow.unknown,
        heuristicFloor: 80000,
      );
      expect(atFloor.detected, isTrue);
      final belowFloor = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(79999)],
        balances: MainAccountBalanceWindow.unknown,
        heuristicFloor: 80000,
      );
      expect(belowFloor.detected, isFalse);
    });

    test('flow match wins over balance jump (priority order)', () {
      final result = AssetSalaryDepositDetector.detect(
        cycleIncomeFlows: [flow(300000)],
        balances: const MainAccountBalanceWindow(
          previousCycleEndBalance: 0,
          currentBalance: 500000,
        ),
        expectedSalaryAmount: 300000,
      );
      expect(result.signal, SalaryDepositSignal.flowAmountMatch);
    });
  });
}

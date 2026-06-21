/// 給料がメインバンクへ振り込まれたかを推定する純関数サービス。
///
/// 負債マスタの「支払済み」チェックは給料日サイクル単位で管理される。新しい
/// サイクルへ切り替える(=チェックをリセットする)契機を「暦の給料日を過ぎたこと」
/// ではなく「実際にメインバンクへ給料が振り込まれたこと」に変えるため、その振込を
/// 検知する。フロー(収支履歴)は口座に紐付かないため、単一シグナルでは確証が得られ
/// ない。そこで複数シグナルを優先度付きで重ね、確度(confidence)付きで返す。
///
/// すべて純粋・同期で `DateTime.now()` を持たない(入力は呼び出し側が用意する)ため
/// 単体テストが容易。`AssetAutoDebitConfirmationService` と同型。
library;

/// 検知の確度。[none] は未検知=リセットせず残高更新を促す。
enum SalaryDepositConfidence { none, medium, high }

/// どのシグナルで検知したか(デバッグ/説明用)。
enum SalaryDepositSignal {
  none,
  flowAmountMatch,
  balanceJump,
  heuristicFlow,
  heuristicBalance,
}

/// サイクル窓内の収入フロー1件(金額は正の円、発生日時はローカル)。
class SalaryDepositFlowObservation {
  const SalaryDepositFlowObservation({
    required this.amount,
    required this.occurredAt,
  });

  /// 収入額(正の円)。
  final double amount;

  /// 発生日時(ローカル)。窓の絞り込みは呼び出し側が済ませる前提だが、
  /// 念のため保持しておく。
  final DateTime occurredAt;
}

/// メインバンク口座の残高変化窓。前サイクル末の残高と現在の残高。
/// いずれかが特定できない場合は null(その場合は残高シグナルを使わない)。
class MainAccountBalanceWindow {
  const MainAccountBalanceWindow({
    required this.previousCycleEndBalance,
    required this.currentBalance,
  });

  final double? previousCycleEndBalance;
  final double? currentBalance;

  /// 前サイクル末 → 現在 の残高増減。特定できない場合は null。
  double? get delta {
    final prev = previousCycleEndBalance;
    final cur = currentBalance;
    if (prev == null || cur == null) {
      return null;
    }
    return cur - prev;
  }

  static const MainAccountBalanceWindow unknown = MainAccountBalanceWindow(
    previousCycleEndBalance: null,
    currentBalance: null,
  );
}

/// 検知結果。
class SalaryDepositDetection {
  const SalaryDepositDetection({
    required this.confidence,
    required this.signal,
    this.matchedAmount,
  });

  final SalaryDepositConfidence confidence;
  final SalaryDepositSignal signal;

  /// 検知の根拠となった金額(フロー額 or 残高増分)。未検知は null。
  final double? matchedAmount;

  bool get detected => confidence != SalaryDepositConfidence.none;

  static const SalaryDepositDetection none = SalaryDepositDetection(
    confidence: SalaryDepositConfidence.none,
    signal: SalaryDepositSignal.none,
  );
}

class AssetSalaryDepositDetector {
  const AssetSalaryDepositDetector();

  /// 現サイクルにメインバンクへの給料振込があったかを推定する。
  ///
  /// シグナル優先度:
  /// - (A) 登録給料額±[amountTolerance] に収まる収入フロー → high (flowAmountMatch)
  /// - (B) メイン口座残高が「給料額×(1-許容)」以上 **増加** → high (balanceJump)
  /// - 登録給料額が無い場合のヒューリスティック:
  ///   - (C1) [heuristicFloor] 以上の単発収入フロー → medium (heuristicFlow)
  ///   - (C2) 残高が [heuristicFloor] 以上 **増加** → medium (heuristicBalance)
  /// - いずれも該当しなければ none(=未検知)。
  ///
  /// 残高の **減少** は給料振込のシグナルにならない(正の増分のみ採用)。
  /// 登録給料額がある場合は誤検知(部分入金などでの早すぎるリセット)を避けるため
  /// ヒューリスティックは使わない。取りこぼしは手動 override で救済する。
  static SalaryDepositDetection detect({
    required List<SalaryDepositFlowObservation> cycleIncomeFlows,
    required MainAccountBalanceWindow balances,
    double? expectedSalaryAmount,
    double amountTolerance = 0.15,
    double heuristicFloor = 100000,
  }) {
    final hasExpected =
        expectedSalaryAmount != null && expectedSalaryAmount > 0;
    if (hasExpected) {
      final expected = expectedSalaryAmount;
      final tolerance = expected * amountTolerance;
      // (A) 給料額に近い収入フロー。
      for (final flow in cycleIncomeFlows) {
        if ((flow.amount - expected).abs() <= tolerance) {
          return SalaryDepositDetection(
            confidence: SalaryDepositConfidence.high,
            signal: SalaryDepositSignal.flowAmountMatch,
            matchedAmount: flow.amount,
          );
        }
      }
      // (B) 給料額相当の残高増加。
      final delta = balances.delta;
      if (delta != null && delta >= expected * (1 - amountTolerance)) {
        return SalaryDepositDetection(
          confidence: SalaryDepositConfidence.high,
          signal: SalaryDepositSignal.balanceJump,
          matchedAmount: delta,
        );
      }
      return SalaryDepositDetection.none;
    }

    // (C) 登録給料額が無い場合のヒューリスティック。
    for (final flow in cycleIncomeFlows) {
      if (flow.amount >= heuristicFloor) {
        return SalaryDepositDetection(
          confidence: SalaryDepositConfidence.medium,
          signal: SalaryDepositSignal.heuristicFlow,
          matchedAmount: flow.amount,
        );
      }
    }
    final delta = balances.delta;
    if (delta != null && delta >= heuristicFloor) {
      return SalaryDepositDetection(
        confidence: SalaryDepositConfidence.medium,
        signal: SalaryDepositSignal.heuristicBalance,
        matchedAmount: delta,
      );
    }
    return SalaryDepositDetection.none;
  }
}

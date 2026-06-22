import 'dart:math';

import '../models/asset_liability_workbook.dart';
import 'asset_debt_trend_analyzer.dart';

/// 「借金しない宣言」モニターが監視する違反の種別。
///
/// - [newBorrowing]: 今月、新規利用（追加借入）が発生した。誓約「追加の借金をしない」違反。
/// - [revolvingCard]: クレジットカード等が当月全額返済されず繰越（リボ/分割）。
///   誓約「カードは必ず一括返済」違反。
enum AssetDebtDisciplineViolationType { newBorrowing, revolvingCard }

/// 1 件の規律違反。金額はすべて Dart 側で計算済みで、AI には説明のみを任せる。
class AssetDebtDisciplineViolation {
  final AssetDebtDisciplineViolationType type;
  final AssetDebtTrendSeverity severity;
  final String accountId;
  final String accountName;
  final AssetLiabilityAccountKind kind;

  /// newBorrowing: 今月の新規利用推定額 / revolvingCard: 翌月への繰越額。
  final double amount;

  /// 現在の利用残高（正の値）。
  final double currentBalance;

  /// 画面・プロンプトに出す「何が起きたか」一文。
  final String problem;

  /// 画面・プロンプトに出す「どうすべきか」一文。
  final String action;

  const AssetDebtDisciplineViolation({
    required this.type,
    required this.severity,
    required this.accountId,
    required this.accountName,
    required this.kind,
    required this.amount,
    required this.currentBalance,
    required this.problem,
    required this.action,
  });
}

/// 「借金しない宣言」モニターの月次評価結果。
class AssetDebtDisciplineReport {
  final List<AssetDebtDisciplineViolation> newBorrowingViolations;
  final List<AssetDebtDisciplineViolation> revolvingCardViolations;

  /// 新規利用判定に必要な前月残高データが 1 件以上あったか。
  final bool hasPriorMonthData;

  /// 今月の新規借入（新規利用）推定合計。
  final double totalNewBorrowing;

  /// 翌月へ繰り越され利息が付く残高の合計（リボ/分割）。
  final double totalCarriedOver;

  /// 監視対象になった借入系口座の数（カード/ローン等・固定費除く）。
  /// 0 のときは監視対象が無い＝モニター自体を表示しない判断に使う。
  final int monitoredAccountCount;

  const AssetDebtDisciplineReport({
    required this.newBorrowingViolations,
    required this.revolvingCardViolations,
    required this.hasPriorMonthData,
    required this.totalNewBorrowing,
    required this.totalCarriedOver,
    required this.monitoredAccountCount,
  });

  /// 表示対象か（監視すべき借入系口座が 1 件以上あるか）。
  bool get isRelevant => monitoredAccountCount > 0;

  List<AssetDebtDisciplineViolation> get allViolations =>
      <AssetDebtDisciplineViolation>[
        ...newBorrowingViolations,
        ...revolvingCardViolations,
      ];

  bool get isCompliant => allViolations.isEmpty;

  /// 誓約①「追加借入ゼロ」を達成しているか。
  bool get zeroNewBorrowingAchieved => newBorrowingViolations.isEmpty;

  /// 誓約②「カードは全額一括」を達成しているか。
  bool get lumpSumAchieved => revolvingCardViolations.isEmpty;

  bool get hasViolations => allViolations.isNotEmpty;
}

/// 「追加の借金をしない／カードは必ず一括返済」という規律を月次で監視する。
///
/// 既存の [AssetDebtTrendAnalyzer] が「借金が複利で膨らんでいないか」を段階的な
/// アドバイスで示すのに対し、本モニターは 2 つの誓約に対する **二値の遵守判定**を行う。
/// 前月の口座別残高（[priorBalancesByAccountId]）から「今月の新規利用額」を推定し、
/// 利息の自然増（複利）と新規借入を切り分ける。
class AssetDebtDisciplineMonitor {
  const AssetDebtDisciplineMonitor({this.newBorrowingThreshold = 1000});

  /// 「新規利用が発生した」と見なす最小額（円）。推定誤差のノイズを問題化しない。
  final double newBorrowingThreshold;

  static const double _epsilon = 1;

  /// 「追加借入」の対象となる借入系の負債種別か。
  ///
  /// 家賃・通信費など [AssetLiabilityDebtRow.fullPaymentEstimate] の固定費は対象外
  /// （毎月全額払いの生活費であり「借金」ではない）。
  static bool isBorrowingKind(AssetLiabilityAccountKind kind) {
    return switch (kind) {
      AssetLiabilityAccountKind.creditCard ||
      AssetLiabilityAccountKind.cardLoan ||
      AssetLiabilityAccountKind.shoppingDebt ||
      AssetLiabilityAccountKind.otherLiability =>
        true,
      _ => false,
    };
  }

  /// 「必ず一括返済」の対象となるカード系の負債種別か（クレカ・ショッピング枠）。
  /// カードローン/キャッシングは借入金であり一括の対象ではない（追加借入のみ監視）。
  static bool isLumpSumCardKind(AssetLiabilityAccountKind kind) {
    return kind == AssetLiabilityAccountKind.creditCard ||
        kind == AssetLiabilityAccountKind.shoppingDebt;
  }

  /// ワークブックと（あれば）前月末の口座別残高から規律違反を評価する。
  AssetDebtDisciplineReport evaluate({
    required AssetLiabilityWorkbook workbook,
    Map<String, double> priorBalancesByAccountId = const <String, double>{},
  }) {
    final newBorrowing = <AssetDebtDisciplineViolation>[];
    final revolving = <AssetDebtDisciplineViolation>[];
    var hasPrior = false;
    var totalNew = 0.0;
    var totalCarried = 0.0;
    var monitoredCount = 0;

    for (final row in workbook.debtMasterRows) {
      if (!isBorrowingKind(row.kind) || row.fullPaymentEstimate) {
        continue;
      }
      final balance = row.balance.abs();
      if (balance <= _epsilon) {
        continue;
      }
      monitoredCount++;
      final interest = max(0.0, row.monthlyInterestEstimate);
      final payment = max(0.0, row.scheduledPaymentAmount);

      // 誓約①: 追加借入ゼロ。前月比＋返済−利息で「今月の新規利用」を推定。
      final prior = priorBalancesByAccountId[row.id];
      if (prior != null) {
        hasPrior = true;
        final newUsage = (balance - prior) + payment - interest;
        if (newUsage > newBorrowingThreshold) {
          totalNew += newUsage;
          newBorrowing.add(
            AssetDebtDisciplineViolation(
              type: AssetDebtDisciplineViolationType.newBorrowing,
              severity: AssetDebtTrendSeverity.critical,
              accountId: row.id,
              accountName: row.name,
              kind: row.kind,
              amount: newUsage,
              currentBalance: balance,
              problem: '${row.name}で今月 約${_yen(newUsage)}の新規利用（追加借入）が発生しました。'
                  '「追加の借金をしない」誓約に反しています。',
              action: '翌月はこのカード/ローンの新規利用を止め、支払いは手元現金またはデビットに切り替えてください。'
                  'どうしても使う場合は、その場で残高を全額入金して借金を翌月へ持ち越さないでください。',
            ),
          );
        }
      }

      // 誓約②: カードは必ず一括。当月に全額返済されず繰り越されるなら違反。
      if (isLumpSumCardKind(row.kind)) {
        final carriedOver = balance - payment;
        final interestBearing = row.annualRate > 0;
        if (carriedOver > _epsilon && interestBearing) {
          totalCarried += carriedOver;
          revolving.add(
            AssetDebtDisciplineViolation(
              type: AssetDebtDisciplineViolationType.revolvingCard,
              severity: AssetDebtTrendSeverity.critical,
              accountId: row.id,
              accountName: row.name,
              kind: row.kind,
              amount: carriedOver,
              currentBalance: balance,
              problem:
                  '${row.name}は残高${_yen(balance)}に対し今月の返済予定が${_yen(payment)}で、'
                  '${_yen(carriedOver)}が翌月へ繰り越され利息が発生します（＝リボ/分割の状態）。'
                  '「カードは必ず一括返済」誓約に反しています。',
              action: 'リボ/分割の設定を解除し、残高${_yen(balance)}を一括返済してください。'
                  '今後カードを使うときは必ず一括（1回払い）に設定し、残高を翌月へ繰り越さないでください。',
            ),
          );
        }
      }
    }

    newBorrowing.sort((a, b) => b.amount.compareTo(a.amount));
    revolving.sort((a, b) => b.amount.compareTo(a.amount));

    return AssetDebtDisciplineReport(
      newBorrowingViolations: List<AssetDebtDisciplineViolation>.unmodifiable(
        newBorrowing,
      ),
      revolvingCardViolations: List<AssetDebtDisciplineViolation>.unmodifiable(
        revolving,
      ),
      hasPriorMonthData: hasPrior,
      totalNewBorrowing: totalNew,
      totalCarriedOver: totalCarried,
      monitoredAccountCount: monitoredCount,
    );
  }

  String _yen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }
}

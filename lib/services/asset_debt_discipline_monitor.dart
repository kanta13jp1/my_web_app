import 'dart:math';

import '../models/asset_liability_workbook.dart';
import 'asset_debt_trend_analyzer.dart';

/// 「借金しない宣言」モニターが監視する違反の種別。
///
/// - [newBorrowing]: カード以外で今月、新規借入が発生した。
/// - [revolvingCard]: カードの新規利用分が最低返済額へ全額上乗せされていない、
///   または返済日が給料日の25日でない。
enum AssetDebtDisciplineViolationType { newBorrowing, revolvingCard }

/// 1 件の規律違反。金額はすべて Dart 側で計算済みで、AI には説明のみを任せる。
class AssetDebtDisciplineViolation {
  final AssetDebtDisciplineViolationType type;
  final AssetDebtTrendSeverity severity;
  final String accountId;
  final String accountName;
  final AssetLiabilityAccountKind kind;

  /// newBorrowing: 今月の新規借入推定額 / revolvingCard: 新規利用分の返済不足額。
  final double amount;

  /// 現在の利用残高（正の値）。
  final double currentBalance;

  /// 画面・プロンプトに出す「何が起きたか」一文。
  final String problem;

  /// 画面・プロンプトに出す「どうすべきか」一文。
  final String action;

  /// revolvingCard: リボ状態から脱却する目標月数（現状は
  /// [AssetDebtDisciplineMonitor.escapeTargetMonths]）。newBorrowing は null。
  final int? escapeMonths;

  /// revolvingCard: [escapeMonths] ヶ月で残高を完済するために必要な
  /// 毎月返済額（年利込み・100円単位切り上げ）。newBorrowing は null。
  final double? escapeMonthlyPayment;

  /// revolvingCard: 今月の返済予定額を続けた場合の完済見込み月数。
  /// 完済できない（返済が利息以下）か返済予定 0 の場合は null。
  final int? currentPlanPayoffMonths;

  /// revolvingCard: 今月の返済予定額を続けた場合の利息総額見込み。
  /// [currentPlanPayoffMonths] が null のときは null。
  final double? currentPlanTotalInterest;

  /// カード会社で「今後の新規利用は1回払い」への変更を記録済みか。
  /// この記録だけを返済実績とは見なさず、true でも不足判定と返済月額目標を維持する。
  final bool oneShotChangeCompleted;

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
    this.escapeMonths,
    this.escapeMonthlyPayment,
    this.currentPlanPayoffMonths,
    this.currentPlanTotalInterest,
    this.oneShotChangeCompleted = false,
  });

  /// 具体的な脱却プラン（月額×期間）を提示できるか。
  bool get hasEscapePlan =>
      escapeMonths != null && escapeMonthlyPayment != null;
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

  /// 誓約②「新規利用分は最低返済額へ上乗せし25日に全額返済」を達成しているか。
  bool get newUsageRepaymentAchieved => revolvingCardViolations.isEmpty;

  /// 旧UI・呼び出し元との互換用。意味は [newUsageRepaymentAchieved] と同じ。
  bool get lumpSumAchieved => newUsageRepaymentAchieved;

  bool get hasViolations => allViolations.isNotEmpty;
}

/// 「カード以外の追加借入をしない／カード新規利用分は25日に全額返済」という
/// 規律を月次で監視する。
///
/// 既存の [AssetDebtTrendAnalyzer] が「借金が複利で膨らんでいないか」を段階的な
/// アドバイスで示すのに対し、本モニターは 2 つの誓約に対する **二値の遵守判定**を行う。
/// 前月の口座別残高（[priorBalancesByAccountId]）から「今月の新規利用額」を推定し、
/// 利息の自然増（複利）と新規借入を切り分ける。
class AssetDebtDisciplineMonitor {
  const AssetDebtDisciplineMonitor({this.newBorrowingThreshold = 1000});

  /// 「新規利用が発生した」と見なす最小額（円）。推定誤差のノイズを問題化しない。
  final double newBorrowingThreshold;

  /// リボ/分割違反に提示する脱却プランの目標月数。
  static const int escapeTargetMonths = 12;

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

  /// 新規利用分の25日返済ルールを適用するカード系の負債種別か
  /// （クレカ・ショッピング枠）。
  ///
  /// メソッド名は既存呼び出し元との互換のため維持している。カードローン/
  /// キャッシングは借入金であり、このルールの対象外（追加借入のみ監視）。
  static bool isLumpSumCardKind(AssetLiabilityAccountKind kind) {
    return kind == AssetLiabilityAccountKind.creditCard ||
        kind == AssetLiabilityAccountKind.shoppingDebt;
  }

  /// ワークブックと（あれば）前月末の口座別残高から規律違反を評価する。
  AssetDebtDisciplineReport evaluate({
    required AssetLiabilityWorkbook workbook,
    Map<String, double> priorBalancesByAccountId = const <String, double>{},
    Map<String, AssetCardUsagePolicy> cardUsagePolicies =
        const <String, AssetCardUsagePolicy>{},
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
      final payment = max(
        0.0,
        row.paid
            ? row.actualPaymentAmount ?? row.scheduledPaymentAmount
            : row.scheduledPaymentAmount,
      );

      // 前月比＋返済−利息で「今月の新規利用」を推定する。リボカードは明細から
      // 算出済みの newUsageAmount を優先し、カード以外だけを誓約①で判定する。
      final prior = priorBalancesByAccountId[row.id];
      double? inferredNewUsage;
      if (prior != null) {
        hasPrior = true;
        inferredNewUsage = (balance - prior) + payment - interest;
        if (!isLumpSumCardKind(row.kind) &&
            inferredNewUsage > newBorrowingThreshold) {
          totalNew += inferredNewUsage;
          newBorrowing.add(
            AssetDebtDisciplineViolation(
              type: AssetDebtDisciplineViolationType.newBorrowing,
              severity: AssetDebtTrendSeverity.critical,
              accountId: row.id,
              accountName: row.name,
              kind: row.kind,
              amount: inferredNewUsage,
              currentBalance: balance,
              problem: '${row.name}で今月 約${_yen(inferredNewUsage)}の新規借入が発生しました。'
                  '「追加の借金をしない」誓約に反しています。',
              action: '翌月はこのローン・借入の新規利用を止め、既存の返済計画を優先してください。',
            ),
          );
        }
      }

      // 誓約②: 既存残高は一括返済せず、新規利用分だけを最低返済額へ全額上乗せして
      // 給料日の25日に返す。残高の繰越自体は違反にしない。
      if (isLumpSumCardKind(row.kind) && row.isRevolving) {
        final revolvingBilling = row.revolvingBilling;
        final newUsage = max(
          0.0,
          revolvingBilling?.newUsageAmount ?? inferredNewUsage ?? 0,
        );
        final minimumPayment = max(
          0.0,
          revolvingBilling?.monthlyAmount ?? row.minimumPaymentEstimate,
        );
        final requiredPayment = minimumPayment + newUsage;
        final shortfall = max(0.0, requiredPayment - payment);
        final paydayAligned = row.paymentDay == 25;
        totalCarried += max(0.0, balance - payment);
        if (shortfall >= _epsilon || !paydayAligned) {
          final oneShotChangeCompleted =
              cardUsagePolicies[row.id]?.enforceOneShot == true;
          final monthlyRate = row.annualRate / 12;
          final escapePayment = AssetDebtTrendAnalyzer.paymentToClearIn(
            balance,
            monthlyRate,
            escapeTargetMonths,
          );
          final currentPlan = payment > 0
              ? AssetDebtTrendAnalyzer.estimatePayoff(
                  balance: balance,
                  monthlyRate: monthlyRate,
                  monthlyPayment: payment,
                )
              : null;
          final currentPlanMonths =
              (currentPlan != null && currentPlan.everPaysOff)
                  ? currentPlan.months
                  : null;
          final String currentPlanText;
          if (payment <= 0) {
            currentPlanText = '今月の返済予定が未入力のため、現状ペースの完済見込みを出せません。';
          } else if (currentPlanMonths != null) {
            currentPlanText =
                '現在の予定額 月${_yen(payment)}のままでは完済まで約$currentPlanMonthsヶ月・'
                '利息総額 約${_yen(currentPlan!.totalInterest)}かかります。';
          } else if (payment <= balance * monthlyRate + _epsilon) {
            currentPlanText =
                '現在の予定額 月${_yen(payment)}では利息に追いつかず、完済の見込みが立ちません。';
          } else {
            // 利息は上回るがシミュレーション上限 (600ヶ月) 内に完済しない。
            currentPlanText = '現在の予定額 月${_yen(payment)}では完済まで50年以上かかる見込みです。';
          }
          final shortageAction = shortfall >= _epsilon
              ? '最低返済${_yen(minimumPayment)}へ新規利用${_yen(newUsage)}を全額上乗せし、'
                  '不足${_yen(shortfall)}を追加してください。'
              : '';
          final paydayAction = paydayAligned ? '' : '返済日を給料日の毎月25日に変更してください。';
          final action = '$shortageAction$paydayAction'
              '既存残高${_yen(balance)}の一括返済は求めません。'
              '無理のない範囲で残高圧縮を続ける場合、月${_yen(escapePayment)}なら'
              '約$escapeTargetMonthsヶ月で完済できる目安です。$currentPlanText';
          revolving.add(
            AssetDebtDisciplineViolation(
              type: AssetDebtDisciplineViolationType.revolvingCard,
              severity: AssetDebtTrendSeverity.critical,
              accountId: row.id,
              accountName: row.name,
              kind: row.kind,
              amount: shortfall,
              currentBalance: balance,
              problem: '${row.name}は新規利用${_yen(newUsage)}に対する'
                  '25日の返済ルールを満たしていません'
                  '（必要${_yen(requiredPayment)} / 予定${_yen(payment)} / '
                  '返済日${row.paymentDay?.toString() ?? '未設定'}日）。',
              action: action,
              escapeMonths: escapeTargetMonths,
              escapeMonthlyPayment: escapePayment,
              currentPlanPayoffMonths: currentPlanMonths,
              currentPlanTotalInterest:
                  currentPlanMonths == null ? null : currentPlan!.totalInterest,
              oneShotChangeCompleted: oneShotChangeCompleted,
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

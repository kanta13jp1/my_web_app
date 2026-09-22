import 'dart:math';

import '../models/asset_liability_workbook.dart';

/// 今月の負債の「問題点」を分類するカテゴリ。
///
/// - [negativeAmortization]: 返済額が利息以下で、残高が永遠に減らない（リボ複利地獄）。
/// - [balanceIncreasing]: 前月比で利用残高が増えており、新規利用が返済を上回っている。
/// - [slowPayoff]: 元金は減るが、今のペースだと完済まで極端に長い。
enum AssetDebtTrendCategory {
  negativeAmortization,
  balanceIncreasing,
  slowPayoff,
}

/// 指摘の重要度。資金繰り系インサイトと同じ 3 段階に揃える。
enum AssetDebtTrendSeverity { info, warning, critical }

/// 1 件の負債に対する「今月の問題点」と「翌月の具体アクション」。
///
/// 金額はすべて Dart 側で計算済みで、AI には説明と優先順位付けのみを任せる
/// （[AssetManagementInsightPromptBuilder] と同じ方針）。
class AssetDebtTrendInsight {
  final String accountId;
  final String accountName;
  final AssetLiabilityAccountKind kind;
  final AssetDebtTrendCategory category;
  final AssetDebtTrendSeverity severity;

  /// 現在の利用残高（負債の絶対額・正の値）。
  final double currentBalance;

  /// 前月末の利用残高（履歴がある場合のみ・正の値）。
  final double? priorBalance;

  /// 前月比の残高変動（正 = 増加）。履歴がある場合のみ。
  final double? balanceDelta;

  /// 今月の月利息見込み。
  final double monthlyInterest;

  /// 今月の返済予定額。
  final double scheduledPayment;

  /// 残高を減らさずに済む「止血ライン」= 利息を 1 円でも上回る返済額。
  final double interestBreakEvenPayment;

  /// 24 ヶ月で完済するための目安返済額（年金現価式）。
  final double payoffIn24MonthsPayment;

  /// 今の返済額のままでの完済月数（null = この返済額では一生終わらない）。
  final int? estimatedPayoffMonths;

  /// 今の返済額のままでの総支払利息見込み（完済する場合のみ）。
  final double? estimatedTotalInterest;

  /// 画面・プロンプトに出す「今月の問題点」一文。
  final String problem;

  /// 画面・プロンプトに出す「翌月の具体アクション」一文。
  final String nextMonthAction;

  const AssetDebtTrendInsight({
    required this.accountId,
    required this.accountName,
    required this.kind,
    required this.category,
    required this.severity,
    required this.currentBalance,
    required this.priorBalance,
    required this.balanceDelta,
    required this.monthlyInterest,
    required this.scheduledPayment,
    required this.interestBreakEvenPayment,
    required this.payoffIn24MonthsPayment,
    required this.estimatedPayoffMonths,
    required this.estimatedTotalInterest,
    required this.problem,
    required this.nextMonthAction,
  });
}

/// 固定額返済を続けたときの完済シミュレーション結果。
class DebtPayoffEstimate {
  /// 完済までの月数（null = [maxMonths] 以内に完済できない）。
  final int? months;

  /// 完済までに支払う利息の総額（完済できない場合は [maxMonths] までの累計）。
  final double totalInterest;

  /// この返済額で元金がいつか 0 になるか。
  final bool everPaysOff;

  const DebtPayoffEstimate({
    required this.months,
    required this.totalInterest,
    required this.everPaysOff,
  });
}

/// 月をまたいだ負債トレンドを決定論的に分析するサービス。
///
/// 既存の [AssetManagementInsightService] は「今〜給料日」の資金繰りに特化しており、
/// 「先月より借金が増えていないか」「返済額が利息に負けていないか」を判定しない。
/// 本サービスがその欠落を埋め、リボ複利・残高増加・超長期完済を検出して
/// 翌月の具体アクションを生成する。
class AssetDebtTrendAnalyzer {
  const AssetDebtTrendAnalyzer({
    this.balanceIncreaseThreshold = 5000,
    this.slowPayoffMonthThreshold = 60,
  });

  /// 「残高が増えた」と見なす最小増加額（円）。小さなブレを問題化しない。
  final double balanceIncreaseThreshold;

  /// 「完済が遅すぎる」と見なす月数の閾値。
  final int slowPayoffMonthThreshold;

  static const double _epsilon = 1;

  /// 利息を持ちうる（=リボ・分割が発生しうる）負債種別か。
  ///
  /// 家賃・通信費など [AssetLiabilityDebtRow.fullPaymentEstimate] の固定費は除外する
  /// （毎月全額払いで残高が累積しないため）。
  static bool isRevolvingLikeKind(AssetLiabilityAccountKind kind) {
    return switch (kind) {
      AssetLiabilityAccountKind.cardLoan ||
      AssetLiabilityAccountKind.shoppingDebt ||
      AssetLiabilityAccountKind.creditCard ||
      AssetLiabilityAccountKind.otherLiability =>
        true,
      _ => false,
    };
  }

  /// ワークブックと（あれば）前月末の口座別残高から負債トレンド指摘を生成する。
  ///
  /// [priorBalancesByAccountId] は accountId -> 前月末の利用残高（正の値）。
  /// 空の場合でも、履歴の要らない①負の償却 ③超長期完済 は検出される。
  List<AssetDebtTrendInsight> analyze({
    required AssetLiabilityWorkbook workbook,
    Map<String, double> priorBalancesByAccountId = const <String, double>{},
  }) {
    final insights = <AssetDebtTrendInsight>[];
    for (final row in workbook.debtMasterRows) {
      final insight = _analyzeRow(row, priorBalancesByAccountId);
      if (insight != null) {
        insights.add(insight);
      }
    }
    insights.sort(_compare);
    return List<AssetDebtTrendInsight>.unmodifiable(insights);
  }

  AssetDebtTrendInsight? _analyzeRow(
    AssetLiabilityDebtRow row,
    Map<String, double> priorBalances,
  ) {
    if (!isRevolvingLikeKind(row.kind) || row.fullPaymentEstimate) {
      return null;
    }
    final balance = row.balance.abs();
    if (balance <= _epsilon) {
      return null;
    }

    final interest = max(0.0, row.monthlyInterestEstimate);
    final payment = max(0.0, row.scheduledPaymentAmount);
    final monthlyRate = row.annualRate / 12;
    final priorBalance = priorBalances[row.id];
    final delta = priorBalance == null ? null : balance - priorBalance;

    final breakEven = interest + 1;
    final payoff24 = paymentToClearIn(balance, monthlyRate, 24);
    final estimate = estimatePayoff(
      balance: balance,
      monthlyRate: monthlyRate,
      monthlyPayment: payment,
    );

    final category = _classify(
      row: row,
      payment: payment,
      delta: delta,
      estimate: estimate,
    );
    if (category == null) {
      return null;
    }

    final severity = _severityFor(
      category: category,
      payment: payment,
      delta: delta,
    );
    final problem = _problemText(
      category: category,
      row: row,
      balance: balance,
      delta: delta,
      interest: interest,
      payment: payment,
      estimate: estimate,
    );
    final action = _actionText(
      category: category,
      balance: balance,
      delta: delta,
      payment: payment,
      breakEven: breakEven,
      payoff24: payoff24,
    );

    return AssetDebtTrendInsight(
      accountId: row.id,
      accountName: row.name,
      kind: row.kind,
      category: category,
      severity: severity,
      currentBalance: balance,
      priorBalance: priorBalance,
      balanceDelta: delta,
      monthlyInterest: interest,
      scheduledPayment: payment,
      interestBreakEvenPayment: breakEven,
      payoffIn24MonthsPayment: payoff24,
      estimatedPayoffMonths: estimate.months,
      estimatedTotalInterest:
          estimate.everPaysOff ? estimate.totalInterest : null,
      problem: problem,
      nextMonthAction: action,
    );
  }

  AssetDebtTrendCategory? _classify({
    required AssetLiabilityDebtRow row,
    required double payment,
    required double? delta,
    required DebtPayoffEstimate estimate,
  }) {
    // ① 返済額が利息以下 → 元金が 1 円も減らない（最優先で指摘）。
    if (payment > 0 && row.principalPaymentEstimate < _epsilon) {
      return AssetDebtTrendCategory.negativeAmortization;
    }
    // ② 前月比で残高が増加（新規利用が返済を侵食）。
    if (delta != null && delta > balanceIncreaseThreshold) {
      return AssetDebtTrendCategory.balanceIncreasing;
    }
    // ③ 元金は減るが完済まで極端に長い。
    if (estimate.everPaysOff &&
        estimate.months != null &&
        estimate.months! > slowPayoffMonthThreshold) {
      return AssetDebtTrendCategory.slowPayoff;
    }
    return null;
  }

  AssetDebtTrendSeverity _severityFor({
    required AssetDebtTrendCategory category,
    required double payment,
    required double? delta,
  }) {
    switch (category) {
      case AssetDebtTrendCategory.negativeAmortization:
        return AssetDebtTrendSeverity.critical;
      case AssetDebtTrendCategory.balanceIncreasing:
        // 増加額が返済額を上回る = 払っても追いつかない → critical。
        if (delta != null && delta > payment) {
          return AssetDebtTrendSeverity.critical;
        }
        return AssetDebtTrendSeverity.warning;
      case AssetDebtTrendCategory.slowPayoff:
        return AssetDebtTrendSeverity.warning;
    }
  }

  String _problemText({
    required AssetDebtTrendCategory category,
    required AssetLiabilityDebtRow row,
    required double balance,
    required double? delta,
    required double interest,
    required double payment,
    required DebtPayoffEstimate estimate,
  }) {
    switch (category) {
      case AssetDebtTrendCategory.negativeAmortization:
        return '${row.name}は今月の返済予定額${_yen(payment)}が利息${_yen(interest)}以下です。'
            'このままでは元金が1円も減らず、残高${_yen(balance)}は利息分だけ毎月膨らみ続けます。';
      case AssetDebtTrendCategory.balanceIncreasing:
        final increase = delta ?? 0;
        final net = increase - payment;
        final netClause = net > 0
            ? '返済${_yen(payment)}を払っても純増${_yen(net)}で、借金は雪だるま式に増えています。'
            : '返済${_yen(payment)}でかろうじて吸収していますが、新規利用が返済を圧迫しています。';
        return '${row.name}の利用残高が先月比+${_yen(increase)}（${_yen(balance)}）に増えました。'
            '$netClause';
      case AssetDebtTrendCategory.slowPayoff:
        final months = estimate.months;
        final years = months == null ? null : (months / 12);
        final yearsText =
            years == null ? '' : '（約${years.toStringAsFixed(1)}年）';
        final interestText = estimate.everPaysOff
            ? '完済までに利息だけで${_yen(estimate.totalInterest)}を支払う計算です。'
            : '';
        return '${row.name}は今の返済額${_yen(payment)}だと完済まで約${months ?? '-'}ヶ月$yearsText。'
            '$interestText';
    }
  }

  String _actionText({
    required AssetDebtTrendCategory category,
    required double balance,
    required double? delta,
    required double payment,
    required double breakEven,
    required double payoff24,
  }) {
    switch (category) {
      case AssetDebtTrendCategory.negativeAmortization:
        return '既存残高の一括返済は求めません。翌月から最低返済額を利息を上回る'
            '${_yen(breakEven)}（24ヶ月で完済するなら${_yen(payoff24)}）以上にしてください。'
            '新規利用分は別枠で全額上乗せし、給料日の25日に返済します。';
      case AssetDebtTrendCategory.balanceIncreasing:
        return '翌月は最低返済額に新規利用分を全額上乗せし、給料日の25日に返済して'
            '残高を増やさないでください。既存残高は一括返済せず、'
            '24ヶ月で完済するなら最低返済部分は月${_yen(payoff24)}が目安です。';
      case AssetDebtTrendCategory.slowPayoff:
        return '返済額を月${_yen(payoff24)}まで引き上げると24ヶ月で完済でき、利息総額を大きく圧縮できます。'
            '余力がある月は繰上返済を行い、新規利用分は25日に全額上乗せしてください。';
    }
  }

  int _compare(AssetDebtTrendInsight a, AssetDebtTrendInsight b) {
    final severity =
        _severityRank(b.severity).compareTo(_severityRank(a.severity));
    if (severity != 0) {
      return severity;
    }
    // 重要度が同じなら、残高への影響が大きい順（増加額 → 残高）。
    final aImpact = (a.balanceDelta ?? 0).abs();
    final bImpact = (b.balanceDelta ?? 0).abs();
    final impact = bImpact.compareTo(aImpact);
    if (impact != 0) {
      return impact;
    }
    final balance = b.currentBalance.compareTo(a.currentBalance);
    if (balance != 0) {
      return balance;
    }
    return a.accountName.compareTo(b.accountName);
  }

  int _severityRank(AssetDebtTrendSeverity severity) {
    return switch (severity) {
      AssetDebtTrendSeverity.critical => 3,
      AssetDebtTrendSeverity.warning => 2,
      AssetDebtTrendSeverity.info => 1,
    };
  }

  /// 負債マスタ行の現在の予定返済額を続けた場合の完済シミュレーション。
  /// UI のインライン表示 (リボの概算脱却目安) 用。計算は Dart が正。
  static DebtPayoffEstimate estimateForRow(AssetLiabilityDebtRow row) {
    return estimatePayoff(
      balance: row.balance.abs(),
      monthlyRate: max(0.0, row.annualRate) / 12,
      monthlyPayment: max(0.0, row.scheduledPaymentAmount),
    );
  }

  /// 固定額返済を続けたときの完済シミュレーション。
  ///
  /// [monthlyPayment] が初月の利息以下なら元金が減らないため、
  /// [DebtPayoffEstimate.everPaysOff] = false / [DebtPayoffEstimate.months] = null を返す。
  static DebtPayoffEstimate estimatePayoff({
    required double balance,
    required double monthlyRate,
    required double monthlyPayment,
    int maxMonths = 600,
  }) {
    if (balance <= _epsilon) {
      return const DebtPayoffEstimate(
        months: 0,
        totalInterest: 0,
        everPaysOff: true,
      );
    }
    final rate = max(0.0, monthlyRate);
    final firstInterest = balance * rate;
    if (monthlyPayment <= firstInterest + _epsilon) {
      // 返済額が利息を超えない限り元金は減らない。
      return DebtPayoffEstimate(
        months: null,
        totalInterest: firstInterest,
        everPaysOff: false,
      );
    }
    var remaining = balance;
    var totalInterest = 0.0;
    for (var month = 1; month <= maxMonths; month++) {
      final interest = remaining * rate;
      totalInterest += interest;
      remaining = remaining + interest - monthlyPayment;
      if (remaining <= _epsilon) {
        return DebtPayoffEstimate(
          months: month,
          totalInterest: totalInterest,
          everPaysOff: true,
        );
      }
    }
    return DebtPayoffEstimate(
      months: null,
      totalInterest: totalInterest,
      everPaysOff: false,
    );
  }

  /// [targetMonths] ヶ月で完済するために必要な毎月返済額（年金現価式）。
  ///
  /// 月利 0 のときは単純に balance / months。100 円単位へ切り上げる。
  static double paymentToClearIn(
    double balance,
    double monthlyRate,
    int targetMonths,
  ) {
    final months = max(1, targetMonths);
    final rate = max(0.0, monthlyRate);
    final double raw;
    if (rate <= 0) {
      raw = balance / months;
    } else {
      final factor = pow(1 + rate, months).toDouble();
      raw = balance * rate * factor / (factor - 1);
    }
    return (raw / 100).ceilToDouble() * 100;
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

import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';

/// リボ払い負債に「毎月X円上乗せ」した場合の完済期間・総利息の変化。
/// 計算は [AssetDebtTrendAnalyzer.estimatePayoff] に委譲する (クライアント完結)。
class RevolvingExtraPaymentResult {
  final double extraPayment;
  final DebtPayoffEstimate baseline;
  final DebtPayoffEstimate boosted;

  const RevolvingExtraPaymentResult({
    required this.extraPayment,
    required this.baseline,
    required this.boosted,
  });

  /// 短縮できる月数。現ペースで完済不能なら比較不能のため null。
  int? get monthsSaved {
    final before = baseline.months;
    final after = boosted.months;
    if (before == null || after == null) return null;
    return before - after;
  }

  /// 削減できる利息。どちらかが完済不能なら比較不能のため null。
  double? get interestSaved {
    if (!baseline.everPaysOff || !boosted.everPaysOff) return null;
    return baseline.totalInterest - boosted.totalInterest;
  }

  /// 現ペースでは完済不能だが、上乗せ後は完済できる。
  bool get becomesPayable => !baseline.everPaysOff && boosted.everPaysOff;
}

class AssetRevolvingExtraPaymentSimulator {
  const AssetRevolvingExtraPaymentSimulator._();

  static RevolvingExtraPaymentResult simulate({
    required AssetLiabilityDebtRow row,
    required double extraPayment,
  }) {
    final extra = max(0.0, extraPayment);
    final balance = row.balance.abs();
    final monthlyRate = max(0.0, row.annualRate) / 12;
    final base = max(0.0, row.scheduledPaymentAmount);
    return RevolvingExtraPaymentResult(
      extraPayment: extra,
      baseline: AssetDebtTrendAnalyzer.estimatePayoff(
        balance: balance,
        monthlyRate: monthlyRate,
        monthlyPayment: base,
      ),
      boosted: AssetDebtTrendAnalyzer.estimatePayoff(
        balance: balance,
        monthlyRate: monthlyRate,
        monthlyPayment: base + extra,
      ),
    );
  }
}

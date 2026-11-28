import 'package:my_web_app/models/asset_liability_workbook.dart';

class AssetPrincipalInterestBreakdown {
  const AssetPrincipalInterestBreakdown({
    required this.accountId,
    required this.monthlyPaymentAmount,
    required this.principalAmount,
    required this.interestAmount,
    required this.principalRatio,
    required this.interestRatio,
    required this.isLowPrincipalEfficiency,
  });

  final String accountId;
  final double monthlyPaymentAmount;
  final double principalAmount;
  final double interestAmount;
  final double principalRatio;
  final double interestRatio;
  final bool isLowPrincipalEfficiency;
}

class AssetPrincipalInterestBreakdownService {
  const AssetPrincipalInterestBreakdownService._();

  static const double lowPrincipalRatioThreshold = 0.5;

  static AssetPrincipalInterestBreakdown? build(AssetLiabilityDebtRow row) {
    if (!row.isDirectCashflowTarget) {
      return null;
    }
    if (row.monthlyInterestEstimate <= 0 && row.principalPaymentEstimate <= 0) {
      return null;
    }
    final monthlyPayment = row.effectiveMonthlyPaymentAmount;
    if (monthlyPayment <= 0) {
      return null;
    }

    final sumBreakdown =
        row.principalPaymentEstimate + row.monthlyInterestEstimate;
    final denominator = sumBreakdown > 0 ? sumBreakdown : monthlyPayment;
    final principalRatio =
        (row.principalPaymentEstimate / denominator).clamp(0.0, 1.0);
    final interestRatio =
        (row.monthlyInterestEstimate / denominator).clamp(0.0, 1.0);

    return AssetPrincipalInterestBreakdown(
      accountId: row.id,
      monthlyPaymentAmount: monthlyPayment,
      principalAmount: row.principalPaymentEstimate,
      interestAmount: row.monthlyInterestEstimate,
      principalRatio: principalRatio,
      interestRatio: interestRatio,
      isLowPrincipalEfficiency: row.monthlyInterestEstimate > 0 &&
          principalRatio < lowPrincipalRatioThreshold,
    );
  }

  static String summaryLabel(
    AssetPrincipalInterestBreakdown breakdown,
    String Function(double) formatYen,
  ) {
    final principalPct = (breakdown.principalRatio * 100).round();
    final interestPct = (breakdown.interestRatio * 100).round();
    return '元金 ${formatYen(breakdown.principalAmount)} ($principalPct%) / '
        '利息 ${formatYen(breakdown.interestAmount)} ($interestPct%)';
  }

  static String lowEfficiencyWarningLabel(
    AssetPrincipalInterestBreakdown breakdown,
  ) {
    final principalPct = (breakdown.principalRatio * 100).round();
    return '元金充当率低 ($principalPct%)';
  }
}

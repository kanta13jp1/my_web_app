import 'package:my_web_app/models/asset_liability_workbook.dart';

/// 支出・リボ・借入の「精神的・金銭的な痛み」を労働時間や日歩利息として直感的に数値化するサービス (Issue #5203)。
class AssetPainMetricService {
  const AssetPainMetricService();

  /// 既定の手取り時給 (月収未設定時のフォールバック)。
  static const double defaultHourlyWage = 2500;

  /// 月間標準実働時間 (1日8h × 20日 = 160h)。
  static const double monthlyStandardWorkHours = 160;

  /// 手取り時給を推定 (手取り月収 ÷ 160h)。
  double estimateHourlyWage({
    double? monthlyIncome,
  }) {
    if (monthlyIncome == null || monthlyIncome <= 0) {
      return defaultHourlyWage;
    }
    return (monthlyIncome / monthlyStandardWorkHours).clamp(1000, 100000);
  }

  /// 金額を労働時間 (例: "2.5時間", "45分") に換算。
  String formatLaborTime(
    double amount, {
    double hourlyWage = defaultHourlyWage,
  }) {
    if (amount <= 0 || hourlyWage <= 0) {
      return '0分';
    }
    final hours = amount / hourlyWage;
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes分';
    }
    return '${hours.toStringAsFixed(1)}時間';
  }

  /// 1日あたりの利息流血額 (月間利息合計 ÷ 30日)。
  double dailyInterestLoss({
    required double monthlyInterestTotal,
  }) {
    if (monthlyInterestTotal <= 0) {
      return 0;
    }
    return monthlyInterestTotal / 30;
  }

  /// 1日あたりの利息流血による労働消失時間 (時間)。
  double dailyLaborHoursLost({
    required double monthlyInterestTotal,
    double hourlyWage = defaultHourlyWage,
  }) {
    final dailyLoss = dailyInterestLoss(
      monthlyInterestTotal: monthlyInterestTotal,
    );
    if (dailyLoss <= 0 || hourlyWage <= 0) {
      return 0;
    }
    return dailyLoss / hourlyWage;
  }

  /// ワークブック全体の月間利息から日歩利息流血額を計算。
  static double calculateDailyInterestBleed(AssetLiabilityWorkbook workbook) {
    var monthlyInterest = 0.0;
    for (final debt in workbook.debtMasterRows) {
      if (debt.isDirectCashflowTarget && debt.balance < 0) {
        final annualRate = debt.annualRate;
        if (annualRate > 0) {
          monthlyInterest += (-debt.balance) * (annualRate / 100.0) / 12.0;
        }
      }
    }
    return monthlyInterest / 30.0;
  }

  /// 1日あたりの利息流出による労働消失時間。
  static double dailyLostLaborHours(
    AssetLiabilityWorkbook workbook, {
    double hourlyWage = defaultHourlyWage,
  }) {
    final dailyBleed = calculateDailyInterestBleed(workbook);
    if (dailyBleed <= 0 || hourlyWage <= 0) return 0;
    return dailyBleed / hourlyWage;
  }

  /// Nヶ月間で借金によって奪われる将来資金の累計額。
  static double stolenFutureTotal({
    required AssetLiabilityWorkbook workbook,
    int months = 6,
  }) {
    final dailyBleed = calculateDailyInterestBleed(workbook);
    return dailyBleed * 30.0 * months;
  }
}

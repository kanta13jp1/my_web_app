import '../models/asset_liability_workbook.dart';

/// リボ払いカードの今月返済予定額を算出する純関数サービス。
///
/// 手元資金で既存残高をいきなり一括返済することは求めず、次の式で
/// 残高増加を防ぐ:
///
///   返済予定額 = 既存残高への最低返済額 + 当月の新規利用額
///
/// 新規利用額は同月25日に全額上乗せし、既存残高だけを最低返済額で圧縮する。
class AssetRevolvingCreditService {
  const AssetRevolvingCreditService();

  /// [config] と現在の [balance] (リボ残高) から今月の返済内訳を算出する。
  /// [newUsageAmount] が指定された場合は取込明細の合計として手入力設定より優先する。
  AssetLiabilityRevolvingCreditBilling computeBilling({
    required double balance,
    required AssetLiabilityRevolvingCreditConfig config,
    double? newUsageAmount,
  }) {
    final normalizedBalance = balance > 0 ? balance : 0.0;
    final requestedNewUsage = newUsageAmount ?? config.newUsageAmount;
    final normalizedNewUsage = requestedNewUsage > 0
        ? requestedNewUsage.clamp(0.0, normalizedBalance).toDouble()
        : 0.0;
    final existingBalance = normalizedBalance - normalizedNewUsage;
    final requestedMinimum =
        config.monthlyAmount > 0 ? config.monthlyAmount : 0.0;
    final minimumPayment =
        requestedMinimum.clamp(0.0, existingBalance).toDouble();
    const paymentDay = 25;
    return AssetLiabilityRevolvingCreditBilling(
      balance: normalizedBalance,
      creditLimit: config.creditLimit,
      monthlyAmount: minimumPayment,
      newUsageAmount: normalizedNewUsage,
      existingBalanceAmount: existingBalance,
      paymentDay: paymentDay,
      overLimitAmount: 0,
      billedAmount: minimumPayment + normalizedNewUsage,
    );
  }
}

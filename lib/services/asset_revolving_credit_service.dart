import '../models/asset_liability_workbook.dart';

/// リボ払いカードの今月請求額を算出する純関数サービス。
///
/// auPAY カードなどの「あらかじめリボ」方式では、毎月の請求額は利用明細の
/// 合計ではなく次の式で決まる:
///
///   請求額 = リボ設定額 + max(0, リボ残高 − 利用限度額)
///
/// 利用限度額の範囲内ならリボ設定額のみが請求され、限度額を超えた分だけが
/// その月に一括で上乗せ請求される。利用明細(新規利用)はリボ残高に積み増され、
/// その月の請求額とは直接対応しない(= 明細合計 ≠ 請求額 が正常)。
class AssetRevolvingCreditService {
  const AssetRevolvingCreditService();

  /// [config] と現在の [balance] (リボ残高) から今月の請求内訳を算出する。
  AssetLiabilityRevolvingCreditBilling computeBilling({
    required double balance,
    required AssetLiabilityRevolvingCreditConfig config,
  }) {
    final normalizedBalance = balance > 0 ? balance : 0.0;
    // 利用限度額が未設定 (0以下) なら上乗せ請求なしとして設定額のみ請求する。
    // リボ設定の入力途中で請求額が残高全額へ跳ねるのを防ぐ安全側の扱い。
    final hasLimit = config.creditLimit > 0;
    final overLimit = hasLimit ? normalizedBalance - config.creditLimit : 0.0;
    final overLimitAmount = overLimit > 0 ? overLimit : 0.0;
    return AssetLiabilityRevolvingCreditBilling(
      balance: normalizedBalance,
      creditLimit: config.creditLimit,
      monthlyAmount: config.monthlyAmount,
      overLimitAmount: overLimitAmount,
      billedAmount: config.monthlyAmount + overLimitAmount,
    );
  }
}

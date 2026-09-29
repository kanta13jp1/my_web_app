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
  /// [statementLines] がある場合は明細ごとの利用先・金額および返済カバー状況
  /// （リボ残高組み入れ・返済不足等）の内訳を生成する。
  AssetLiabilityRevolvingCreditBilling computeBilling({
    required double balance,
    required AssetLiabilityRevolvingCreditConfig config,
    double? newUsageAmount,
    List<AssetLiabilityCardStatementLine>? statementLines,
    bool? hasImportedStatement,
    double? scheduledPayment,
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
    final billedAmount = minimumPayment + normalizedNewUsage;

    final isImported = hasImportedStatement ??
        (statementLines != null && statementLines.isNotEmpty);
    final items = <AssetLiabilityRevolvingUsageItem>[];

    if (statementLines != null && statementLines.isNotEmpty) {
      final effectivePayment = scheduledPayment ?? billedAmount;
      var remainingCoverageBudget =
          (effectivePayment - minimumPayment).clamp(0.0, double.infinity);

      for (final line in statementLines) {
        final lineAmount = line.amount;
        final AssetLiabilityRevolvingUsageStatus status;
        final String statusLabel;

        if (lineAmount <= remainingCoverageBudget) {
          status = AssetLiabilityRevolvingUsageStatus.covered;
          statusLabel = '今月返済でカバー';
          remainingCoverageBudget -= lineAmount;
        } else if (remainingCoverageBudget > 0) {
          status = AssetLiabilityRevolvingUsageStatus.uncoveredShortfall;
          statusLabel = '返済一部不足（リボ算入）';
          remainingCoverageBudget = 0;
        } else {
          status = AssetLiabilityRevolvingUsageStatus.uncoveredShortfall;
          statusLabel = '返済不足（リボ残高算入・繰越）';
        }

        items.add(
          AssetLiabilityRevolvingUsageItem(
            id: line.id,
            description: line.description,
            amount: line.amount,
            postedAt: line.postedAt,
            status: status,
            statusLabel: statusLabel,
          ),
        );
      }
    } else if (normalizedNewUsage > 0) {
      final effectivePayment = scheduledPayment ?? billedAmount;
      final hasShortfall =
          (effectivePayment - minimumPayment) < normalizedNewUsage;
      items.add(
        AssetLiabilityRevolvingUsageItem(
          id: 'manual_usage',
          description: '当月新規利用額（手入力設定）',
          amount: normalizedNewUsage,
          status: hasShortfall
              ? AssetLiabilityRevolvingUsageStatus.uncoveredShortfall
              : AssetLiabilityRevolvingUsageStatus.covered,
          statusLabel: hasShortfall ? '返済不足（リボ残高算入・繰越）' : '今月返済でカバー',
        ),
      );
    }

    return AssetLiabilityRevolvingCreditBilling(
      balance: normalizedBalance,
      creditLimit: config.creditLimit,
      monthlyAmount: minimumPayment,
      newUsageAmount: normalizedNewUsage,
      existingBalanceAmount: existingBalance,
      paymentDay: paymentDay,
      overLimitAmount: 0,
      billedAmount: billedAmount,
      usageItems: List<AssetLiabilityRevolvingUsageItem>.unmodifiable(items),
      hasImportedStatement: isImported,
    );
  }
}

import 'dart:math';

import '../models/asset_liability_workbook.dart';

/// 個別負債の遅延損害金・延滞金計算結果。
class AssetLateFeeCalculation {
  const AssetLateFeeCalculation({
    required this.overdueDays,
    required this.lateFeeAnnualRate,
    required this.estimatedLateFeeAmount,
    required this.projectedBalanceWithLateFee,
  });

  final int overdueDays;
  final double? lateFeeAnnualRate;
  final double estimatedLateFeeAmount;
  final double projectedBalanceWithLateFee;
}

/// 延滞中負債 1 件分の遅延損害金サマリ項目。
class AssetLateFeeItem {
  const AssetLateFeeItem({
    required this.accountId,
    required this.accountName,
    required this.paymentDay,
    required this.overdueDays,
    required this.lateFeeAnnualRate,
    required this.estimatedLateFeeAmount,
    required this.balanceAbs,
    required this.projectedBalanceWithLateFee,
  });

  final String accountId;
  final String accountName;
  final int? paymentDay;
  final int overdueDays;
  final double lateFeeAnnualRate;
  final double estimatedLateFeeAmount;
  final double balanceAbs;
  final double projectedBalanceWithLateFee;
}

/// ワークブック全体の遅延損害金・延滞金サマリ。
class AssetLateFeeSummary {
  const AssetLateFeeSummary({
    required this.overdueCount,
    required this.totalEstimatedLateFee,
    required this.items,
  });

  final int overdueCount;
  final double totalEstimatedLateFee;
  final List<AssetLateFeeItem> items;
}

/// 支払遅延時の遅延損害金・延滞金を決定論的に算出するサービス（#3442）。
class AssetLateFeeService {
  const AssetLateFeeService._();

  /// 約定金利が未入力または法定水準以下の場合のフォールバック年利（14.6%）。
  static const double statutoryFallbackAnnualRate = 0.146;

  /// 上限金利（利息制限法・一般的な延滞上限 20.0%）。
  static const double maxAnnualRateCeiling = 0.20;

  /// 契約種別と登録年利に基づく遅延損害金年利の概算既定値。
  static double defaultLateFeeAnnualRate({
    required AssetLiabilityAccountKind kind,
    required double annualRate,
  }) {
    if (annualRate > statutoryFallbackAnnualRate) {
      return min(annualRate, maxAnnualRateCeiling);
    }
    return statutoryFallbackAnnualRate;
  }

  /// 日割り概算 `(予定支払額 × 年利 × 遅延日数 / 365)` で遅延損害金を算出する。
  static AssetLateFeeCalculation estimate({
    required AssetLiabilityAccountKind kind,
    required double annualRate,
    required double balance,
    required double scheduledPaymentAmount,
    required bool paid,
    required bool requiresAction,
    required bool isDirectCashflowTarget,
    required DateTime? baseDate,
    required DateTime? paymentDate,
    double? customLateFeeAnnualRate,
  }) {
    final balanceAbs = balance.abs();
    if (paid ||
        !requiresAction ||
        !isDirectCashflowTarget ||
        scheduledPaymentAmount <= 0 ||
        baseDate == null ||
        paymentDate == null) {
      return AssetLateFeeCalculation(
        overdueDays: 0,
        lateFeeAnnualRate: null,
        estimatedLateFeeAmount: 0,
        projectedBalanceWithLateFee: balanceAbs,
      );
    }

    final baseDay = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final payDay = DateTime(
      paymentDate.year,
      paymentDate.month,
      paymentDate.day,
    );
    final overdueDays = baseDay.difference(payDay).inDays;
    if (overdueDays <= 0) {
      return AssetLateFeeCalculation(
        overdueDays: 0,
        lateFeeAnnualRate: null,
        estimatedLateFeeAmount: 0,
        projectedBalanceWithLateFee: balanceAbs,
      );
    }

    final effectiveRate = customLateFeeAnnualRate ??
        defaultLateFeeAnnualRate(kind: kind, annualRate: annualRate);
    final estimatedLateFee =
        (scheduledPaymentAmount * effectiveRate * overdueDays / 365.0)
            .roundToDouble();
    return AssetLateFeeCalculation(
      overdueDays: overdueDays,
      lateFeeAnnualRate: effectiveRate,
      estimatedLateFeeAmount: estimatedLateFee,
      projectedBalanceWithLateFee: balanceAbs + estimatedLateFee,
    );
  }

  /// ワークブック内の遅延発生行を集計して残高加算影響を含むサマリを返す。
  static AssetLateFeeSummary summarizeWorkbook(
    AssetLiabilityWorkbook workbook,
  ) {
    final items = <AssetLateFeeItem>[];
    var totalLateFee = 0.0;

    for (final row in workbook.debtMasterRows) {
      if (row.paid ||
          !row.requiresAction ||
          !row.isDirectCashflowTarget ||
          row.overdueDays <= 0 ||
          row.estimatedLateFeeAmount <= 0) {
        continue;
      }
      final rate = row.lateFeeAnnualRate ??
          defaultLateFeeAnnualRate(kind: row.kind, annualRate: row.annualRate);
      final balanceAbs = row.balance.abs();
      totalLateFee += row.estimatedLateFeeAmount;
      items.add(
        AssetLateFeeItem(
          accountId: row.id,
          accountName: row.name,
          paymentDay: row.paymentDay,
          overdueDays: row.overdueDays,
          lateFeeAnnualRate: rate,
          estimatedLateFeeAmount: row.estimatedLateFeeAmount,
          balanceAbs: balanceAbs,
          projectedBalanceWithLateFee: balanceAbs + row.estimatedLateFeeAmount,
        ),
      );
    }

    items.sort((a, b) {
      final feeCmp = b.estimatedLateFeeAmount.compareTo(
        a.estimatedLateFeeAmount,
      );
      if (feeCmp != 0) {
        return feeCmp;
      }
      return a.accountName.compareTo(b.accountName);
    });

    return AssetLateFeeSummary(
      overdueCount: items.length,
      totalEstimatedLateFee: totalLateFee,
      items: List<AssetLateFeeItem>.unmodifiable(items),
    );
  }
}

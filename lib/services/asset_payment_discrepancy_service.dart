import 'package:my_web_app/models/asset_liability_workbook.dart';

class AssetPaymentDiscrepancyItem {
  const AssetPaymentDiscrepancyItem({
    required this.accountId,
    required this.accountName,
    required this.paymentDay,
    required this.scheduledPaymentAmount,
    required this.actualPaymentAmount,
    required this.differenceAmount,
    required this.reason,
    required this.exceedsThreshold,
    required this.missingReason,
    this.minimumPaymentEstimate = 0,
  });

  final String accountId;
  final String accountName;
  final int? paymentDay;
  final double scheduledPaymentAmount;
  final double actualPaymentAmount;
  final double differenceAmount;
  final String? reason;
  final bool exceedsThreshold;
  final bool missingReason;
  final double minimumPaymentEstimate;

  /// Insight・AI要約向けの代表差額（予定額との差を優先し、0なら推定最低額との差）。
  double get effectiveDifferenceForInsight => differenceAmount.abs() >= 1
      ? differenceAmount
      : (minimumPaymentEstimate > 0
          ? actualPaymentAmount - minimumPaymentEstimate
          : differenceAmount);
}

class AssetPaymentDiscrepancyService {
  const AssetPaymentDiscrepancyService._();

  static const double defaultThresholdYen = 1000;

  static List<AssetPaymentDiscrepancyItem> detectDiscrepancies(
    AssetLiabilityWorkbook workbook, {
    double thresholdYen = defaultThresholdYen,
  }) {
    final items = <AssetPaymentDiscrepancyItem>[];
    for (final row in workbook.debtMasterRows) {
      if (!row.isDirectCashflowTarget) {
        continue;
      }
      final actual = row.actualPaymentAmount;
      if (actual == null) {
        continue;
      }
      final diff = actual - row.scheduledPaymentAmount;
      if (diff.abs() < 1) {
        continue;
      }
      final exceedsThreshold = diff.abs() >= thresholdYen;
      final normalizedReason = row.paymentDifferenceReason?.trim();
      final missingReason =
          normalizedReason == null || normalizedReason.isEmpty;
      if (!exceedsThreshold && !missingReason) {
        continue;
      }
      items.add(
        AssetPaymentDiscrepancyItem(
          accountId: row.id,
          accountName: row.name,
          paymentDay: row.paymentDay,
          scheduledPaymentAmount: row.scheduledPaymentAmount,
          actualPaymentAmount: actual,
          differenceAmount: diff,
          reason: missingReason ? null : normalizedReason,
          exceedsThreshold: exceedsThreshold,
          missingReason: missingReason,
          minimumPaymentEstimate: row.minimumPaymentEstimate,
        ),
      );
    }

    return _sortItems(items);
  }

  /// AI要約・要対応アクション向けに、予定額または推定最低支払額と実支払額に
  /// 差額のある負債行をすべて抽出する。
  static List<AssetPaymentDiscrepancyItem> detectAllForInsight(
    AssetLiabilityWorkbook workbook,
  ) {
    final items = <AssetPaymentDiscrepancyItem>[];
    for (final row in workbook.debtMasterRows) {
      if (!row.isDirectCashflowTarget) {
        continue;
      }
      final actual = row.actualPaymentAmount;
      if (actual == null) {
        continue;
      }
      final diff = actual - row.scheduledPaymentAmount;
      final minDiff = row.minimumPaymentEstimate > 0
          ? actual - row.minimumPaymentEstimate
          : 0.0;
      if (diff.abs() < 1 && minDiff.abs() < 1) {
        continue;
      }
      final normalizedReason = row.paymentDifferenceReason?.trim();
      final missingReason =
          normalizedReason == null || normalizedReason.isEmpty;
      items.add(
        AssetPaymentDiscrepancyItem(
          accountId: row.id,
          accountName: row.name,
          paymentDay: row.paymentDay,
          scheduledPaymentAmount: row.scheduledPaymentAmount,
          actualPaymentAmount: actual,
          differenceAmount: diff,
          reason: missingReason ? null : normalizedReason,
          exceedsThreshold: diff.abs() >= defaultThresholdYen,
          missingReason: missingReason,
          minimumPaymentEstimate: row.minimumPaymentEstimate,
        ),
      );
    }
    return _sortItems(items);
  }

  /// 予定額・推定最低支払額を下回る実支払（未払いの穴・補填確認が必要か）。
  static bool needsTopUp(AssetPaymentDiscrepancyItem item) {
    return item.actualPaymentAmount + 1 <= item.scheduledPaymentAmount ||
        (item.minimumPaymentEstimate > 0 &&
            item.actualPaymentAmount + 1 <= item.minimumPaymentEstimate);
  }

  /// 差額の発生要因について確認を促す推定ヒントを返す。
  static String inferReasonHint(AssetPaymentDiscrepancyItem item) {
    if (item.minimumPaymentEstimate > 0 &&
        item.actualPaymentAmount + 1 <= item.minimumPaymentEstimate) {
      return '推定最低支払額を下回る実支払（未払いの穴・不足分の補填要確認）';
    }
    if (item.differenceAmount < 0) {
      return '支払予定額より少ない実支払（引落不足・一部支払・予定額未更新の可能性）';
    }
    if (item.differenceAmount > 0) {
      return '支払予定額より多い実支払（繰上返済・手数料または延滞金加算の可能性）';
    }
    return '推定最低支払額と実支払額に差異あり（契約最低額との整合確認）';
  }

  static List<AssetPaymentDiscrepancyItem> _sortItems(
    List<AssetPaymentDiscrepancyItem> items,
  ) {
    items.sort((a, b) {
      final absDiff = b.effectiveDifferenceForInsight.abs().compareTo(
            a.effectiveDifferenceForInsight.abs(),
          );
      if (absDiff != 0) {
        return absDiff;
      }
      return a.accountName.compareTo(b.accountName);
    });
    return List<AssetPaymentDiscrepancyItem>.unmodifiable(items);
  }
}

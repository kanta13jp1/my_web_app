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
        ),
      );
    }

    items.sort((a, b) {
      final absDiff = b.differenceAmount.abs().compareTo(
            a.differenceAmount.abs(),
          );
      if (absDiff != 0) {
        return absDiff;
      }
      return a.accountName.compareTo(b.accountName);
    });
    return List<AssetPaymentDiscrepancyItem>.unmodifiable(items);
  }
}

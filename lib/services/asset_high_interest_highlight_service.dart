import '../models/asset_liability_workbook.dart';

enum AssetDebtRateTier { critical, high, normal }

enum AssetDebtSortMode { highInterestPriority, paymentDay }

/// 負債の年利・月利息に基づく「高金利止血」分類と優先ソート順を提供する純 Dart サービス。
class AssetHighInterestHighlightService {
  const AssetHighInterestHighlightService._();

  static const double criticalAnnualRateThreshold = 0.175;
  static const double highAnnualRateThreshold = 0.14;

  static AssetDebtRateTier classifyRateTier(double annualRate) {
    if (annualRate >= criticalAnnualRateThreshold) {
      return AssetDebtRateTier.critical;
    }
    if (annualRate >= highAnnualRateThreshold) {
      return AssetDebtRateTier.high;
    }
    return AssetDebtRateTier.normal;
  }

  static String? rateBadgeLabel(double annualRate) {
    final pct = '${(annualRate * 100).toStringAsFixed(1)}%';
    return switch (classifyRateTier(annualRate)) {
      AssetDebtRateTier.critical => '高金利 $pct',
      AssetDebtRateTier.high => '要注意 $pct',
      AssetDebtRateTier.normal => null,
    };
  }

  static String monthlyInterestTooltip(AssetLiabilityDebtRow row) {
    final ratePct = (row.annualRate * 100).toStringAsFixed(1);
    final sharePct = (row.liabilityShare * 100).toStringAsFixed(1);
    return '年利 $ratePct% / '
        '月利息の概算 ${_formatYen(row.monthlyInterestEstimate)} / '
        '負債割合 $sharePct%';
  }

  /// 年利降順 → 月利息概算降順 → 負債割合降順 → 残高絶対値降順 → 口座名昇順で並べる。
  static int compareByHighInterestPriority(
    AssetLiabilityDebtRow a,
    AssetLiabilityDebtRow b,
  ) {
    final rate = b.annualRate.compareTo(a.annualRate);
    if (rate != 0) {
      return rate;
    }
    final interest = b.monthlyInterestEstimate.compareTo(
      a.monthlyInterestEstimate,
    );
    if (interest != 0) {
      return interest;
    }
    final share = b.liabilityShare.compareTo(a.liabilityShare);
    if (share != 0) {
      return share;
    }
    final balance = b.balance.abs().compareTo(a.balance.abs());
    if (balance != 0) {
      return balance;
    }
    return a.name.compareTo(b.name);
  }

  /// 支払日リスク行に含まれる負債のうち、高金利警告帯に該当する最優先行を返す。
  static AssetLiabilityDebtRow? highestRateRowForPaymentRisk(
    AssetLiabilityPaymentDayRisk risk,
    List<AssetLiabilityDebtRow> debtRows,
  ) {
    final riskNames = risk.accountNames.map((n) => n.trim()).toSet();
    final matched = debtRows
        .where(
          (row) =>
              riskNames.contains(row.name.trim()) &&
              classifyRateTier(row.annualRate) != AssetDebtRateTier.normal,
        )
        .toList(growable: false);
    if (matched.isEmpty) {
      return null;
    }
    matched.sort(compareByHighInterestPriority);
    return matched.first;
  }

  static String _formatYen(double amount) {
    final rounded = amount.round();
    final sign = rounded < 0 ? '-' : '';
    final digits = rounded.abs().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$sign$digits円';
  }
}

import '../models/asset_liability_workbook.dart';
import '../models/user_profile.dart';

/// 過多アラートの内訳となる有効サブスクリプション 1 件。
class AssetSubscriptionExcessItem {
  final String id;
  final String name;
  final double monthlyAmount;
  final AssetSubscriptionReviewDecision reviewDecision;

  const AssetSubscriptionExcessItem({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    required this.reviewDecision,
  });
}

/// アクティブなサブスクリプションが件数・月額・年収比基準を超過した際のアラート。
class AssetSubscriptionExcessAlert {
  final List<AssetSubscriptionExcessItem> items;
  final int activeCount;
  final double monthlyTotal;
  final double annualTotal;
  final double? annualIncome;
  final double? incomeShareRatio;
  final List<String> triggers;
  final String summaryMessage;

  const AssetSubscriptionExcessAlert({
    required this.items,
    required this.activeCount,
    required this.monthlyTotal,
    required this.annualTotal,
    required this.annualIncome,
    required this.incomeShareRatio,
    required this.triggers,
    required this.summaryMessage,
  });
}

/// 登録済みサブスクリプションの過多判定と年額・年収負担の可視化を行う純ロジック。
class AssetSubscriptionExcessAlertService {
  const AssetSubscriptionExcessAlertService._();

  static const int defaultCountThreshold = 5;
  static const double defaultMonthlyTotalThreshold = 15000.0;
  static const double defaultAnnualIncomeRatioThreshold = 0.05;

  /// 有効なサブスクリプションのみを対象に過多判定を行い、基準超過時のみ返す。
  /// 金額が 0 円以下、または最終請求日を経過した解約済み項目は除外する。
  static AssetSubscriptionExcessAlert? evaluate({
    required AssetLiabilityWorkbook workbook,
    UserProfile? userProfile,
    int countThreshold = defaultCountThreshold,
    double monthlyTotalThreshold = defaultMonthlyTotalThreshold,
    double annualIncomeRatioThreshold = defaultAnnualIncomeRatioThreshold,
  }) {
    final baseDay = DateTime(
      workbook.baseDate.year,
      workbook.baseDate.month,
      workbook.baseDate.day,
    );
    final items = <AssetSubscriptionExcessItem>[];
    for (final cost in workbook.recurringFixedCosts) {
      if (cost.category != AssetRecurringFixedCostCategory.subscription) {
        continue;
      }
      if (cost.amount <= 0) {
        continue;
      }
      final last = cost.lastBillingDate;
      if (last != null) {
        final lastDay = DateTime(last.year, last.month, last.day);
        if (baseDay.isAfter(lastDay)) {
          continue;
        }
      }
      items.add(
        AssetSubscriptionExcessItem(
          id: cost.id,
          name: cost.name,
          monthlyAmount: cost.amount,
          reviewDecision: cost.subscriptionReviewDecision,
        ),
      );
    }
    if (items.isEmpty) {
      return null;
    }

    items.sort((left, right) {
      final amountCompare = right.monthlyAmount.compareTo(left.monthlyAmount);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return left.name.compareTo(right.name);
    });

    final activeCount = items.length;
    final monthlyTotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.monthlyAmount,
    );
    final annualTotal = monthlyTotal * 12.0;
    final rawIncome = userProfile?.annualIncome;
    final double? annualIncome =
        rawIncome != null && rawIncome > 0 ? rawIncome.toDouble() : null;
    final double? incomeShareRatio =
        annualIncome != null ? annualTotal / annualIncome : null;

    final triggers = <String>[
      if (activeCount >= countThreshold)
        '件数 $activeCount件（基準 $countThreshold件以上）',
      if (monthlyTotal >= monthlyTotalThreshold)
        '月額 ${_formatYen(monthlyTotal)}（基準 ${_formatYen(monthlyTotalThreshold)}以上）',
      if (incomeShareRatio != null &&
          incomeShareRatio >= annualIncomeRatioThreshold)
        '年収比 ${(incomeShareRatio * 100).toStringAsFixed(1)}%'
            '（基準 ${(annualIncomeRatioThreshold * 100).toStringAsFixed(1)}%以上）',
    ];
    if (triggers.isEmpty) {
      return null;
    }

    final ratioSuffix = incomeShareRatio == null
        ? ''
        : '（年収の ${(incomeShareRatio * 100).toStringAsFixed(1)}%）';
    final summaryMessage = '有効なサブスク $activeCount件で月額合計 '
        '${_formatYen(monthlyTotal)}・年額換算 ${_formatYen(annualTotal)}$ratioSuffix'
        'が発生しています。不要な契約の解約・見直しを検討してください。';

    return AssetSubscriptionExcessAlert(
      items: List<AssetSubscriptionExcessItem>.unmodifiable(items),
      activeCount: activeCount,
      monthlyTotal: monthlyTotal,
      annualTotal: annualTotal,
      annualIncome: annualIncome,
      incomeShareRatio: incomeShareRatio,
      triggers: List<String>.unmodifiable(triggers),
      summaryMessage: summaryMessage,
    );
  }

  static String _formatYen(double value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}¥$buffer';
  }
}

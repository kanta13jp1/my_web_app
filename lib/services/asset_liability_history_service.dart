import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';
import 'asset_liability_planning_service.dart';

class AssetLiabilityHistoryService {
  const AssetLiabilityHistoryService();

  AssetLiabilityMonthlySnapshot buildSnapshot({
    required String monthKey,
    required AssetLiabilityWorkbook workbook,
    required DateTime savedAt,
  }) {
    final paidPaymentTotal = workbook.debtMasterRows.fold<double>(
      0,
      (sum, row) => row.isDirectCashflowTarget && row.paid
          ? sum + row.effectivePaidPaymentAmount
          : sum,
    );
    final paymentDifferenceTotal = workbook.debtMasterRows.fold<double>(
      0,
      (sum, row) => row.isDirectCashflowTarget
          ? sum + (row.paymentDifferenceAmount ?? 0)
          : sum,
    );
    final overduePaymentCount = workbook.cashflowRows
        .where((row) => row.isPayment && row.overdue)
        .length;

    return AssetLiabilityMonthlySnapshot(
      monthKey: monthKey,
      savedAt: savedAt,
      positiveAssetTotal: workbook.positiveAssetTotal,
      liabilityTotal: workbook.liabilityTotal,
      netWorth: workbook.netWorth,
      cashLikeTotal: workbook.cashLikeTotal,
      monthlyScheduledPaymentTotal: workbook.monthlyScheduledPaymentTotal,
      monthlyPaidPaymentTotal: paidPaymentTotal,
      monthlyUnpaidPaymentTotal: workbook.monthlyUnpaidPaymentTotal,
      monthlyActualPaymentTotal: workbook.monthlyActualPaymentTotal,
      monthlyPaymentDifferenceTotal: paymentDifferenceTotal,
      overduePaymentCount: overduePaymentCount,
    );
  }

  List<AssetLiabilityMonthlySnapshotComparison> compareSnapshots(
    List<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    final comparisons = <AssetLiabilityMonthlySnapshotComparison>[];
    for (var index = 0; index < sorted.length; index++) {
      final current = sorted[index];
      final previous = index == 0 ? null : sorted[index - 1];
      comparisons.add(
        AssetLiabilityMonthlySnapshotComparison(
          snapshot: current,
          positiveAssetDelta: previous == null
              ? null
              : current.positiveAssetTotal - previous.positiveAssetTotal,
          liabilityDelta: previous == null
              ? null
              : current.liabilityTotal - previous.liabilityTotal,
          netWorthDelta:
              previous == null ? null : current.netWorth - previous.netWorth,
          cashLikeDelta: previous == null
              ? null
              : current.cashLikeTotal - previous.cashLikeTotal,
        ),
      );
    }
    return comparisons.reversed.toList(growable: false);
  }

  AssetLiabilityMonthlyChartData buildMonthlyChartData(
    List<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));

    return AssetLiabilityMonthlyChartData(
      monthKeys: [for (final snapshot in sorted) snapshot.monthKey],
      series: [
        _buildMonthlyChartSeries(
          sorted,
          AssetLiabilityMonthlyChartMetric.positiveAssetTotal,
          '資産合計',
          (snapshot) => snapshot.positiveAssetTotal,
        ),
        _buildMonthlyChartSeries(
          sorted,
          AssetLiabilityMonthlyChartMetric.liabilityTotal,
          '負債合計',
          (snapshot) => snapshot.liabilityTotal,
        ),
        _buildMonthlyChartSeries(
          sorted,
          AssetLiabilityMonthlyChartMetric.netWorth,
          '純資産',
          (snapshot) => snapshot.netWorth,
        ),
        _buildMonthlyChartSeries(
          sorted,
          AssetLiabilityMonthlyChartMetric.cashLikeTotal,
          '手元現金',
          (snapshot) => snapshot.cashLikeTotal,
        ),
      ],
    );
  }

  AssetLiabilityMonthlyChartSeries _buildMonthlyChartSeries(
    List<AssetLiabilityMonthlySnapshot> snapshots,
    AssetLiabilityMonthlyChartMetric metric,
    String label,
    double Function(AssetLiabilityMonthlySnapshot snapshot) valueOf,
  ) {
    final points = <AssetLiabilityMonthlyChartPoint>[];
    for (var index = 0; index < snapshots.length; index++) {
      final current = snapshots[index];
      final value = valueOf(current);
      final previousValue = index == 0 ? null : valueOf(snapshots[index - 1]);
      final delta = previousValue == null ? null : value - previousValue;
      points.add(
        AssetLiabilityMonthlyChartPoint(
          monthKey: current.monthKey,
          value: value,
          deltaFromPrevious: delta,
          worsened: delta != null && delta < 0,
        ),
      );
    }

    return AssetLiabilityMonthlyChartSeries(
      metric: metric,
      label: label,
      points: points,
    );
  }

  AssetLiabilityCsvExportBundle buildCsvExportBundle({
    required List<AssetLiabilityMonthlySnapshot> monthlySnapshots,
    required AssetLiabilityWorkbook workbook,
  }) {
    return AssetLiabilityCsvExportBundle(
      monthlyHistoryCsv: buildMonthlyHistoryCsv(monthlySnapshots),
      paymentScheduleCsv: buildPaymentScheduleCsv(workbook),
      incomePlansCsv: buildIncomePlansCsv(workbook),
      accountCashflowCsv: buildAccountCashflowCsv(workbook),
    );
  }

  String buildMonthlyHistoryCsv(List<AssetLiabilityMonthlySnapshot> snapshots) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return _csv([
      const <Object?>[
        '対象月',
        '保存日時',
        '資産合計',
        '負債合計',
        '純資産',
        '手元現金',
        '今月支払予定総額',
        '実支払済み総額',
        '未払い総額',
        '期限超過件数',
        'actual_paid_payment_total',
        'payment_difference_total',
      ],
      for (final snapshot in sorted)
        <Object?>[
          snapshot.monthKey,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.savedAt),
          snapshot.positiveAssetTotal,
          snapshot.liabilityTotal,
          snapshot.netWorth,
          snapshot.cashLikeTotal,
          snapshot.monthlyScheduledPaymentTotal,
          snapshot.monthlyPaidPaymentTotal,
          snapshot.monthlyUnpaidPaymentTotal,
          snapshot.overduePaymentCount,
          snapshot.monthlyActualPaymentTotal,
          snapshot.monthlyPaymentDifferenceTotal,
        ],
    ]);
  }

  String buildPaymentScheduleCsv(AssetLiabilityWorkbook workbook) {
    final rows = workbook.cashflowRows.where((row) => row.isPayment).toList();
    final reviewItemsById = <String, AssetLiabilityCardBillingReviewItem>{
      for (final item in workbook.cardBillingReview.directPaymentItems)
        item.accountId: item,
      for (final group in workbook.cardBillingReview.cardBillingGroups)
        for (final item in group.items) item.accountId: item,
    };
    return _csv([
      const <Object?>[
        'レビュー区分',
        '確認事項',
        '二重計上対象外',
        '\u8a2d\u5b9a\u5143',
        '請求先カード',
        '日付',
        '支払先',
        '支払原資口座',
        '支払い方法',
        '資金繰り上の扱い',
        '直接差し引き対象',
        '支払予定額',
        '実額/推定',
        '支払済み',
        '期限超過',
        '支払後手元資金',
        'actual_payment_amount',
        'payment_difference_amount',
        'payment_difference_reason',
      ],
      for (final row in rows)
        <Object?>[
          _paymentReviewCategoryLabel(reviewItemsById[row.accountId]),
          _paymentReviewAlertLabel(reviewItemsById[row.accountId]),
          row.includedInBillingAccount
              ? AssetLiabilityPlanningService
                  .cardBillingReviewExcludedFromDirectCashflowLabel
              : AssetLiabilityPlanningService
                  .cardBillingReviewDirectCashflowTargetLabel,
          AssetLiabilityPlanningService.paymentMethodSettingSourceLabel(
            row.paymentMethodSettingSource,
          ),
          row.billingAccountName ?? row.billingAccountId ?? '',
          DateFormat('yyyy-MM-dd').format(row.paymentDate),
          row.accountName,
          row.paymentSourceAccountName ?? '未設定',
          row.paymentMethodLabel ?? '',
          row.includedInBillingAccount
              ? AssetLiabilityPlanningService.cardBillingIncludedLabel
              : '直接差し引き',
          row.isDirectCashflowTarget ? '対象' : '対象外',
          row.paymentAmount,
          row.paymentAmountEstimated ? '推定' : '実額',
          row.includedInBillingAccount
              ? AssetLiabilityPlanningService.cardBillingIncludedLabel
              : (row.paid ? '済' : '未済'),
          row.overdue ? '期限超過' : '',
          row.cashAfterPayment,
          row.actualPaymentAmount ?? '',
          row.paymentDifferenceAmount ?? '',
          row.paymentDifferenceReason ?? '',
        ],
    ]);
  }

  String _paymentReviewCategoryLabel(
    AssetLiabilityCardBillingReviewItem? item,
  ) {
    if (item == null) {
      return '';
    }
    return item.includedInBillingAccount
        ? AssetLiabilityPlanningService.cardBillingReviewIncludedLabel
        : AssetLiabilityPlanningService.cardBillingReviewDirectLabel;
  }

  String _paymentReviewAlertLabel(AssetLiabilityCardBillingReviewItem? item) {
    if (item == null) {
      return '';
    }
    return item.alerts.isEmpty ? '問題なし' : item.alerts.join(' / ');
  }

  String buildIncomePlansCsv(AssetLiabilityWorkbook workbook) {
    return _csv([
      const <Object?>['日付', '名称', '金額', '入金先口座', '入金済み'],
      for (final plan in workbook.incomePlans)
        <Object?>[
          DateFormat('yyyy-MM-dd').format(plan.date),
          plan.name,
          plan.amount,
          plan.destinationAccountName ?? '未設定',
          plan.received ? '済' : '未済',
        ],
    ]);
  }

  String buildAccountCashflowCsv(AssetLiabilityWorkbook workbook) {
    return _csv([
      const <Object?>['口座', '現在残高', '今後の支払い', '今後の入金', '支払後残高', '判定'],
      for (final summary in workbook.accountCashflowSummaries)
        <Object?>[
          summary.accountName,
          summary.currentBalance,
          summary.upcomingPayments,
          summary.upcomingIncome,
          summary.projectedBalance,
          _cashRiskLabel(summary.riskLevel),
        ],
    ]);
  }

  String _csv(List<List<Object?>> rows) {
    return rows
        .map((row) => row.map((cell) => _escapeCsvCell(cell)).join(','))
        .join('\n');
  }

  String _escapeCsvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _cashRiskLabel(AssetLiabilityCashRiskLevel riskLevel) {
    switch (riskLevel) {
      case AssetLiabilityCashRiskLevel.short:
        return '資金ショート';
      case AssetLiabilityCashRiskLevel.caution:
        return '要注意';
      case AssetLiabilityCashRiskLevel.watch:
        return '警戒';
      case AssetLiabilityCashRiskLevel.normal:
        return '通常';
    }
  }
}

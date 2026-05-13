import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';

class AssetLiabilityHistoryService {
  const AssetLiabilityHistoryService();

  AssetLiabilityMonthlySnapshot buildSnapshot({
    required String monthKey,
    required AssetLiabilityWorkbook workbook,
    required DateTime savedAt,
  }) {
    final paidPaymentTotal = workbook.debtMasterRows.fold<double>(
      0,
      (sum, row) => row.paid ? sum + row.scheduledPaymentAmount : sum,
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

  String buildMonthlyHistoryCsv(
    List<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return _csv(
      [
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
          ],
      ],
    );
  }

  String buildPaymentScheduleCsv(AssetLiabilityWorkbook workbook) {
    final rows = workbook.cashflowRows.where((row) => row.isPayment).toList();
    return _csv(
      [
        const <Object?>[
          '日付',
          '支払先',
          '支払原資口座',
          '支払予定額',
          '実額/推定',
          '支払済み',
          '期限超過',
          '支払後手元資金',
        ],
        for (final row in rows)
          <Object?>[
            DateFormat('yyyy-MM-dd').format(row.paymentDate),
            row.accountName,
            row.paymentSourceAccountName ?? '未設定',
            row.paymentAmount,
            row.paymentAmountEstimated ? '推定' : '実額',
            row.paid ? '済' : '未済',
            row.overdue ? '期限超過' : '',
            row.cashAfterPayment,
          ],
      ],
    );
  }

  String buildIncomePlansCsv(AssetLiabilityWorkbook workbook) {
    return _csv(
      [
        const <Object?>[
          '日付',
          '名称',
          '金額',
          '入金先口座',
          '入金済み',
        ],
        for (final plan in workbook.incomePlans)
          <Object?>[
            DateFormat('yyyy-MM-dd').format(plan.date),
            plan.name,
            plan.amount,
            plan.destinationAccountName ?? '未設定',
            plan.received ? '済' : '未済',
          ],
      ],
    );
  }

  String buildAccountCashflowCsv(AssetLiabilityWorkbook workbook) {
    return _csv(
      [
        const <Object?>[
          '口座',
          '現在残高',
          '今後の支払い',
          '今後の入金',
          '支払後残高',
          '判定',
        ],
        for (final summary in workbook.accountCashflowSummaries)
          <Object?>[
            summary.accountName,
            summary.currentBalance,
            summary.upcomingPayments,
            summary.upcomingIncome,
            summary.projectedBalance,
            _cashRiskLabel(summary.riskLevel),
          ],
      ],
    );
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

import '../models/asset_liability_workbook.dart';

/// 期限超過かつ未払いの直接支払対象項目。
class AssetOverdueUnpaidItem {
  final AssetLiabilityDebtRow debtRow;
  final DateTime paymentDate;
  final double paymentAmount;
  final int overdueDays;

  const AssetOverdueUnpaidItem({
    required this.debtRow,
    required this.paymentDate,
    required this.paymentAmount,
    required this.overdueDays,
  });
}

/// 期限超過の未払い項目を一括確認・支払済み反映向けに抽出・集計する純ロジック。
class AssetOverdueBulkConfirmService {
  const AssetOverdueBulkConfirmService._();

  /// [workbook] から期限超過・未払いの直接支払対象のみを抽出し、
  /// 支払日昇順・金額降順・ID 昇順で返す（1 負債につき 1 件へ重複排除）。
  static List<AssetOverdueUnpaidItem> collectOverdueUnpaidItems(
    AssetLiabilityWorkbook workbook,
  ) {
    final debtById = <String, AssetLiabilityDebtRow>{
      for (final row in workbook.debtMasterRows) row.id: row,
    };
    final baseDay = DateTime(
      workbook.baseDate.year,
      workbook.baseDate.month,
      workbook.baseDate.day,
    );
    final seenIds = <String>{};
    final items = <AssetOverdueUnpaidItem>[];

    for (final cashflow in workbook.cashflowRows) {
      if (!cashflow.isPayment ||
          !cashflow.overdue ||
          cashflow.paid ||
          cashflow.includedInBillingAccount ||
          !cashflow.isDirectCashflowTarget) {
        continue;
      }
      final debtRow = debtById[cashflow.accountId];
      if (debtRow == null ||
          debtRow.paid ||
          debtRow.includedInBillingAccount ||
          !seenIds.add(debtRow.id)) {
        continue;
      }
      final paymentDay = DateTime(
        cashflow.paymentDate.year,
        cashflow.paymentDate.month,
        cashflow.paymentDate.day,
      );
      final overdueDays = baseDay.difference(paymentDay).inDays.clamp(0, 99999);
      items.add(
        AssetOverdueUnpaidItem(
          debtRow: debtRow,
          paymentDate: cashflow.paymentDate,
          paymentAmount: cashflow.paymentAmount,
          overdueDays: overdueDays,
        ),
      );
    }

    items.sort((left, right) {
      final dateCompare = left.paymentDate.compareTo(right.paymentDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final amountCompare = right.paymentAmount.compareTo(left.paymentAmount);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return left.debtRow.id.compareTo(right.debtRow.id);
    });
    return items;
  }

  /// 選択中 [selectedIds] に含まれる項目の支払予定額合計を返す。
  static double totalSelectedAmount(
    Iterable<AssetOverdueUnpaidItem> items,
    Set<String> selectedIds,
  ) {
    var total = 0.0;
    for (final item in items) {
      if (selectedIds.contains(item.debtRow.id)) {
        total += item.paymentAmount;
      }
    }
    return total;
  }
}

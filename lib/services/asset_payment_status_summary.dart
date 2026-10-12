import '../models/asset_liability_workbook.dart';

/// Disjoint groups derived from the same direct, unpaid cashflow rows.
Map<String, List<AssetLiabilityCashflowRow>> assetPaymentStatusGroups(
  AssetLiabilityWorkbook workbook,
) {
  final today = DateTime(
    workbook.baseDate.year,
    workbook.baseDate.month,
    workbook.baseDate.day,
  );
  final groups = <String, List<AssetLiabilityCashflowRow>>{
    '期限超過': [],
    '本日期日': [],
    '今後の支払い': [],
  };
  for (final row in workbook.cashflowRows) {
    if (!row.isPayment || !row.isDirectCashflowTarget || row.paid ||
        row.paymentAmount <= 0) {
      continue;
    }
    final date = DateTime(
      row.paymentDate.year,
      row.paymentDate.month,
      row.paymentDate.day,
    );
    final label = date.isBefore(today)
        ? '期限超過'
        : date == today ? '本日期日' : '今後の支払い';
    groups[label]!.add(row);
  }
  return groups;
}

String assetPaymentStatusPrompt(AssetLiabilityWorkbook workbook) {
  final buffer = StringBuffer()
    ..writeln('## 支払い状態別の確定内訳')
    ..writeln('期限超過は基準日の前日以前だけです。本日期日は期限超過に含めません。'
        '各区分の件数・合計・項目は同じ行から計算済みです。区分を混ぜず、そのまま引用してください。'
        'カード請求内訳・支払済み・収入・0円項目は対象外です。');
  for (final entry in assetPaymentStatusGroups(workbook).entries) {
    final total = entry.value.fold<double>(0, (sum, row) => sum + row.paymentAmount);
    buffer.writeln('- ${entry.key}: ${entry.value.length}件 / 合計 ${total.round()}円');
    for (final row in entry.value) {
      final date = row.paymentDate;
      buffer.writeln('  - ${row.accountName}: ${row.paymentAmount.round()}円 / '
          '${date.year}/${date.month}/${date.day}');
    }
  }
  return buffer.toString();
}

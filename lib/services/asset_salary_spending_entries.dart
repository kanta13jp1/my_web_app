import '../models/asset_liability_workbook.dart';
import 'salary_spending_breakdown_service.dart';

/// 資産管理ページのフロー(カード明細・収支履歴・収入計画・給与明細)から
/// [SalarySpendingBreakdownService] へ渡す [SalarySpendingEntry] /
/// [SalaryIncomeEntry] を組み立てる純関数の置き場。
///
/// 元々ページの `_buildSalarySpendingBreakdown` 内にインライン化されていた集計
/// ロジックを抽出し、build から切り離してユニットテスト可能にしたもの(振る舞いは
/// 不変)。表示タイトルの導出だけはページ依存(`_flowDisplayTitle` → 説明パース)の
/// ため、関数として注入する。
class AssetSalarySpendingEntries {
  const AssetSalarySpendingEntries({
    required this.expenses,
    required this.incomes,
  });

  final List<SalarySpendingEntry> expenses;
  final List<SalaryIncomeEntry> incomes;

  /// 各種フローから支出/収入エントリを組み立てる。
  ///
  /// - カード明細 = すべて支出。billing 名/ID を「カード明細マーカー」に記録。
  /// - 収支履歴(recentFlows)= 振替は除外。支出はカード明細マーカーに含まれる
  ///   説明なら二重計上回避で除外。収入(conquer)は収入へ。
  /// - 受取済み収入計画・給与明細 = 同日同額の重複を排除して収入へ。
  ///   未受取の計画は予測専用で、実績には含めない。
  static AssetSalarySpendingEntries build({
    required List<AssetLiabilityCardStatementLine> cardStatementLines,
    required List<Map<String, dynamic>> recentFlows,
    required List<AssetLiabilityIncomePlan> monthlyIncomePlans,
    required List<Map<String, dynamic>> payslipSalaryIncomes,
    required List<Map<String, dynamic>> payslipRows,
    required String Function(Map<String, dynamic> flow) flowDisplayTitle,
  }) {
    final expenses = <SalarySpendingEntry>[];
    final incomes = <SalaryIncomeEntry>[];
    final cardBillingMarkers = <String>{};

    bool hasIncomeEntry(DateTime date, double amount) {
      final rowKey = '${_dateKey(date)}:${amount.round()}';
      return incomes.any(
        (entry) => '${_dateKey(entry.date)}:${entry.amount.round()}' == rowKey,
      );
    }

    void addIncomeEntry({
      required DateTime date,
      required double amount,
      required String description,
    }) {
      if (amount <= 0 || hasIncomeEntry(date, amount)) {
        return;
      }
      incomes.add(
        SalaryIncomeEntry(
          date: date,
          amount: amount,
          description: description.trim().isEmpty ? '収入' : description.trim(),
        ),
      );
    }

    for (final line in cardStatementLines) {
      final postedAt = line.postedAt;
      if (postedAt == null) {
        continue;
      }
      final billingName = line.billingAccountName?.trim();
      if (billingName != null && billingName.isNotEmpty) {
        cardBillingMarkers.add(billingName.toLowerCase());
      }
      cardBillingMarkers.add(line.billingAccountId.toLowerCase());
      final billingLabel = billingName != null && billingName.isNotEmpty
          ? billingName
          : line.billingAccountId;
      expenses.add(
        SalarySpendingEntry(
          date: postedAt,
          amount: line.amount,
          description: line.description,
          sourceLabel: billingLabel,
        ),
      );
    }

    for (final flow in recentFlows) {
      final actionType = flow['action_type']?.toString() ?? '';
      if (actionType == 'transfer') {
        continue;
      }
      final occurredAt = DateTime.tryParse(
        flow['occurred_at']?.toString() ?? '',
      )?.toLocal();
      final amount = (flow['amount'] as num?)?.toDouble() ?? 0;
      if (occurredAt == null || amount <= 0) {
        continue;
      }
      final description = flow['description']?.toString() ?? '';
      final displayTitle = flowDisplayTitle(flow);
      if (actionType == 'expense') {
        final lowerDescription = description.toLowerCase();
        final representedByCardDetail = cardBillingMarkers.any(
          (marker) => marker.isNotEmpty && lowerDescription.contains(marker),
        );
        if (representedByCardDetail) {
          continue;
        }
        expenses.add(
          SalarySpendingEntry(
            date: occurredAt,
            amount: amount,
            description: displayTitle.isEmpty ? description : displayTitle,
            sourceLabel: _flowLabel(actionType),
          ),
        );
      } else if (actionType == 'conquer') {
        incomes.add(
          SalaryIncomeEntry(
            date: occurredAt,
            amount: amount,
            description: displayTitle.isEmpty ? description : displayTitle,
          ),
        );
      }
    }

    for (final plan in monthlyIncomePlans) {
      if (!plan.received) {
        continue;
      }
      addIncomeEntry(
        date: plan.date,
        amount: plan.amount,
        description: plan.name,
      );
    }

    for (final row in payslipSalaryIncomes) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final amount = _num(row['amount']);
      if (payDate == null || amount <= 0) {
        continue;
      }
      final description = row['description']?.toString().trim() ?? '';
      addIncomeEntry(
        date: payDate,
        amount: amount,
        description: description.isEmpty ? '給与明細' : '給与明細: $description',
      );
    }

    for (final row in payslipRows) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final amount = _num(row['net_amount']);
      if (payDate == null || amount <= 0) {
        continue;
      }
      final companyName = row['company_name']?.toString().trim() ?? '';
      addIncomeEntry(
        date: payDate,
        amount: amount,
        description: companyName.isEmpty ? '給与明細' : '給与明細: $companyName',
      );
    }

    return AssetSalarySpendingEntries(expenses: expenses, incomes: incomes);
  }

  /// action_type のラベル(支出の sourceLabel 用)。
  static String _flowLabel(String actionType) {
    switch (actionType) {
      case 'conquer':
        return '収入';
      case 'transfer':
        return '振替';
      default:
        return '支出';
    }
  }

  /// 文字列/数値混在の金額を double へ寛容に変換する。
  static double _num(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return 0;
    }
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  /// 同日同額の収入重複排除に使う日付キー(yyyy-MM-dd)。
  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// 家計簿 予算 / 支出 / 収入エントリモデル。
///
/// `social-commerce-hub`:
/// - `budget.summary` → `{success, budgets: [hub_data 行]}`
///   実フィールド `metadata.category` / `metadata.amount` / `metadata.period`。
/// - `budget.expense_list` → `{success, expenses: [hub_data 行]}`
///   実フィールド `metadata.category` / `metadata.amount` / `metadata.date`。
/// - `budget.income_list` → `{success, income: [hub_data 行]}` (キーは単数 `income`)
///   実フィールド `metadata.source` / `metadata.amount` / `metadata.date`。
///
/// 旧実装のバグ:
/// - 収入取得に無効 action `'get'` を使い EF 400 → 支出常に空。
/// - 収入を `budget.expense_list` で取得し応答キー `incomes` を読む
///   (正: action=`budget.income_list` / キー=`income`)。
/// - category / amount を flat `e['category']`/`e['amount']` で読み全行 null →
///   カテゴリ照合不能で予算・実績が常に 0。
library;

import 'hub_data_parsing.dart';

class BudgetEntry {
  const BudgetEntry({
    required this.category,
    required this.amount,
    required this.label,
  });

  /// 予算・支出の分類キー (収入は source を category として扱う)。
  final String category;
  final num amount;

  /// 収入 source 等の表示ラベル (category と別に保持)。
  final String label;

  factory BudgetEntry.fromMap(Map<String, dynamic> raw) {
    final category = hubString(hubField(raw, 'category'));
    final source = hubString(hubField(raw, 'source'));
    return BudgetEntry(
      category: category.isNotEmpty ? category : source,
      amount: hubNum(hubField(raw, 'amount')),
      label: hubString(hubField(raw, 'description')),
    );
  }

  static List<BudgetEntry> listFromResponse(dynamic data, String listKey) =>
      hubRowsFromResponse(data, listKey).map(BudgetEntry.fromMap).toList();

  /// カテゴリ別 amount 合計。
  static num sumForCategory(List<BudgetEntry> entries, String category) =>
      entries
          .where((e) => e.category == category)
          .fold<num>(0, (sum, e) => sum + e.amount);

  /// 全 amount 合計。
  static num total(List<BudgetEntry> entries) =>
      entries.fold<num>(0, (sum, e) => sum + e.amount);
}

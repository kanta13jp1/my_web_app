/// カテゴリ別の予算と実支出を突き合わせた1行(予実)。
class CategoryBudgetRow {
  const CategoryBudgetRow({
    required this.category,
    required this.budget,
    required this.actual,
  });

  final String category;

  /// 月次予算。0 なら未設定。
  final double budget;

  /// 当該期間の実支出。
  final double actual;

  /// 残り予算(予算 − 実績)。予算未設定なら負になりうる(= 実績のぶん)。
  double get remaining => budget - actual;

  /// 消化率(実績 / 予算)。予算未設定(0)なら null。
  double? get ratio => budget > 0 ? actual / budget : null;

  /// 予算超過(予算設定あり かつ 実績 > 予算)。
  bool get isOver => budget > 0 && actual > budget;

  bool get hasBudget => budget > 0;
}

/// 予算/カテゴリ予実レポート(給料サイクル等の1期間ぶん)。
class CategoryBudgetReport {
  const CategoryBudgetReport({
    required this.rows,
    required this.totalBudget,
    required this.totalActual,
  });

  final List<CategoryBudgetRow> rows;
  final double totalBudget;
  final double totalActual;

  /// 全体の残り予算。
  double get totalRemaining => totalBudget - totalActual;

  bool get isEmpty => rows.isEmpty;

  /// いずれかのカテゴリに予算が設定されているか。
  bool get hasAnyBudget => totalBudget > 0;

  /// 予算超過しているカテゴリ数。
  int get overCount {
    var count = 0;
    for (final row in rows) {
      if (row.isOver) {
        count += 1;
      }
    }
    return count;
  }
}

/// カテゴリ別の月次予算(ユーザー設定)と実支出([actualByCategory])を
/// 突き合わせて予実レポートを作る純関数サービス。
///
/// 実支出は `SalarySpendingBreakdownService` が算出した
/// カテゴリ別内訳(`sections`)をそのまま渡す想定。スキーマ非依存・完全テスト可。
class AssetCategoryBudgetService {
  const AssetCategoryBudgetService();

  static CategoryBudgetReport build({
    required Map<String, double> actualByCategory,
    required Map<String, double> budgets,
  }) {
    final categories = <String>{
      for (final entry in budgets.entries)
        if (entry.value > 0) entry.key,
      for (final entry in actualByCategory.entries)
        if (entry.value > 0) entry.key,
    };

    final rows = <CategoryBudgetRow>[
      for (final category in categories)
        CategoryBudgetRow(
          category: category,
          budget: _nonNegative(budgets[category]),
          actual: _nonNegative(actualByCategory[category]),
        ),
    ]..sort((a, b) {
        // 予算超過を先頭へ、その中・以降は実績の多い順。
        if (a.isOver != b.isOver) {
          return a.isOver ? -1 : 1;
        }
        return b.actual.compareTo(a.actual);
      });

    var totalBudget = 0.0;
    var totalActual = 0.0;
    for (final row in rows) {
      totalBudget += row.budget;
      totalActual += row.actual;
    }

    return CategoryBudgetReport(
      rows: rows,
      totalBudget: totalBudget,
      totalActual: totalActual,
    );
  }

  static double _nonNegative(double? value) {
    if (value == null || value < 0) {
      return 0;
    }
    return value;
  }
}

/// A receipt of borrowed money is financing, not earned income or spending.
enum AssetFlowKind {
  income,
  expense,
  transfer,
  borrowing,
  other;

  static AssetFlowKind fromActionType(String value) => switch (value) {
        'conquer' => income,
        'expense' => expense,
        'transfer' => transfer,
        'borrowing' => borrowing,
        _ => other,
      };

  bool get countsAsIncome => this == income;
  bool get countsAsExpense => this == expense;

  String get label => switch (this) {
        income => '収入',
        expense => '支出',
        transfer => '振替',
        borrowing => '借入受取',
        other => 'その他の記録',
      };

  String get amountPrefix => switch (this) {
        income || borrowing => '+',
        expense => '-',
        transfer => '↔',
        other => '',
      };
}

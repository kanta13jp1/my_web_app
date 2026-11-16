class HomeDailyCashflowSummary {
  final int incomeTotal;
  final int expenseTotal;
  final int transferTotal;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;

  const HomeDailyCashflowSummary({
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.transferTotal = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
    this.transferCount = 0,
  });

  HomeDailyCashflowSummary copyWith({
    int? incomeTotal,
    int? expenseTotal,
    int? transferTotal,
    int? incomeCount,
    int? expenseCount,
    int? transferCount,
  }) {
    return HomeDailyCashflowSummary(
      incomeTotal: incomeTotal ?? this.incomeTotal,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      incomeCount: incomeCount ?? this.incomeCount,
      expenseCount: expenseCount ?? this.expenseCount,
      transferCount: transferCount ?? this.transferCount,
    );
  }

  int get recordCount => incomeCount + expenseCount;

  int get netTotal => incomeTotal - expenseTotal;

  bool get hasCashflow => recordCount > 0;

  bool get hasAnyEntry => hasCashflow || transferCount > 0;
}

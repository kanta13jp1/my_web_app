class HomeDailyCashflowSummary {
  final int incomeTotal;
  final int expenseTotal;
  final int transferTotal;
  final int borrowingTotal;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;
  final int borrowingCount;

  const HomeDailyCashflowSummary({
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.transferTotal = 0,
    this.borrowingTotal = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
    this.transferCount = 0,
    this.borrowingCount = 0,
  });

  HomeDailyCashflowSummary copyWith({
    int? incomeTotal,
    int? expenseTotal,
    int? transferTotal,
    int? borrowingTotal,
    int? incomeCount,
    int? expenseCount,
    int? transferCount,
    int? borrowingCount,
  }) {
    return HomeDailyCashflowSummary(
      incomeTotal: incomeTotal ?? this.incomeTotal,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      borrowingTotal: borrowingTotal ?? this.borrowingTotal,
      incomeCount: incomeCount ?? this.incomeCount,
      expenseCount: expenseCount ?? this.expenseCount,
      transferCount: transferCount ?? this.transferCount,
      borrowingCount: borrowingCount ?? this.borrowingCount,
    );
  }

  int get recordCount => incomeCount + expenseCount;

  int get netTotal => incomeTotal - expenseTotal;

  bool get hasCashflow => recordCount > 0;

  bool get hasBorrowing => borrowingCount > 0;

  bool get hasAnyEntry =>
      hasCashflow || transferCount > 0 || borrowingCount > 0;
}

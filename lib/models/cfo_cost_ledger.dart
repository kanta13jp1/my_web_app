enum CfoCostType {
  fixed,
  variable;

  String get databaseValue => switch (this) {
        CfoCostType.fixed => 'fixed',
        CfoCostType.variable => 'variable',
      };

  String get label => switch (this) {
        CfoCostType.fixed => '固定費',
        CfoCostType.variable => '変動費',
      };

  static CfoCostType fromValue(Object? value) {
    return switch (value?.toString()) {
      'fixed' => CfoCostType.fixed,
      _ => CfoCostType.variable,
    };
  }
}

class CfoCostEntry {
  const CfoCostEntry({
    required this.id,
    required this.item,
    required this.category,
    required this.amountJpy,
    required this.incurredOn,
    required this.costType,
    required this.note,
    this.createdAt,
  });

  final String id;
  final String item;
  final String category;
  final int amountJpy;
  final DateTime incurredOn;
  final CfoCostType costType;
  final String note;
  final DateTime? createdAt;

  factory CfoCostEntry.fromMap(Map<String, dynamic> map) {
    return CfoCostEntry(
      id: map['id']?.toString() ?? '',
      item: map['item']?.toString() ?? '',
      category: map['category']?.toString() ?? 'other',
      amountJpy: (map['amount_jpy'] as num?)?.round() ?? 0,
      incurredOn: DateTime.tryParse(map['incurred_on']?.toString() ?? '') ??
          DateTime.now(),
      costType: CfoCostType.fromValue(map['cost_type']),
      note: map['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

class CfoCostEntryDraft {
  const CfoCostEntryDraft({
    required this.item,
    required this.category,
    required this.amountJpy,
    required this.incurredOn,
    required this.costType,
    required this.note,
  });

  final String item;
  final String category;
  final int amountJpy;
  final DateTime incurredOn;
  final CfoCostType costType;
  final String note;

  Map<String, dynamic> toInsertMap(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'item': item,
      'category': category,
      'amount_jpy': amountJpy,
      'incurred_on': _dateOnly(incurredOn),
      'cost_type': costType.databaseValue,
      'note': note,
    };
  }
}

class CfoMonthlyBudget {
  const CfoMonthlyBudget({required this.month, required this.budgetJpy});

  final String month;
  final int budgetJpy;

  factory CfoMonthlyBudget.fromMap(Map<String, dynamic> map) {
    return CfoMonthlyBudget(
      month: map['month']?.toString() ?? '',
      budgetJpy: (map['budget_jpy'] as num?)?.round() ?? 0,
    );
  }
}

class CfoMonthlyCostSummary {
  const CfoMonthlyCostSummary({
    required this.month,
    required this.budgetJpy,
    required this.fixedCostJpy,
    required this.variableCostJpy,
    required this.categoryTotals,
    required this.entries,
  });

  final String month;
  final int budgetJpy;
  final int fixedCostJpy;
  final int variableCostJpy;
  final Map<String, int> categoryTotals;
  final List<CfoCostEntry> entries;

  int get totalCostJpy => fixedCostJpy + variableCostJpy;

  int get budgetRemainingJpy => budgetJpy - totalCostJpy;

  double get budgetUsageRatio {
    if (budgetJpy <= 0) {
      return 0;
    }
    return totalCostJpy / budgetJpy;
  }

  bool get isOverBudget => budgetJpy > 0 && totalCostJpy > budgetJpy;

  bool get hasBudget => budgetJpy > 0;
}

String cfoLedgerMonth(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

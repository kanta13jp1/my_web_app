import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cfo_cost_ledger.dart';

class CfoCostLedgerSnapshot {
  const CfoCostLedgerSnapshot({required this.summary, required this.budget});

  final CfoMonthlyCostSummary summary;
  final CfoMonthlyBudget? budget;
}

class CfoCostLedgerService {
  CfoCostLedgerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<CfoCostLedgerSnapshot> loadMonth({String? month}) async {
    final selectedMonth = month ?? cfoLedgerMonth(DateTime.now());
    final entries = await loadEntries(month: selectedMonth);
    final budget = await loadBudget(month: selectedMonth);
    return CfoCostLedgerSnapshot(
      summary: summarize(
        entries: entries,
        month: selectedMonth,
        budgetJpy: budget?.budgetJpy ?? 0,
      ),
      budget: budget,
    );
  }

  Future<List<CfoCostEntry>> loadEntries({required String month}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return <CfoCostEntry>[];
    }
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 0);
    final data = await _client
        .from('cfo_cost_entries')
        .select()
        .eq('user_id', userId)
        .gte('incurred_on', _dateOnly(start))
        .lte('incurred_on', _dateOnly(end))
        .order('incurred_on', ascending: false)
        .order('created_at', ascending: false);

    return (data as List)
        .whereType<Map>()
        .map((row) => CfoCostEntry.fromMap(row.cast<String, dynamic>()))
        .toList();
  }

  Future<CfoMonthlyBudget?> loadBudget({required String month}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    final data = await _client
        .from('cfo_monthly_budgets')
        .select()
        .eq('user_id', userId)
        .eq('month', month)
        .maybeSingle();
    if (data == null) {
      return null;
    }
    return CfoMonthlyBudget.fromMap(data);
  }

  Future<void> addEntry(CfoCostEntryDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('ログインが必要です');
    }
    await _client.from('cfo_cost_entries').insert(draft.toInsertMap(userId));
  }

  Future<void> setMonthlyBudget({
    required String month,
    required int budgetJpy,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('ログインが必要です');
    }
    await _client.from('cfo_monthly_budgets').upsert(
      <String, dynamic>{
        'user_id': userId,
        'month': month,
        'budget_jpy': budgetJpy,
      },
      onConflict: 'user_id,month',
    );
  }

  static CfoMonthlyCostSummary summarize({
    required List<CfoCostEntry> entries,
    required String month,
    required int budgetJpy,
  }) {
    var fixedCost = 0;
    var variableCost = 0;
    final categoryTotals = <String, int>{};

    for (final entry in entries) {
      switch (entry.costType) {
        case CfoCostType.fixed:
          fixedCost += entry.amountJpy;
        case CfoCostType.variable:
          variableCost += entry.amountJpy;
      }
      categoryTotals.update(
        entry.category,
        (value) => value + entry.amountJpy,
        ifAbsent: () => entry.amountJpy,
      );
    }

    final sortedCategoryTotals = Map<String, int>.fromEntries(
      categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return CfoMonthlyCostSummary(
      month: month,
      budgetJpy: budgetJpy,
      fixedCostJpy: fixedCost,
      variableCostJpy: variableCost,
      categoryTotals: sortedCategoryTotals,
      entries: entries,
    );
  }
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

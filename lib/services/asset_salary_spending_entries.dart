import '../models/asset_income_source_evidence.dart';
import 'asset_liability_monthly_state_store.dart';
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

    void addIncomeEntry({
      required DateTime date,
      required double amount,
      required String description,
    }) {
      if (amount <= 0) {
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

  /// Source identity is never inferred from date, amount, or company name.
  static IncomeEvidenceProjection projectCycle({
    required String ownerId,
    required String? flowOwnerId,
    required String? financeOwnerId,
    required DateTime reference,
    required int salaryDay,
    required List<Map<String, dynamic>> recentFlows,
    required List<AssetLiabilityIncomePlan> monthlyIncomePlans,
    required List<Map<String, dynamic>> payslipSalaryIncomes,
    required List<Map<String, dynamic>> payslipRows,
    List<Map<String, dynamic>> referencedPayslips = const [],
    List<IncomeRelationshipDecision> decisions = const [],
    int relationshipPage = 0,
  }) {
    final start = AssetLiabilityMonthlyStateStore.salaryCycleStart(
      reference,
      salaryDay: salaryDay,
    );
    final end = AssetLiabilityMonthlyStateStore.salaryCycleEndExclusive(
      reference,
      salaryDay: salaryDay,
    );
    bool belongs(String raw) {
      final date = DateTime.tryParse(raw);
      // Keep malformed observations, so the pure layer reports their problem.
      return date == null || (!date.isBefore(start) && date.isBefore(end));
    }

    IncomeSourceRecord record(
      IncomeSourceKind kind,
      Map<String, dynamic> row,
      String dateField,
      String amountField,
      String? capturedOwner, {
      bool evidenceOnly = false,
    }) {
      final raw = row[amountField];
      final numeric =
          raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      final amount = numeric != null &&
              numeric.isFinite &&
              numeric >= 0 &&
              numeric <= 9007199254740991 &&
              numeric == numeric.truncateToDouble()
          ? numeric.toInt()
          : -1;
      final date = row[dateField]?.toString() ?? '';
      return IncomeSourceRecord(
        kind: kind,
        id: row['id']?.toString(),
        ownerId: row['user_id']?.toString() ?? capturedOwner ?? '',
        currency: row['currency']?.toString() ?? 'JPY',
        date: date,
        datePrecision: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)
            ? IncomeDatePrecision.day
            : IncomeDatePrecision.instant,
        amount: amount,
        observedAmount: raw?.toString(),
        payslipId: row['payslip_id']?.toString(),
        requiresPayslipLink:
            kind == IncomeSourceKind.salaryIncome && row['source'] == 'payslip',
        evidenceOnly: evidenceOnly,
      );
    }

    final salaryRows = payslipSalaryIncomes
        .where((row) => belongs(row['pay_date']?.toString() ?? ''))
        .toList();
    final neededIds = salaryRows
        .map((row) => row['payslip_id']?.toString())
        .whereType<String>()
        .toSet();
    final records = <IncomeSourceRecord>[
      for (final row in recentFlows)
        if (row['action_type'] == 'conquer' &&
            belongs(row['occurred_at']?.toString() ?? ''))
          record(
            IncomeSourceKind.flow,
            row,
            'occurred_at',
            'amount',
            flowOwnerId,
          ),
      for (final plan in monthlyIncomePlans)
        if (plan.received && belongs(_dateKey(plan.date)))
          // Legacy local plans carry no owner provenance. Do not relabel them.
          IncomeSourceRecord(
            kind: IncomeSourceKind.receivedPlan,
            id: plan.id,
            ownerId: '',
            currency: 'JPY',
            date: _dateKey(plan.date),
            datePrecision: IncomeDatePrecision.day,
            amount: plan.amount.isFinite &&
                    plan.amount == plan.amount.truncateToDouble() &&
                    plan.amount >= 0 &&
                    plan.amount <= 9007199254740991
                ? plan.amount.toInt()
                : -1,
            observedAmount: plan.amount.toString(),
          ),
      for (final row in payslipRows)
        if (belongs(row['pay_date']?.toString() ?? ''))
          record(
            IncomeSourceKind.payslip,
            row,
            'pay_date',
            'net_amount',
            financeOwnerId,
          ),
      for (final row in salaryRows)
        record(
          IncomeSourceKind.salaryIncome,
          row,
          'pay_date',
          'amount',
          financeOwnerId,
        ),
      for (final row in referencedPayslips)
        if (neededIds.contains(row['id']?.toString()) &&
            !payslipRows.any((existing) => existing['id'] == row['id']))
          record(
            IncomeSourceKind.payslip,
            row,
            'pay_date',
            'net_amount',
            financeOwnerId,
            evidenceOnly: true,
          ),
    ];
    return AssetIncomeSourceEvidence.project(
      ownerId: ownerId,
      currency: 'JPY',
      records: records,
      decisions: decisions,
      relationshipPage: relationshipPage,
    );
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

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

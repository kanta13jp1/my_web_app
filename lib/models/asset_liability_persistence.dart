import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

/// Supabase persistence draft for the asset/liability board.
///
/// Schema foundation tables:
/// - asset_liability_monthly_states
/// - asset_liability_income_plans
/// - asset_liability_recurring_income_templates
/// - asset_liability_payment_source_settings
/// - asset_liability_monthly_snapshots
///
/// Common columns:
///   - id uuid primary key default gen_random_uuid()
///   - user_id uuid not null
///   - month_key text not null
///   - payload jsonb not null default '{}'
///   - created_at timestamptz not null default now()
///   - updated_at timestamptz not null default now()
///
/// Runtime note:
/// SharedPreferences remains the primary store while Supabase sync is rolled
/// out behind feature flags. Supabase reads and production writes are enabled
/// separately so staging can inspect/restore data before allowing remote
/// mutation. UI code should continue to depend on AssetLiabilityRepository
/// rather than calling Supabase directly.
class AssetLiabilitySupabaseTablePlan {
  static const String monthlyStatesTable = 'asset_liability_monthly_states';
  static const String incomePlansTable = 'asset_liability_income_plans';
  static const String recurringIncomeTemplatesTable =
      'asset_liability_recurring_income_templates';
  static const String paymentSourceSettingsTable =
      'asset_liability_payment_source_settings';
  static const String monthlySnapshotsTable =
      'asset_liability_monthly_snapshots';

  static const String globalMonthKey = 'global';

  static const List<String> payloadTables = <String>[
    monthlyStatesTable,
    incomePlansTable,
    recurringIncomeTemplatesTable,
    paymentSourceSettingsTable,
    monthlySnapshotsTable,
  ];

  static const List<String> commonPayloadColumns = <String>[
    'id',
    'user_id',
    'month_key',
    'payload',
    'created_at',
    'updated_at',
  ];

  const AssetLiabilitySupabaseTablePlan._();
}

class AssetLiabilityPersistenceSnapshot {
  final String monthKey;
  final AssetLiabilityMonthlyState monthlyState;
  final Map<String, String> defaultPaymentSourceAccountIds;
  final Map<String, String> defaultCardBillingAccountIds;
  final List<AssetLiabilityRecurringIncomeTemplate> recurringIncomeTemplates;
  final List<AssetLiabilityMonthlySnapshot> monthlySnapshots;

  const AssetLiabilityPersistenceSnapshot({
    required this.monthKey,
    required this.monthlyState,
    required this.defaultPaymentSourceAccountIds,
    required this.defaultCardBillingAccountIds,
    required this.recurringIncomeTemplates,
    required this.monthlySnapshots,
  });
}

class AssetLiabilityMonthlyStatePayload {
  final String monthKey;
  final Map<String, double> paymentOverrides;
  final Map<String, double> actualPaymentAmounts;
  final Map<String, String> paymentDifferenceReasons;
  final Map<String, double> annualRateOverrides;
  final Map<String, AssetLiabilityAnnualRateEvidence> annualRateEvidences;
  final Set<String> paidAccountIds;
  final Map<String, String> paymentSourceAccountIds;
  final Map<String, String> cardBillingAccountIds;
  final List<AssetLiabilityCardStatementLine> cardStatementLines;
  final List<AssetLiabilityIncomePlan> incomePlans;
  final List<AssetLiabilityTransferTask> transferTasks;

  const AssetLiabilityMonthlyStatePayload({
    required this.monthKey,
    required this.paymentOverrides,
    required this.actualPaymentAmounts,
    required this.paymentDifferenceReasons,
    required this.annualRateOverrides,
    required this.annualRateEvidences,
    required this.paidAccountIds,
    required this.paymentSourceAccountIds,
    required this.cardBillingAccountIds,
    required this.cardStatementLines,
    required this.incomePlans,
    required this.transferTasks,
  });

  factory AssetLiabilityMonthlyStatePayload.fromState({
    required String monthKey,
    required AssetLiabilityMonthlyState state,
  }) {
    return AssetLiabilityMonthlyStatePayload(
      monthKey: monthKey,
      paymentOverrides: Map<String, double>.from(state.paymentOverrides),
      actualPaymentAmounts: Map<String, double>.from(
        state.actualPaymentAmounts,
      ),
      paymentDifferenceReasons: Map<String, String>.from(
        state.paymentDifferenceReasons,
      ),
      annualRateOverrides: Map<String, double>.from(state.annualRateOverrides),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        state.annualRateEvidences,
      ),
      paidAccountIds: Set<String>.from(state.paidAccountNames),
      paymentSourceAccountIds: Map<String, String>.from(
        state.paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(
        state.cardBillingAccountIds,
      ),
      cardStatementLines: List<AssetLiabilityCardStatementLine>.from(
        state.cardStatementLines,
      ),
      incomePlans: List<AssetLiabilityIncomePlan>.from(state.incomePlans),
      transferTasks: List<AssetLiabilityTransferTask>.from(state.transferTasks),
    );
  }

  factory AssetLiabilityMonthlyStatePayload.fromSupabaseJson(
    Map<String, Object?> json,
  ) {
    final monthKey =
        _readString(json, 'month_key') ?? _readString(json, 'monthKey') ?? '';
    return AssetLiabilityMonthlyStatePayload(
      monthKey: monthKey,
      paymentOverrides: _readDoubleMap(json, 'payment_overrides') ??
          _readDoubleMap(json, 'paymentOverrides') ??
          const <String, double>{},
      actualPaymentAmounts: _readDoubleMap(json, 'actual_payment_amounts') ??
          _readDoubleMap(json, 'actualPaymentAmounts') ??
          const <String, double>{},
      paymentDifferenceReasons:
          _readStringMap(json, 'payment_difference_reasons') ??
              _readStringMap(json, 'paymentDifferenceReasons') ??
              const <String, String>{},
      annualRateOverrides: _readDoubleMap(json, 'annual_rate_overrides') ??
          _readDoubleMap(json, 'annualRateOverrides') ??
          const <String, double>{},
      annualRateEvidences:
          _readAnnualRateEvidences(json, 'annual_rate_evidences') ??
              _readAnnualRateEvidences(json, 'annualRateEvidences') ??
              const <String, AssetLiabilityAnnualRateEvidence>{},
      paidAccountIds: _readStringSet(json, 'paid_account_ids') ??
          _readStringSet(json, 'paidAccountIds') ??
          const <String>{},
      paymentSourceAccountIds:
          _readStringMap(json, 'payment_source_account_ids') ??
              _readStringMap(json, 'paymentSourceAccountIds') ??
              const <String, String>{},
      cardBillingAccountIds: _readStringMap(json, 'card_billing_account_ids') ??
          _readStringMap(json, 'cardBillingAccountIds') ??
          const <String, String>{},
      cardStatementLines:
          _readCardStatementLines(json, 'card_statement_lines') ??
              _readCardStatementLines(json, 'cardStatementLines') ??
              const <AssetLiabilityCardStatementLine>[],
      incomePlans: _readIncomePlans(json, 'income_plans') ??
          _readIncomePlans(json, 'incomePlans') ??
          const <AssetLiabilityIncomePlan>[],
      transferTasks: _readTransferTasks(json, 'transfer_tasks') ??
          _readTransferTasks(json, 'transferTasks') ??
          const <AssetLiabilityTransferTask>[],
    );
  }

  AssetLiabilityMonthlyState toState() {
    return AssetLiabilityMonthlyState(
      paymentOverrides: Map<String, double>.from(paymentOverrides),
      actualPaymentAmounts: Map<String, double>.from(actualPaymentAmounts),
      paymentDifferenceReasons: Map<String, String>.from(
        paymentDifferenceReasons,
      ),
      annualRateOverrides: Map<String, double>.from(annualRateOverrides),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        annualRateEvidences,
      ),
      paidAccountNames: Set<String>.from(paidAccountIds),
      paymentSourceAccountIds: Map<String, String>.from(
        paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(cardBillingAccountIds),
      cardStatementLines: List<AssetLiabilityCardStatementLine>.from(
        cardStatementLines,
      ),
      incomePlans: List<AssetLiabilityIncomePlan>.from(incomePlans),
      transferTasks: List<AssetLiabilityTransferTask>.from(transferTasks),
    );
  }

  Map<String, Object?> toSupabaseJson({
    required String userId,
    DateTime? updatedAt,
  }) {
    final timestamp = updatedAt?.toUtc().toIso8601String();
    return <String, Object?>{
      'user_id': userId,
      'month_key': monthKey,
      'payment_overrides': Map<String, double>.from(paymentOverrides),
      'actual_payment_amounts': Map<String, double>.from(actualPaymentAmounts),
      'payment_difference_reasons': Map<String, String>.from(
        paymentDifferenceReasons,
      ),
      'annual_rate_overrides': Map<String, double>.from(annualRateOverrides),
      'annual_rate_evidences': {
        for (final entry in annualRateEvidences.entries)
          entry.key: entry.value.toJson(),
      },
      'paid_account_ids': (paidAccountIds.toList()..sort()),
      'payment_source_account_ids': Map<String, String>.from(
        paymentSourceAccountIds,
      ),
      'card_billing_account_ids': Map<String, String>.from(
        cardBillingAccountIds,
      ),
      'card_statement_lines': [
        for (final line in cardStatementLines) _encodeCardStatementLine(line),
      ],
      'income_plans': [for (final plan in incomePlans) _encodeIncomePlan(plan)],
      'transfer_tasks': [
        for (final task in transferTasks) _encodeTransferTask(task),
      ],
      if (timestamp != null) 'updated_at': timestamp,
    };
  }
}

class AssetLiabilityUserSettingsPayload {
  final Map<String, String> defaultPaymentSourceAccountIds;
  final Map<String, String> defaultCardBillingAccountIds;
  final List<AssetLiabilityRecurringIncomeTemplate> recurringIncomeTemplates;

  const AssetLiabilityUserSettingsPayload({
    required this.defaultPaymentSourceAccountIds,
    required this.defaultCardBillingAccountIds,
    required this.recurringIncomeTemplates,
  });

  factory AssetLiabilityUserSettingsPayload.fromSupabaseJson(
    Map<String, Object?> json,
  ) {
    return AssetLiabilityUserSettingsPayload(
      defaultPaymentSourceAccountIds:
          _readStringMap(json, 'default_payment_source_account_ids') ??
              _readStringMap(json, 'defaultPaymentSourceAccountIds') ??
              const <String, String>{},
      defaultCardBillingAccountIds:
          _readStringMap(json, 'default_card_billing_account_ids') ??
              _readStringMap(json, 'defaultCardBillingAccountIds') ??
              const <String, String>{},
      recurringIncomeTemplates:
          _readRecurringIncomeTemplates(json, 'recurring_income_templates') ??
              _readRecurringIncomeTemplates(json, 'recurringIncomeTemplates') ??
              const <AssetLiabilityRecurringIncomeTemplate>[],
    );
  }

  Map<String, Object?> toSupabaseJson({
    required String userId,
    DateTime? updatedAt,
  }) {
    final timestamp = updatedAt?.toUtc().toIso8601String();
    return <String, Object?>{
      'user_id': userId,
      'default_payment_source_account_ids': Map<String, String>.from(
        defaultPaymentSourceAccountIds,
      ),
      'default_card_billing_account_ids': Map<String, String>.from(
        defaultCardBillingAccountIds,
      ),
      'recurring_income_templates': [
        for (final template in recurringIncomeTemplates)
          _encodeRecurringIncomeTemplate(template),
      ],
      if (timestamp != null) 'updated_at': timestamp,
    };
  }
}

class AssetLiabilityMonthlySnapshotPayload {
  final AssetLiabilityMonthlySnapshot snapshot;

  const AssetLiabilityMonthlySnapshotPayload({required this.snapshot});

  factory AssetLiabilityMonthlySnapshotPayload.fromSupabaseJson(
    Map<String, Object?> json,
  ) {
    final monthKey =
        _readString(json, 'month_key') ?? _readString(json, 'monthKey') ?? '';
    final savedAtText =
        _readString(json, 'saved_at') ?? _readString(json, 'savedAt');
    final savedAt = DateTime.tryParse(savedAtText ?? '') ?? DateTime(1970);
    return AssetLiabilityMonthlySnapshotPayload(
      snapshot: AssetLiabilityMonthlySnapshot(
        monthKey: monthKey,
        savedAt: savedAt,
        positiveAssetTotal: _readDouble(json, 'positive_asset_total') ??
            _readDouble(json, 'positiveAssetTotal') ??
            0,
        liabilityTotal: _readDouble(json, 'liability_total') ??
            _readDouble(json, 'liabilityTotal') ??
            0,
        netWorth: _readDouble(json, 'net_worth') ??
            _readDouble(json, 'netWorth') ??
            0,
        cashLikeTotal: _readDouble(json, 'cash_like_total') ??
            _readDouble(json, 'cashLikeTotal') ??
            0,
        monthlyScheduledPaymentTotal:
            _readDouble(json, 'monthly_scheduled_payment_total') ??
                _readDouble(json, 'monthlyScheduledPaymentTotal') ??
                0,
        monthlyPaidPaymentTotal:
            _readDouble(json, 'monthly_paid_payment_total') ??
                _readDouble(json, 'monthlyPaidPaymentTotal') ??
                0,
        monthlyUnpaidPaymentTotal:
            _readDouble(json, 'monthly_unpaid_payment_total') ??
                _readDouble(json, 'monthlyUnpaidPaymentTotal') ??
                0,
        monthlyActualPaymentTotal:
            _readDouble(json, 'monthly_actual_payment_total') ??
                _readDouble(json, 'monthlyActualPaymentTotal') ??
                _readDouble(json, 'monthly_paid_payment_total') ??
                _readDouble(json, 'monthlyPaidPaymentTotal') ??
                0,
        monthlyPaymentDifferenceTotal:
            _readDouble(json, 'monthly_payment_difference_total') ??
                _readDouble(json, 'monthlyPaymentDifferenceTotal') ??
                0,
        overduePaymentCount: _readInt(json, 'overdue_payment_count') ??
            _readInt(json, 'overduePaymentCount') ??
            0,
      ),
    );
  }

  Map<String, Object?> toSupabaseJson({
    required String userId,
    DateTime? updatedAt,
  }) {
    final timestamp = updatedAt?.toUtc().toIso8601String();
    return <String, Object?>{
      'user_id': userId,
      'month_key': snapshot.monthKey,
      'saved_at': snapshot.savedAt.toUtc().toIso8601String(),
      'positive_asset_total': snapshot.positiveAssetTotal,
      'liability_total': snapshot.liabilityTotal,
      'net_worth': snapshot.netWorth,
      'cash_like_total': snapshot.cashLikeTotal,
      'monthly_scheduled_payment_total': snapshot.monthlyScheduledPaymentTotal,
      'monthly_paid_payment_total': snapshot.monthlyPaidPaymentTotal,
      'monthly_unpaid_payment_total': snapshot.monthlyUnpaidPaymentTotal,
      'monthly_actual_payment_total': snapshot.monthlyActualPaymentTotal,
      'monthly_payment_difference_total':
          snapshot.monthlyPaymentDifferenceTotal,
      'overdue_payment_count': snapshot.overduePaymentCount,
      if (timestamp != null) 'updated_at': timestamp,
    };
  }
}

Map<String, Object?> _encodeIncomePlan(AssetLiabilityIncomePlan plan) {
  return <String, Object?>{
    'id': plan.id,
    'date': _dateOnly(plan.date),
    'name': plan.name,
    'amount': plan.amount,
    'destinationAccountId': plan.destinationAccountId,
    'destinationAccountName': plan.destinationAccountName,
    'received': plan.received,
  };
}

Map<String, Object?> _encodeRecurringIncomeTemplate(
  AssetLiabilityRecurringIncomeTemplate template,
) {
  return <String, Object?>{
    'id': template.id,
    'dayOfMonth': template.dayOfMonth,
    'name': template.name,
    'amount': template.amount,
    'destinationAccountId': template.destinationAccountId,
    'destinationAccountName': template.destinationAccountName,
  };
}

Map<String, Object?> _encodeCardStatementLine(
  AssetLiabilityCardStatementLine line,
) {
  return <String, Object?>{
    'id': line.id,
    'billingAccountId': line.billingAccountId,
    'billingAccountName': line.billingAccountName,
    'postedAt': line.postedAt == null ? null : _dateOnly(line.postedAt!),
    'description': line.description,
    'amount': line.amount,
  };
}

Map<String, Object?> _encodeTransferTask(AssetLiabilityTransferTask task) {
  return <String, Object?>{
    'id': task.id,
    'fromAccountId': task.fromAccountId,
    'fromAccountName': task.fromAccountName,
    'toAccountId': task.toAccountId,
    'toAccountName': task.toAccountName,
    'amount': task.amount,
    'dueDate': task.dueDate == null ? null : _dateOnly(task.dueDate!),
    'completed': task.completed,
    'completedAt': task.completedAt?.toUtc().toIso8601String(),
    'completionMemo': task.completionMemo,
  };
}

AssetLiabilityIncomePlan? _decodeIncomePlan(Object? source) {
  if (source is! Map) {
    return null;
  }
  final id = _cleanString(source['id']);
  final date = DateTime.tryParse(_cleanString(source['date']) ?? '');
  final name = _cleanString(source['name']);
  final amount = _parseDouble(source['amount']);
  if (id == null ||
      date == null ||
      name == null ||
      amount == null ||
      amount <= 0) {
    return null;
  }
  return AssetLiabilityIncomePlan(
    id: id,
    date: date,
    name: name,
    amount: amount,
    destinationAccountId: _cleanString(source['destinationAccountId']),
    destinationAccountName: _cleanString(source['destinationAccountName']),
    received: source['received'] == true,
  );
}

AssetLiabilityRecurringIncomeTemplate? _decodeRecurringIncomeTemplate(
  Object? source,
) {
  if (source is! Map) {
    return null;
  }
  final id = _cleanString(source['id']);
  final name = _cleanString(source['name']);
  final day = _parseInt(source['dayOfMonth']);
  final amount = _parseDouble(source['amount']);
  if (id == null ||
      name == null ||
      day == null ||
      day < 1 ||
      amount == null ||
      amount <= 0) {
    return null;
  }
  return AssetLiabilityRecurringIncomeTemplate(
    id: id,
    dayOfMonth: day.clamp(1, 31).toInt(),
    name: name,
    amount: amount,
    destinationAccountId: _cleanString(source['destinationAccountId']),
    destinationAccountName: _cleanString(source['destinationAccountName']),
  );
}

AssetLiabilityCardStatementLine? _decodeCardStatementLine(Object? source) {
  if (source is! Map) {
    return null;
  }
  final id = _cleanString(source['id']);
  final billingAccountId = _cleanString(source['billingAccountId']) ??
      _cleanString(source['billing_account_id']);
  final description = _cleanString(source['description']);
  final amount = _parseDouble(source['amount']);
  final postedAtText =
      _cleanString(source['postedAt']) ?? _cleanString(source['posted_at']);
  final postedAt =
      postedAtText == null ? null : DateTime.tryParse(postedAtText);
  if (id == null ||
      billingAccountId == null ||
      description == null ||
      amount == null) {
    return null;
  }
  return AssetLiabilityCardStatementLine(
    id: id,
    billingAccountId: billingAccountId,
    billingAccountName: _cleanString(source['billingAccountName']) ??
        _cleanString(source['billing_account_name']),
    postedAt: postedAt,
    description: description,
    amount: amount,
  );
}

AssetLiabilityTransferTask? _decodeTransferTask(Object? source) {
  if (source is! Map) {
    return null;
  }
  final id = _cleanString(source['id']);
  final fromAccountId = _cleanString(source['fromAccountId']) ??
      _cleanString(source['from_account_id']);
  final toAccountId = _cleanString(source['toAccountId']) ??
      _cleanString(source['to_account_id']);
  final amount = _parseDouble(source['amount']);
  final dueDateText =
      _cleanString(source['dueDate']) ?? _cleanString(source['due_date']);
  final completedAtText = _cleanString(source['completedAt']) ??
      _cleanString(source['completed_at']);
  final dueDate = dueDateText == null ? null : DateTime.tryParse(dueDateText);
  final completedAt =
      completedAtText == null ? null : DateTime.tryParse(completedAtText);
  if (id == null ||
      fromAccountId == null ||
      toAccountId == null ||
      fromAccountId == toAccountId ||
      amount == null ||
      amount <= 0) {
    return null;
  }
  return AssetLiabilityTransferTask(
    id: id,
    fromAccountId: fromAccountId,
    fromAccountName: _cleanString(source['fromAccountName']) ??
        _cleanString(source['from_account_name']) ??
        fromAccountId,
    toAccountId: toAccountId,
    toAccountName: _cleanString(source['toAccountName']) ??
        _cleanString(source['to_account_name']) ??
        toAccountId,
    amount: amount,
    dueDate: dueDate,
    completed: source['completed'] == true,
    completedAt: completedAt,
    completionMemo: _cleanString(source['completionMemo']) ??
        _cleanString(source['completion_memo']) ??
        '',
  );
}

List<AssetLiabilityIncomePlan>? _readIncomePlans(
  Map<String, Object?> json,
  String key,
) {
  final source = json[key];
  if (source is! Iterable) {
    return null;
  }
  final plans = <AssetLiabilityIncomePlan>[];
  for (final value in source) {
    final plan = _decodeIncomePlan(value);
    if (plan != null) {
      plans.add(plan);
    }
  }
  plans.sort((a, b) => a.date.compareTo(b.date));
  return plans;
}

List<AssetLiabilityRecurringIncomeTemplate>? _readRecurringIncomeTemplates(
  Map<String, Object?> json,
  String key,
) {
  final source = json[key];
  if (source is! Iterable) {
    return null;
  }
  final templates = <AssetLiabilityRecurringIncomeTemplate>[];
  for (final value in source) {
    final template = _decodeRecurringIncomeTemplate(value);
    if (template != null) {
      templates.add(template);
    }
  }
  templates.sort((a, b) {
    final day = a.dayOfMonth.compareTo(b.dayOfMonth);
    if (day != 0) {
      return day;
    }
    return a.name.compareTo(b.name);
  });
  return templates;
}

List<AssetLiabilityCardStatementLine>? _readCardStatementLines(
  Map<String, Object?> json,
  String key,
) {
  final source = json[key];
  if (source is! Iterable) {
    return null;
  }
  final lines = <AssetLiabilityCardStatementLine>[];
  for (final value in source) {
    final line = _decodeCardStatementLine(value);
    if (line != null) {
      lines.add(line);
    }
  }
  lines.sort((a, b) {
    final billing = a.billingAccountId.compareTo(b.billingAccountId);
    if (billing != 0) {
      return billing;
    }
    final dateA = a.postedAt;
    final dateB = b.postedAt;
    if (dateA != null && dateB != null) {
      final date = dateA.compareTo(dateB);
      if (date != 0) {
        return date;
      }
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }
    return a.description.compareTo(b.description);
  });
  return lines;
}

List<AssetLiabilityTransferTask>? _readTransferTasks(
  Map<String, Object?> json,
  String key,
) {
  final source = json[key];
  if (source is! Iterable) {
    return null;
  }
  final tasks = <AssetLiabilityTransferTask>[];
  for (final value in source) {
    final task = _decodeTransferTask(value);
    if (task != null) {
      tasks.add(task);
    }
  }
  tasks.sort((a, b) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue != null && bDue != null) {
      final date = aDue.compareTo(bDue);
      if (date != 0) {
        return date;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  });
  return tasks;
}

Map<String, AssetLiabilityAnnualRateEvidence>? _readAnnualRateEvidences(
  Map<String, Object?> json,
  String key,
) {
  final source = json[key];
  if (source is! Map) {
    return null;
  }
  final result = <String, AssetLiabilityAnnualRateEvidence>{};
  for (final entry in source.entries) {
    if (entry.value is! Map) {
      continue;
    }
    final evidence = AssetLiabilityAnnualRateEvidence.fromJson(
      Map<String, Object?>.from(
        (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
    );
    if (evidence != null) {
      result[entry.key.toString()] = evidence;
    }
  }
  return result;
}

Map<String, double>? _readDoubleMap(Map<String, Object?> json, String key) {
  final source = json[key];
  if (source is! Map) {
    return null;
  }
  final result = <String, double>{};
  for (final entry in source.entries) {
    final amount = _parseDouble(entry.value);
    if (amount != null && amount >= 0) {
      result[entry.key.toString()] = amount;
    }
  }
  return result;
}

Map<String, String>? _readStringMap(Map<String, Object?> json, String key) {
  final source = json[key];
  if (source is! Map) {
    return null;
  }
  final result = <String, String>{};
  for (final entry in source.entries) {
    final mapKey = _cleanString(entry.key);
    final value = _cleanString(entry.value);
    if (mapKey != null && value != null) {
      result[mapKey] = value;
    }
  }
  return result;
}

Set<String>? _readStringSet(Map<String, Object?> json, String key) {
  final source = json[key];
  if (source is! Iterable) {
    return null;
  }
  final result = <String>{};
  for (final value in source) {
    final text = _cleanString(value);
    if (text != null) {
      result.add(text);
    }
  }
  return result;
}

String? _readString(Map<String, Object?> json, String key) {
  return _cleanString(json[key]);
}

double? _readDouble(Map<String, Object?> json, String key) {
  return _parseDouble(json[key]);
}

int? _readInt(Map<String, Object?> json, String key) {
  return _parseInt(json[key]);
}

String? _cleanString(Object? source) {
  final value = source?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

double? _parseDouble(Object? source) {
  if (source is num) {
    return source.toDouble();
  }
  if (source == null) {
    return null;
  }
  return double.tryParse(source.toString().replaceAll(',', ''));
}

int? _parseInt(Object? source) {
  if (source is num) {
    return source.toInt();
  }
  if (source == null) {
    return null;
  }
  return int.tryParse(source.toString().replaceAll(',', ''));
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

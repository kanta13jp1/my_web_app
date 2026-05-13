import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

/// Supabase persistence draft for the asset/liability board.
///
/// Proposed tables:
/// - asset_liability_monthly_states
///   - user_id uuid not null
///   - month_key text not null
///   - payment_overrides jsonb not null default '{}'
///   - paid_account_ids jsonb not null default '[]'
///   - payment_source_account_ids jsonb not null default '{}'
///   - income_plans jsonb not null default '[]'
///   - created_at timestamptz not null default now()
///   - updated_at timestamptz not null default now()
///   - primary key (user_id, month_key)
/// - asset_liability_user_settings
///   - user_id uuid primary key
///   - default_payment_source_account_ids jsonb not null default '{}'
///   - recurring_income_templates jsonb not null default '[]'
///   - created_at timestamptz not null default now()
///   - updated_at timestamptz not null default now()
/// - asset_liability_monthly_snapshots
///   - user_id uuid not null
///   - month_key text not null
///   - saved_at timestamptz not null
///   - positive_asset_total numeric not null
///   - liability_total numeric not null
///   - net_worth numeric not null
///   - cash_like_total numeric not null
///   - monthly_scheduled_payment_total numeric not null
///   - monthly_paid_payment_total numeric not null
///   - monthly_unpaid_payment_total numeric not null
///   - overdue_payment_count integer not null
///   - created_at timestamptz not null default now()
///   - updated_at timestamptz not null default now()
///   - primary key (user_id, month_key)
class AssetLiabilitySupabaseTablePlan {
  static const String monthlyStatesTable = 'asset_liability_monthly_states';
  static const String userSettingsTable = 'asset_liability_user_settings';
  static const String monthlySnapshotsTable =
      'asset_liability_monthly_snapshots';

  static const List<String> monthlyStateColumns = <String>[
    'user_id',
    'month_key',
    'payment_overrides',
    'paid_account_ids',
    'payment_source_account_ids',
    'income_plans',
    'created_at',
    'updated_at',
  ];

  static const List<String> userSettingsColumns = <String>[
    'user_id',
    'default_payment_source_account_ids',
    'recurring_income_templates',
    'created_at',
    'updated_at',
  ];

  static const List<String> monthlySnapshotColumns = <String>[
    'user_id',
    'month_key',
    'saved_at',
    'positive_asset_total',
    'liability_total',
    'net_worth',
    'cash_like_total',
    'monthly_scheduled_payment_total',
    'monthly_paid_payment_total',
    'monthly_unpaid_payment_total',
    'overdue_payment_count',
    'created_at',
    'updated_at',
  ];

  const AssetLiabilitySupabaseTablePlan._();
}

class AssetLiabilityPersistenceSnapshot {
  final String monthKey;
  final AssetLiabilityMonthlyState monthlyState;
  final Map<String, String> defaultPaymentSourceAccountIds;
  final List<AssetLiabilityRecurringIncomeTemplate> recurringIncomeTemplates;
  final List<AssetLiabilityMonthlySnapshot> monthlySnapshots;

  const AssetLiabilityPersistenceSnapshot({
    required this.monthKey,
    required this.monthlyState,
    required this.defaultPaymentSourceAccountIds,
    required this.recurringIncomeTemplates,
    required this.monthlySnapshots,
  });
}

class AssetLiabilityMonthlyStatePayload {
  final String monthKey;
  final Map<String, double> paymentOverrides;
  final Set<String> paidAccountIds;
  final Map<String, String> paymentSourceAccountIds;
  final List<AssetLiabilityIncomePlan> incomePlans;

  const AssetLiabilityMonthlyStatePayload({
    required this.monthKey,
    required this.paymentOverrides,
    required this.paidAccountIds,
    required this.paymentSourceAccountIds,
    required this.incomePlans,
  });

  factory AssetLiabilityMonthlyStatePayload.fromState({
    required String monthKey,
    required AssetLiabilityMonthlyState state,
  }) {
    return AssetLiabilityMonthlyStatePayload(
      monthKey: monthKey,
      paymentOverrides: Map<String, double>.from(state.paymentOverrides),
      paidAccountIds: Set<String>.from(state.paidAccountNames),
      paymentSourceAccountIds: Map<String, String>.from(
        state.paymentSourceAccountIds,
      ),
      incomePlans: List<AssetLiabilityIncomePlan>.from(state.incomePlans),
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
      paidAccountIds: _readStringSet(json, 'paid_account_ids') ??
          _readStringSet(json, 'paidAccountIds') ??
          const <String>{},
      paymentSourceAccountIds:
          _readStringMap(json, 'payment_source_account_ids') ??
              _readStringMap(json, 'paymentSourceAccountIds') ??
              const <String, String>{},
      incomePlans: _readIncomePlans(json, 'income_plans') ??
          _readIncomePlans(json, 'incomePlans') ??
          const <AssetLiabilityIncomePlan>[],
    );
  }

  AssetLiabilityMonthlyState toState() {
    return AssetLiabilityMonthlyState(
      paymentOverrides: Map<String, double>.from(paymentOverrides),
      paidAccountNames: Set<String>.from(paidAccountIds),
      paymentSourceAccountIds: Map<String, String>.from(
        paymentSourceAccountIds,
      ),
      incomePlans: List<AssetLiabilityIncomePlan>.from(incomePlans),
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
      'paid_account_ids': (paidAccountIds.toList()..sort()),
      'payment_source_account_ids': Map<String, String>.from(
        paymentSourceAccountIds,
      ),
      'income_plans': [for (final plan in incomePlans) _encodeIncomePlan(plan)],
      if (timestamp != null) 'updated_at': timestamp,
    };
  }
}

class AssetLiabilityUserSettingsPayload {
  final Map<String, String> defaultPaymentSourceAccountIds;
  final List<AssetLiabilityRecurringIncomeTemplate> recurringIncomeTemplates;

  const AssetLiabilityUserSettingsPayload({
    required this.defaultPaymentSourceAccountIds,
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

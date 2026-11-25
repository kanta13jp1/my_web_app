import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_cost_monitor_models.dart';

class SupabaseAiCostRepository implements AiCostMonitorRepository {
  SupabaseAiCostRepository({final SupabaseClient? client})
      : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    if (_providedClient != null) return _providedClient;
    return Supabase.instance.client;
  }

  @override
  Future<AiCostDashboardSnapshot> fetchDashboard({
    final String? targetDate,
  }) async {
    final summaryBody = <String, Object?>{
      'action': 'ai_cost.daily_summary',
      if (targetDate != null && targetDate.trim().isNotEmpty)
        'target_date': targetDate.trim(),
    };

    const listBody = <String, Object?>{
      'action': 'ai_cost.list_usage',
      'limit': 50,
    };
    final futures = <Future<Map<String, Object?>>>[
      _invokeAppHub(summaryBody),
      _invokeAppHub(listBody),
    ];
    final responses = await Future.wait<Map<String, Object?>>(futures);

    final summaryMap = responses[0];
    final usageMap = responses[1];
    final rawProviders = summaryMap['by_provider'];
    final rawAlerts = summaryMap['recent_alerts'];
    final rawLogs = usageMap['logs'];
    final rawDisclaimer = summaryMap['pricing_disclaimer'];

    return AiCostDashboardSnapshot(
      targetDate: (summaryMap['target_date'] ?? '').toString(),
      totalCalls: _toInt(summaryMap['total_calls']),
      knownCostCalls: _toInt(summaryMap['known_cost_calls']),
      unpricedCallCount: _toInt(summaryMap['unpriced_call_count']),
      totalCostUsd: _toDouble(summaryMap['total_cost_usd']),
      totalInputUnits: _toInt(summaryMap['total_input_units']),
      totalOutputUnits: _toInt(summaryMap['total_output_units']),
      totalUnits: _toInt(summaryMap['total_units']),
      byProvider: rawProviders is List
          ? rawProviders
              .whereType<Map>()
              .map(
                (final item) => ProviderCostBreakdown.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ProviderCostBreakdown>[],
      logs: rawLogs is List
          ? rawLogs
              .whereType<Map>()
              .map(
                (final item) => AiApiUsageLog.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <AiApiUsageLog>[],
      recentAlerts: rawAlerts is List
          ? rawAlerts
              .whereType<Map>()
              .map(
                (final item) => BudgetAlertRecord.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <BudgetAlertRecord>[],
      pricingDisclaimer:
          (rawDisclaimer ?? AiCostDashboardSnapshot.empty.pricingDisclaimer)
              .toString(),
    );
  }

  @override
  Future<AiApiUsageLog> recordUsage({
    required final String model,
    required final int inputUnits,
    required final int outputUnits,
    final String actionName = 'manual_entry',
  }) async {
    final data = await _invokeAppHub(<String, Object?>{
      'action': 'ai_cost.record_usage',
      'model': model.trim(),
      'input_units': inputUnits,
      'output_units': outputUnits,
      'action_name': actionName.trim(),
    });
    final logRaw = data['log'];
    if (logRaw is Map) {
      return AiApiUsageLog.fromMap(Map<String, Object?>.from(logRaw));
    }
    throw Exception('利用ログの保存レスポンスが不正です。');
  }

  @override
  Future<BudgetCheckOutcome> checkBudget({
    required final double budgetThresholdUsd,
    final String? targetDate,
  }) async {
    final data = await _invokeAppHub(<String, Object?>{
      'action': 'ai_cost.check_budget',
      'budget_threshold_usd': budgetThresholdUsd,
      if (targetDate != null && targetDate.trim().isNotEmpty)
        'target_date': targetDate.trim(),
    });
    return BudgetCheckOutcome.fromMap(data);
  }

  Future<Map<String, Object?>> _invokeAppHub(
    final Map<String, Object?> body,
  ) async {
    try {
      final response = await _client.functions.invoke('app-hub', body: body);
      if (response.status == 401) {
        throw const AiCostAuthException();
      }
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('app-hub からの応答形式が不正です。');
      }
      final map = Map<String, Object?>.from(raw);
      if (response.status >= 400 || map['success'] == false) {
        final msg = (map['error'] ?? 'AIコストデータの取得に失敗しました。').toString();
        throw Exception(msg);
      }
      return map;
    } on FunctionException catch (err) {
      if (err.status == 401) {
        throw const AiCostAuthException();
      }
      throw Exception('AIコスト監視 API エラー (${err.status})');
    }
  }

  int _toInt(final Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(final Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

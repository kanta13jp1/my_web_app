class AiCostAuthException implements Exception {
  const AiCostAuthException({
    this.message = '認証セッションが確認できません。ログイン後に再度お試しください。',
  });

  final String message;

  @override
  String toString() => message;
}

class AiApiUsageLog {
  const AiApiUsageLog({
    required this.id,
    required this.provider,
    required this.model,
    required this.actionName,
    required this.inputUnits,
    required this.outputUnits,
    required this.totalUnits,
    required this.knownPricing,
    required this.estimatedCostUsd,
    required this.pricingNote,
    required this.recordedAt,
    required this.usageDate,
  });

  final String id;
  final String provider;
  final String model;
  final String actionName;
  final int inputUnits;
  final int outputUnits;
  final int totalUnits;
  final bool knownPricing;
  final double? estimatedCostUsd;
  final String pricingNote;
  final String recordedAt;
  final String usageDate;

  factory AiApiUsageLog.fromMap(final Map<String, Object?> map) {
    return AiApiUsageLog(
      id: (map['id'] ?? '').toString(),
      provider: (map['provider'] ?? 'unknown').toString(),
      model: (map['model'] ?? 'unknown').toString(),
      actionName: (map['action_name'] ?? 'unknown').toString(),
      inputUnits: _asInt(map['input_units']),
      outputUnits: _asInt(map['output_units']),
      totalUnits: _asInt(map['total_units']),
      knownPricing: map['known_pricing'] == true,
      estimatedCostUsd: _asNullableDouble(map['estimated_cost_usd']),
      pricingNote: (map['pricing_note'] ?? '').toString(),
      recordedAt: (map['recorded_at'] ?? '').toString(),
      usageDate: (map['usage_date'] ?? '').toString(),
    );
  }
}

class ProviderCostBreakdown {
  const ProviderCostBreakdown({
    required this.provider,
    required this.callCount,
    required this.unpricedCallCount,
    required this.inputUnits,
    required this.outputUnits,
    required this.totalUnits,
    required this.estimatedCostUsd,
  });

  final String provider;
  final int callCount;
  final int unpricedCallCount;
  final int inputUnits;
  final int outputUnits;
  final int totalUnits;
  final double estimatedCostUsd;

  factory ProviderCostBreakdown.fromMap(final Map<String, Object?> map) {
    return ProviderCostBreakdown(
      provider: (map['provider'] ?? 'unknown').toString(),
      callCount: _asInt(map['call_count']),
      unpricedCallCount: _asInt(map['unpriced_call_count']),
      inputUnits: _asInt(map['input_units']),
      outputUnits: _asInt(map['output_units']),
      totalUnits: _asInt(map['total_units']),
      estimatedCostUsd: _asDouble(map['estimated_cost_usd']),
    );
  }
}

class BudgetAlertRecord {
  const BudgetAlertRecord({
    required this.id,
    required this.usageDate,
    required this.dailyCostUsd,
    required this.budgetThresholdUsd,
    required this.exceededByUsd,
    required this.issueTitle,
    required this.githubStatus,
    required this.githubIssueUrl,
    required this.githubIssueNumber,
    required this.recordedAt,
  });

  final String id;
  final String usageDate;
  final double dailyCostUsd;
  final double budgetThresholdUsd;
  final double exceededByUsd;
  final String issueTitle;
  final String githubStatus;
  final String? githubIssueUrl;
  final int? githubIssueNumber;
  final String recordedAt;

  factory BudgetAlertRecord.fromMap(final Map<String, Object?> map) {
    final issueNumRaw = map['github_issue_number'];
    final issueUrlRaw = map['github_issue_url']?.toString().trim() ?? '';
    return BudgetAlertRecord(
      id: (map['id'] ?? '').toString(),
      usageDate: (map['usage_date'] ?? '').toString(),
      dailyCostUsd: _asDouble(map['daily_cost_usd']),
      budgetThresholdUsd: _asDouble(map['budget_threshold_usd']),
      exceededByUsd: _asDouble(map['exceeded_by_usd']),
      issueTitle: (map['issue_title'] ?? '').toString(),
      githubStatus: (map['github_status'] ?? 'recorded').toString(),
      githubIssueUrl: issueUrlRaw.isEmpty ? null : issueUrlRaw,
      githubIssueNumber:
          issueNumRaw == null ? null : _asNullableInt(issueNumRaw),
      recordedAt: (map['recorded_at'] ?? '').toString(),
    );
  }
}

class BudgetCheckOutcome {
  const BudgetCheckOutcome({
    required this.targetDate,
    required this.budgetThresholdUsd,
    required this.dailyCostUsd,
    required this.exceededByUsd,
    required this.thresholdExceeded,
    required this.unpricedCallCount,
    required this.githubStatus,
    required this.issueTitle,
    required this.githubIssueUrl,
    required this.githubIssueNumber,
  });

  final String targetDate;
  final double budgetThresholdUsd;
  final double dailyCostUsd;
  final double exceededByUsd;
  final bool thresholdExceeded;
  final int unpricedCallCount;
  final String githubStatus;
  final String issueTitle;
  final String? githubIssueUrl;
  final int? githubIssueNumber;

  factory BudgetCheckOutcome.fromMap(final Map<String, Object?> map) {
    final ghResult = map['github_result'] is Map
        ? Map<String, Object?>.from(map['github_result'] as Map)
        : const <String, Object?>{};
    final issuePayload = map['github_issue_payload'] is Map
        ? Map<String, Object?>.from(map['github_issue_payload'] as Map)
        : const <String, Object?>{};
    final issueUrlRaw = ghResult['html_url']?.toString().trim() ?? '';
    return BudgetCheckOutcome(
      targetDate: (map['target_date'] ?? '').toString(),
      budgetThresholdUsd: _asDouble(map['budget_threshold_usd']),
      dailyCostUsd: _asDouble(map['daily_cost_usd']),
      exceededByUsd: _asDouble(map['exceeded_by_usd']),
      thresholdExceeded: map['threshold_exceeded'] == true,
      unpricedCallCount: _asInt(map['unpriced_call_count']),
      githubStatus: (ghResult['status'] ?? 'not_needed').toString(),
      issueTitle: (issuePayload['title'] ?? '').toString(),
      githubIssueUrl: issueUrlRaw.isEmpty ? null : issueUrlRaw,
      githubIssueNumber: _asNullableInt(ghResult['issue_number']),
    );
  }
}

class AiCostDashboardSnapshot {
  const AiCostDashboardSnapshot({
    required this.targetDate,
    required this.totalCalls,
    required this.knownCostCalls,
    required this.unpricedCallCount,
    required this.totalCostUsd,
    required this.totalInputUnits,
    required this.totalOutputUnits,
    required this.totalUnits,
    required this.byProvider,
    required this.logs,
    required this.recentAlerts,
    required this.pricingDisclaimer,
  });

  final String targetDate;
  final int totalCalls;
  final int knownCostCalls;
  final int unpricedCallCount;
  final double totalCostUsd;
  final int totalInputUnits;
  final int totalOutputUnits;
  final int totalUnits;
  final List<ProviderCostBreakdown> byProvider;
  final List<AiApiUsageLog> logs;
  final List<BudgetAlertRecord> recentAlerts;
  final String pricingDisclaimer;

  static const AiCostDashboardSnapshot empty = AiCostDashboardSnapshot(
    targetDate: '',
    totalCalls: 0,
    knownCostCalls: 0,
    unpricedCallCount: 0,
    totalCostUsd: 0,
    totalInputUnits: 0,
    totalOutputUnits: 0,
    totalUnits: 0,
    byProvider: <ProviderCostBreakdown>[],
    logs: <AiApiUsageLog>[],
    recentAlerts: <BudgetAlertRecord>[],
    pricingDisclaimer:
        '参考単価(USD/1M単位)に基づく概算見積りです。キャッシュ割引・段階課金・最新の公式価格改定により実請求と異なる場合があります。',
  );
}

abstract class AiCostMonitorRepository {
  Future<AiCostDashboardSnapshot> fetchDashboard({String? targetDate});

  Future<AiApiUsageLog> recordUsage({
    required String model,
    required int inputUnits,
    required int outputUnits,
    String actionName = 'manual_entry',
  });

  Future<BudgetCheckOutcome> checkBudget({
    required double budgetThresholdUsd,
    String? targetDate,
  });
}

int _asInt(final Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(final Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(final Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(final Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

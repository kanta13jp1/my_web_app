import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/external_diff_alert_models.dart';

class SupabaseExternalDiffAlertRepository
    implements ExternalDiffAlertRepository {
  SupabaseExternalDiffAlertRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;
  RealtimeChannel? _channel;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireAuthenticatedUser() {
    if (_resolvedClient.auth.currentUser == null) {
      throw StateError(
        'サインイン済みセッションが必要です。ログイン後に再試行してください。',
      );
    }
  }

  @override
  Future<ExternalDiffDashboardSnapshot> fetchDashboard({int limit = 30}) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'core-hub',
      body: <String, Object?>{
        'action': 'external_diff.alert.list',
        'limit': limit,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'external_diff.alert.list',
    );
    return ExternalDiffDashboardSnapshot.fromJson(payload);
  }

  @override
  Future<ExternalDiffRule> upsertRule({
    required String ruleName,
    required String sourceKey,
    required String fieldPath,
    required DiffRuleOperator operatorType,
    required String thresholdValue,
    required DiffAlertSeverity severity,
    required bool notifyEmail,
    required String recipientEmail,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'core-hub',
      body: <String, Object?>{
        'action': 'external_diff.rule.upsert',
        'rule_name': ruleName.trim(),
        'source_key': sourceKey.trim(),
        'field_path': fieldPath.trim(),
        'operator': operatorType.wireValue,
        'threshold_value': thresholdValue.trim(),
        'severity': severity.wireValue,
        'notify_email': notifyEmail,
        'recipient_email': recipientEmail.trim(),
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'external_diff.rule.upsert',
    );
    return ExternalDiffRule.fromJson(
      normalizeJsonObject(payload['rule'], 'rule'),
    );
  }

  @override
  Future<SnapshotDetectOutcome> runSnapshotDetect({
    required String sourceKey,
    required Map<String, Object?> payload,
    bool dryRun = false,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'core-hub',
      body: <String, Object?>{
        'action': 'external_diff.snapshot_and_detect',
        'source_key': sourceKey.trim(),
        'payload': payload,
        'dry_run': dryRun,
      },
    );
    final data = normalizeJsonObject(
      response.data,
      'external_diff.snapshot_and_detect',
    );
    return SnapshotDetectOutcome.fromJson(data);
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    _requireAuthenticatedUser();
    await _resolvedClient.functions.invoke(
      'core-hub',
      body: <String, Object?>{
        'action': 'external_diff.alert.acknowledge',
        'alert_id': alertId,
      },
    );
  }

  @override
  bool subscribeToAlerts(void Function() onRealtimeAlert) {
    if (_channel != null) {
      return true;
    }
    try {
      _channel = _resolvedClient
          .channel('public:async_jobs:external_diff_alerts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'async_jobs',
            callback: (PostgresChangePayload _) => onRealtimeAlert(),
          )
          .subscribe();
      return true;
    } catch (_) {
      _channel = null;
      return false;
    }
  }

  @override
  Future<void> disposeSubscription() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) {
      return;
    }
    try {
      await _resolvedClient.removeChannel(channel);
    } catch (_) {
      // Realtime チャンネル破棄エラーは画面終了を阻害しない。
    }
  }
}

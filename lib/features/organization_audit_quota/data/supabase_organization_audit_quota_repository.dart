import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/organization_audit_quota_models.dart';

/// 組織監査ログ・クォータ管理リポジトリ契約 (#2692).
abstract class OrganizationAuditQuotaRepository {
  Future<OrganizationAuditQuotaDashboard> fetchDashboard({
    required final String organizationId,
    final OrgAuditEventType eventFilter = OrgAuditEventType.all,
  });

  Future<OrganizationAuditLogEntry> recordAuditEvent({
    required final String organizationId,
    required final OrgAuditEventType eventType,
    required final String resourceType,
    final String resourceId = '',
    final String summary = '',
  });

  Future<OrgQuotaConsumeOutcome> consumeQuota({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    final int units = 1,
  });

  Future<OrganizationQuotaUsage> updateQuotaLimit({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    required final int limitAmount,
    final double warningThresholdPct = 80.0,
  });

  Future<OrganizationQuotaAlert> acknowledgeAlert({
    required final String organizationId,
    required final String alertId,
  });
}

Map<String, Object?> _normalizeMap(final Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map(
      (final Object? k, final Object? v) =>
          MapEntry<String, Object?>(k.toString(), v),
    );
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _normalizeMapList(final Object? raw) {
  if (raw is! List) {
    return const <Map<String, Object?>>[];
  }
  return raw
      .whereType<Map<Object?, Object?>>()
      .map(
        (final Map<Object?, Object?> entry) => entry.map(
          (final Object? k, final Object? v) =>
              MapEntry<String, Object?>(k.toString(), v),
        ),
      )
      .toList(growable: false);
}

/// `admin-hub` Edge Function 経由で組織監査ログ・クォータを操作する実装 (#2692).
class SupabaseOrganizationAuditQuotaRepository
    implements OrganizationAuditQuotaRepository {
  SupabaseOrganizationAuditQuotaRepository({final SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, Object?>> _invokeAdminHub(
    final Map<String, Object?> body,
  ) async {
    try {
      final FunctionResponse res = await _client.functions.invoke(
        'admin-hub',
        body: body,
      );
      final Map<String, Object?> payload = _normalizeMap(res.data);
      if (res.status == 429 || payload['code'] == 'QUOTA_EXCEEDED') {
        final String msg = (payload['error']?.toString() ?? '').trim();
        throw OrgQuotaExceededException(
          message: msg.isNotEmpty
              ? msg
              : '組織のリソース利用上限に達したため処理をブロックしました。管理者にクォータ引き上げを依頼してください。',
        );
      }
      if (payload['success'] == false) {
        final String err =
            (payload['error']?.toString() ?? '組織クォータAPI呼び出しに失敗しました').trim();
        throw StateError(err);
      }
      return payload;
    } on FunctionException catch (exc) {
      final Map<String, Object?> details = _normalizeMap(exc.details);
      final String msg = (details['error']?.toString() ??
              exc.reasonPhrase ??
              '組織クォータAPIエラー (HTTP ${exc.status})')
          .trim();
      if (exc.status == 429 || details['code'] == 'QUOTA_EXCEEDED') {
        throw OrgQuotaExceededException(
          message: msg.isNotEmpty ? msg : '組織のリソース利用上限に達したため処理をブロックしました。',
        );
      }
      throw StateError(msg);
    }
  }

  @override
  Future<OrganizationAuditQuotaDashboard> fetchDashboard({
    required final String organizationId,
    final OrgAuditEventType eventFilter = OrgAuditEventType.all,
  }) async {
    final Map<String, Object?> quotaPayload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_quota.status',
        'organization_id': organizationId,
      },
    );
    final Map<String, Object?> auditPayload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_audit.list',
        'organization_id': organizationId,
        if (eventFilter != OrgAuditEventType.all)
          'event_type': eventFilter.wireValue,
        'limit': 50,
      },
    );

    final List<OrganizationQuotaUsage> quotas =
        _normalizeMapList(quotaPayload['quotas'])
            .map(OrganizationQuotaUsage.fromJson)
            .toList(growable: false);
    final List<OrganizationQuotaAlert> alerts =
        _normalizeMapList(quotaPayload['alerts'])
            .map(OrganizationQuotaAlert.fromJson)
            .toList(growable: false);
    final List<OrganizationAuditLogEntry> logs =
        _normalizeMapList(auditPayload['entries'])
            .map(OrganizationAuditLogEntry.fromJson)
            .toList(growable: false);

    return OrganizationAuditQuotaDashboard(
      organizationId: organizationId,
      periodKey: (quotaPayload['period_key']?.toString() ?? '').trim(),
      quotas: List<OrganizationQuotaUsage>.unmodifiable(quotas),
      alerts: List<OrganizationQuotaAlert>.unmodifiable(alerts),
      auditLogs: List<OrganizationAuditLogEntry>.unmodifiable(logs),
    );
  }

  @override
  Future<OrganizationAuditLogEntry> recordAuditEvent({
    required final String organizationId,
    required final OrgAuditEventType eventType,
    required final String resourceType,
    final String resourceId = '',
    final String summary = '',
  }) async {
    final Map<String, Object?> payload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_audit.record',
        'organization_id': organizationId,
        'event_type': eventType.wireValue,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'summary': summary,
      },
    );
    return OrganizationAuditLogEntry.fromJson(
      _normalizeMap(payload['entry']),
    );
  }

  @override
  Future<OrgQuotaConsumeOutcome> consumeQuota({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    final int units = 1,
  }) async {
    final Map<String, Object?> payload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_quota.consume',
        'organization_id': organizationId,
        'resource_type': resourceType.wireValue,
        'units': units,
      },
    );
    return OrgQuotaConsumeOutcome.fromJson(payload);
  }

  @override
  Future<OrganizationQuotaUsage> updateQuotaLimit({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    required final int limitAmount,
    final double warningThresholdPct = 80.0,
  }) async {
    final Map<String, Object?> payload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_quota.update_limit',
        'organization_id': organizationId,
        'resource_type': resourceType.wireValue,
        'limit_amount': limitAmount,
        'warning_threshold_pct': warningThresholdPct,
      },
    );
    return OrganizationQuotaUsage.fromJson(
      _normalizeMap(payload['quota']),
    );
  }

  @override
  Future<OrganizationQuotaAlert> acknowledgeAlert({
    required final String organizationId,
    required final String alertId,
  }) async {
    final Map<String, Object?> payload = await _invokeAdminHub(
      <String, Object?>{
        'action': 'org_quota.acknowledge_alert',
        'organization_id': organizationId,
        'alert_id': alertId,
      },
    );
    return OrganizationQuotaAlert.fromJson(
      _normalizeMap(payload['alert']),
    );
  }
}

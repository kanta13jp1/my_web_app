import 'package:flutter/foundation.dart';

/// 組織監査イベント種別 (#2692).
enum OrgAuditEventType {
  all('all', 'すべて'),
  login('login', 'ログイン'),
  permissionChange('permission_change', '権限変更'),
  resourceCreate('resource_create', 'データ作成'),
  resourceDelete('resource_delete', 'データ削除'),
  quotaWarning80('quota_warning_80', '80%クォータ警告'),
  quotaLimitExceeded('quota_limit_exceeded', '上限超過ブロック'),
  quotaPolicyUpdate('quota_policy_update', 'クォータ設定変更');

  const OrgAuditEventType(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static OrgAuditEventType parse(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final OrgAuditEventType item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return OrgAuditEventType.resourceCreate;
  }
}

/// 組織単位でクォータ監視対象となるリソース種別 (#2692).
enum OrgQuotaResourceType {
  apiCalls('api_calls', 'API 呼び出し回数', '回'),
  computeUnits('compute_units', '処理コンピュート', 'CU'),
  storageMb('storage_mb', 'ストレージ使用量', 'MB');

  const OrgQuotaResourceType(this.wireValue, this.labelJa, this.unitLabel);

  final String wireValue;
  final String labelJa;
  final String unitLabel;

  static OrgQuotaResourceType parse(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final OrgQuotaResourceType item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return OrgQuotaResourceType.apiCalls;
  }
}

/// クォータ閾値アラート種別 (#2692).
enum OrgQuotaAlertLevel {
  warning80('warning_80', '80% 警告'),
  limit100('limit_100', '100% ブロック');

  const OrgQuotaAlertLevel(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static OrgQuotaAlertLevel parse(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final OrgQuotaAlertLevel level in values) {
      if (level.wireValue == normalized) {
        return level;
      }
    }
    return OrgQuotaAlertLevel.warning80;
  }
}

/// クォータ上限超過（HTTP 429）時に UI へ返す例外 (#2692).
class OrgQuotaExceededException implements Exception {
  const OrgQuotaExceededException({
    required this.message,
    this.code = 'QUOTA_EXCEEDED',
    this.httpStatus = 429,
  });

  final String message;
  final String code;
  final int httpStatus;

  @override
  String toString() => message;
}

int _parseInt(final Object? raw, {final int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

double _parseDouble(final Object? raw, {final double fallback = 0.0}) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? fallback;
}

DateTime? _parseDateTime(final Object? raw) {
  final String text = (raw?.toString() ?? '').trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

/// 組織監査ログの 1 エントリ (#2692).
@immutable
class OrganizationAuditLogEntry {
  const OrganizationAuditLogEntry({
    required this.id,
    required this.actorRole,
    required this.eventType,
    required this.resourceType,
    required this.resourceId,
    required this.summary,
    required this.createdAt,
    this.organizationId,
    this.actorUserId,
  });

  final String id;
  final String? organizationId;
  final String? actorUserId;
  final String actorRole;
  final OrgAuditEventType eventType;
  final String resourceType;
  final String resourceId;
  final String summary;
  final DateTime createdAt;

  factory OrganizationAuditLogEntry.fromJson(final Map<String, Object?> json) {
    final String orgRaw = (json['organization_id']?.toString() ?? '').trim();
    final String actorRaw = (json['actor_user_id']?.toString() ?? '').trim();
    return OrganizationAuditLogEntry(
      id: (json['id']?.toString() ?? '').trim(),
      organizationId: orgRaw.isEmpty ? null : orgRaw,
      actorUserId: actorRaw.isEmpty ? null : actorRaw,
      actorRole: (json['actor_role']?.toString() ?? 'authenticated').trim(),
      eventType: OrgAuditEventType.parse(json['event_type']?.toString()),
      resourceType: (json['resource_type']?.toString() ?? '').trim(),
      resourceId: (json['resource_id']?.toString() ?? '').trim(),
      summary: (json['summary']?.toString() ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.utc(2026, 1, 1),
    );
  }
}

/// 組織リソース別の月次クォータ利用状況 (#2692).
@immutable
class OrganizationQuotaUsage {
  const OrganizationQuotaUsage({
    required this.id,
    required this.organizationId,
    required this.resourceType,
    required this.periodKey,
    required this.limitAmount,
    required this.usedAmount,
    required this.warningThresholdPct,
    this.warning80TriggeredAt,
    this.lastExceededAt,
  });

  final String id;
  final String organizationId;
  final OrgQuotaResourceType resourceType;
  final String periodKey;
  final int limitAmount;
  final int usedAmount;
  final double warningThresholdPct;
  final DateTime? warning80TriggeredAt;
  final DateTime? lastExceededAt;

  int get remaining =>
      (limitAmount - usedAmount) < 0 ? 0 : (limitAmount - usedAmount);

  double get usagePct =>
      limitAmount <= 0 ? 100.0 : (usedAmount / limitAmount) * 100.0;

  bool get isWarning80 =>
      usagePct >= warningThresholdPct || warning80TriggeredAt != null;

  bool get isExceeded => usedAmount >= limitAmount;

  factory OrganizationQuotaUsage.fromJson(final Map<String, Object?> json) {
    final int limit = _parseInt(json['limit_amount'], fallback: 1000);
    final int used = _parseInt(json['used_amount'], fallback: 0);
    final double threshold = _parseDouble(
      json['warning_threshold_pct'],
      fallback: 80.0,
    );
    return OrganizationQuotaUsage(
      id: (json['id']?.toString() ?? '').trim(),
      organizationId: (json['organization_id']?.toString() ?? '').trim(),
      resourceType:
          OrgQuotaResourceType.parse(json['resource_type']?.toString()),
      periodKey: (json['period_key']?.toString() ?? '').trim(),
      limitAmount: limit <= 0 ? 1000 : limit,
      usedAmount: used < 0 ? 0 : used,
      warningThresholdPct: threshold <= 0 ? 80.0 : threshold,
      warning80TriggeredAt: _parseDateTime(json['warning_80_triggered_at']),
      lastExceededAt: _parseDateTime(json['last_exceeded_at']),
    );
  }
}

/// 管理者向け 80% 警告 / 100% ブロックアラート通知 (#2692).
@immutable
class OrganizationQuotaAlert {
  const OrganizationQuotaAlert({
    required this.id,
    required this.organizationId,
    required this.resourceType,
    required this.periodKey,
    required this.alertLevel,
    required this.usagePct,
    required this.usedAmount,
    required this.limitAmount,
    required this.message,
    required this.adminNotified,
    required this.createdAt,
    this.notifiedAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  final String id;
  final String organizationId;
  final OrgQuotaResourceType resourceType;
  final String periodKey;
  final OrgQuotaAlertLevel alertLevel;
  final double usagePct;
  final int usedAmount;
  final int limitAmount;
  final String message;
  final bool adminNotified;
  final DateTime createdAt;
  final DateTime? notifiedAt;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;

  factory OrganizationQuotaAlert.fromJson(final Map<String, Object?> json) {
    final String ackBy = (json['acknowledged_by']?.toString() ?? '').trim();
    return OrganizationQuotaAlert(
      id: (json['id']?.toString() ?? '').trim(),
      organizationId: (json['organization_id']?.toString() ?? '').trim(),
      resourceType:
          OrgQuotaResourceType.parse(json['resource_type']?.toString()),
      periodKey: (json['period_key']?.toString() ?? '').trim(),
      alertLevel: OrgQuotaAlertLevel.parse(json['alert_level']?.toString()),
      usagePct: _parseDouble(json['usage_pct'], fallback: 0.0),
      usedAmount: _parseInt(json['used_amount'], fallback: 0),
      limitAmount: _parseInt(json['limit_amount'], fallback: 1000),
      message: (json['message']?.toString() ?? '').trim(),
      adminNotified: json['admin_notified'] == true,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.utc(2026, 1, 1),
      notifiedAt: _parseDateTime(json['notified_at']),
      acknowledgedBy: ackBy.isEmpty ? null : ackBy,
      acknowledgedAt: _parseDateTime(json['acknowledged_at']),
    );
  }
}

/// クォータ消費判定レスポンス (#2692).
@immutable
class OrgQuotaConsumeOutcome {
  const OrgQuotaConsumeOutcome({
    required this.allowed,
    required this.httpStatus,
    required this.usedAmount,
    required this.limitAmount,
    required this.remaining,
    required this.usagePct,
    required this.warning80Triggered,
    required this.alertTriggered,
    this.code,
    this.errorMessage,
  });

  final bool allowed;
  final int httpStatus;
  final int usedAmount;
  final int limitAmount;
  final int remaining;
  final double usagePct;
  final bool warning80Triggered;
  final bool alertTriggered;
  final String? code;
  final String? errorMessage;

  factory OrgQuotaConsumeOutcome.fromJson(final Map<String, Object?> json) {
    final rawQuota = json['quota'];
    final Map<String, Object?> quotaMap = rawQuota is Map
        ? rawQuota.map(
            (final Object? k, final Object? v) =>
                MapEntry<String, Object?>(k.toString(), v),
          )
        : json;
    final String codeRaw =
        (quotaMap['code']?.toString() ?? json['code']?.toString() ?? '').trim();
    final String errRaw = (quotaMap['error_message']?.toString() ??
            json['error']?.toString() ??
            '')
        .trim();
    return OrgQuotaConsumeOutcome(
      allowed: quotaMap['allowed'] != false && json['allowed'] != false,
      httpStatus: _parseInt(quotaMap['http_status'], fallback: 200),
      usedAmount: _parseInt(quotaMap['used_amount'], fallback: 0),
      limitAmount: _parseInt(quotaMap['limit_amount'], fallback: 1000),
      remaining: _parseInt(quotaMap['remaining'], fallback: 0),
      usagePct: _parseDouble(quotaMap['usage_pct'], fallback: 0.0),
      warning80Triggered: quotaMap['warning_80_triggered'] == true ||
          json['warning_80_triggered'] == true,
      alertTriggered: json['alert_triggered'] == true ||
          quotaMap['warning_80_newly_triggered'] == true,
      code: codeRaw.isEmpty ? null : codeRaw,
      errorMessage: errRaw.isEmpty ? null : errRaw,
    );
  }
}

/// 監査ログ・クォータ状態の集約スナップショット (#2692).
@immutable
class OrganizationAuditQuotaDashboard {
  const OrganizationAuditQuotaDashboard({
    required this.organizationId,
    required this.periodKey,
    required this.quotas,
    required this.alerts,
    required this.auditLogs,
  });

  final String organizationId;
  final String periodKey;
  final List<OrganizationQuotaUsage> quotas;
  final List<OrganizationQuotaAlert> alerts;
  final List<OrganizationAuditLogEntry> auditLogs;

  bool get hasWarning80 =>
      quotas.any((final OrganizationQuotaUsage q) => q.isWarning80) ||
      alerts.any(
        (final OrganizationQuotaAlert a) =>
            a.alertLevel == OrgQuotaAlertLevel.warning80 && !a.isAcknowledged,
      );

  bool get hasExceededQuota =>
      quotas.any((final OrganizationQuotaUsage q) => q.isExceeded);
}

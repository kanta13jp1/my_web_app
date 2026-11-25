import 'package:flutter/foundation.dart';

Map<String, Object?> normalizeJsonObject(Object? raw, String context) {
  if (raw is! Map<Object?, Object?>) {
    throw FormatException('Expected JSON object for $context.');
  }
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      throw FormatException('Expected String key in $context.');
    }
    result[key] = entry.value;
  }
  return result;
}

String _readString(Map<String, Object?> json, String key, {String def = ''}) {
  final Object? raw = json[key];
  if (raw == null) {
    return def;
  }
  if (raw is! String) {
    throw FormatException('Expected String for "$key".');
  }
  return raw;
}

String _requireNonEmptyString(Map<String, Object?> json, String key) {
  final val = _readString(json, key).trim();
  if (val.isEmpty) {
    throw FormatException('Missing non-empty String "$key".');
  }
  return val;
}

bool _readBool(Map<String, Object?> json, String key, {bool def = false}) {
  final Object? raw = json[key];
  if (raw == null) {
    return def;
  }
  if (raw is! bool) {
    throw FormatException('Expected bool for "$key".');
  }
  return raw;
}

List<String> _readStringList(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw == null) {
    return const <String>[];
  }
  if (raw is! List<Object?>) {
    throw FormatException('Expected List for "$key".');
  }
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) {
      throw FormatException('Expected String element in "$key".');
    }
    out.add(item);
  }
  return List<String>.unmodifiable(out);
}

enum DiffRuleOperator {
  anyChange('any_change', '全フィールド変更検知'),
  fieldChanged('field_changed', '指定フィールド更新'),
  gt('gt', '閾値超過 (>)'),
  lt('lt', '閾値未満 (<)'),
  pctChangeGte('pct_change_gte', '変化率 (% 以上)'),
  contains('contains', '文字列一致');

  const DiffRuleOperator(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static DiffRuleOperator fromWire(Object? raw) {
    if (raw is String) {
      for (final value in DiffRuleOperator.values) {
        if (value.wireValue == raw) {
          return value;
        }
      }
    }
    throw FormatException('Unknown DiffRuleOperator: "$raw".');
  }
}

enum DiffAlertSeverity {
  info('info', '情報'),
  warning('warning', '警告'),
  critical('critical', '緊急');

  const DiffAlertSeverity(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static DiffAlertSeverity fromWire(Object? raw) {
    if (raw is String) {
      for (final value in DiffAlertSeverity.values) {
        if (value.wireValue == raw) {
          return value;
        }
      }
    }
    throw FormatException('Unknown DiffAlertSeverity: "$raw".');
  }
}

@immutable
class ExternalDiffRule {
  const ExternalDiffRule({
    required this.id,
    required this.ruleName,
    required this.sourceKey,
    required this.fieldPath,
    required this.operatorType,
    required this.thresholdValue,
    required this.severity,
    required this.notifyEmail,
    required this.recipientEmail,
    required this.enabled,
    required this.updatedAt,
  });

  final String id;
  final String ruleName;
  final String sourceKey;
  final String fieldPath;
  final DiffRuleOperator operatorType;
  final String thresholdValue;
  final DiffAlertSeverity severity;
  final bool notifyEmail;
  final String recipientEmail;
  final bool enabled;
  final String updatedAt;

  factory ExternalDiffRule.fromJson(Map<String, Object?> json) {
    return ExternalDiffRule(
      id: _requireNonEmptyString(json, 'id'),
      ruleName: _requireNonEmptyString(json, 'ruleName'),
      sourceKey: _requireNonEmptyString(json, 'sourceKey'),
      fieldPath: _readString(json, 'fieldPath'),
      operatorType: DiffRuleOperator.fromWire(json['operator']),
      thresholdValue: _readString(json, 'thresholdValue'),
      severity: DiffAlertSeverity.fromWire(json['severity']),
      notifyEmail: _readBool(json, 'notifyEmail', def: true),
      recipientEmail: _readString(json, 'recipientEmail'),
      enabled: _readBool(json, 'enabled', def: true),
      updatedAt: _readString(json, 'updatedAt'),
    );
  }
}

@immutable
class ExternalDiffAlertEvent {
  const ExternalDiffAlertEvent({
    required this.id,
    required this.title,
    required this.status,
    required this.severity,
    required this.sourceKey,
    required this.ruleId,
    required this.ruleName,
    required this.diffSummary,
    required this.changedFields,
    required this.emailStatus,
    required this.emailRecipientMasked,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final DiffAlertSeverity severity;
  final String sourceKey;
  final String ruleId;
  final String ruleName;
  final String diffSummary;
  final List<String> changedFields;
  final String emailStatus;
  final String emailRecipientMasked;
  final String createdAt;

  bool get isAcknowledged => status == 'cancelled';

  factory ExternalDiffAlertEvent.fromJson(Map<String, Object?> json) {
    return ExternalDiffAlertEvent(
      id: _requireNonEmptyString(json, 'id'),
      title: _requireNonEmptyString(json, 'title'),
      status: _readString(json, 'status', def: 'completed'),
      severity: DiffAlertSeverity.fromWire(json['severity']),
      sourceKey: _readString(json, 'sourceKey'),
      ruleId: _readString(json, 'ruleId'),
      ruleName: _readString(json, 'ruleName'),
      diffSummary: _readString(json, 'diffSummary'),
      changedFields: _readStringList(json, 'changedFields'),
      emailStatus: _readString(json, 'emailStatus', def: 'none'),
      emailRecipientMasked: _readString(json, 'emailRecipientMasked'),
      createdAt: _readString(json, 'createdAt'),
    );
  }
}

@immutable
class ExternalSnapshotSummary {
  const ExternalSnapshotSummary({
    required this.id,
    required this.sourceKey,
    required this.sourceLabel,
    required this.payloadHash,
    required this.fetchedAt,
  });

  final String id;
  final String sourceKey;
  final String sourceLabel;
  final String payloadHash;
  final String fetchedAt;

  factory ExternalSnapshotSummary.fromJson(Map<String, Object?> json) {
    return ExternalSnapshotSummary(
      id: _requireNonEmptyString(json, 'id'),
      sourceKey: _requireNonEmptyString(json, 'sourceKey'),
      sourceLabel: _readString(json, 'sourceLabel'),
      payloadHash: _readString(json, 'payloadHash'),
      fetchedAt: _readString(json, 'fetchedAt'),
    );
  }
}

@immutable
class ExternalDiffDashboardSnapshot {
  const ExternalDiffDashboardSnapshot({
    required this.alerts,
    required this.rules,
    required this.snapshots,
  });

  final List<ExternalDiffAlertEvent> alerts;
  final List<ExternalDiffRule> rules;
  final List<ExternalSnapshotSummary> snapshots;

  factory ExternalDiffDashboardSnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawAlerts = json['alerts'];
    final Object? rawRules = json['rules'];
    final Object? rawSnapshots = json['snapshots'];
    if (rawAlerts is! List<Object?> ||
        rawRules is! List<Object?> ||
        rawSnapshots is! List<Object?>) {
      throw const FormatException('Invalid dashboard snapshot list fields.');
    }

    final alerts = rawAlerts
        .map(
          (item) => ExternalDiffAlertEvent.fromJson(
            normalizeJsonObject(item, 'alerts[]'),
          ),
        )
        .toList(growable: false);
    final rules = rawRules
        .map(
          (item) => ExternalDiffRule.fromJson(
            normalizeJsonObject(item, 'rules[]'),
          ),
        )
        .toList(growable: false);
    final snapshots = rawSnapshots
        .map(
          (item) => ExternalSnapshotSummary.fromJson(
            normalizeJsonObject(item, 'snapshots[]'),
          ),
        )
        .toList(growable: false);

    return ExternalDiffDashboardSnapshot(
      alerts: List<ExternalDiffAlertEvent>.unmodifiable(alerts),
      rules: List<ExternalDiffRule>.unmodifiable(rules),
      snapshots: List<ExternalSnapshotSummary>.unmodifiable(snapshots),
    );
  }
}

@immutable
class SnapshotDetectOutcome {
  const SnapshotDetectOutcome({
    required this.sourceKey,
    required this.baselineInitialized,
    required this.diffCount,
    required this.alertsTriggered,
  });

  final String sourceKey;
  final bool baselineInitialized;
  final int diffCount;
  final int alertsTriggered;

  factory SnapshotDetectOutcome.fromJson(Map<String, Object?> json) {
    final Object? rawDiffCount = json['diff_count'];
    final Object? rawAlertCount = json['alerts_triggered'];
    if (rawDiffCount is! int || rawAlertCount is! int) {
      throw const FormatException('Missing numeric diff/alert counts.');
    }
    return SnapshotDetectOutcome(
      sourceKey: _requireNonEmptyString(json, 'source_key'),
      baselineInitialized: _readBool(json, 'baseline_initialized'),
      diffCount: rawDiffCount,
      alertsTriggered: rawAlertCount,
    );
  }
}

abstract interface class ExternalDiffAlertRepository {
  Future<ExternalDiffDashboardSnapshot> fetchDashboard({int limit = 30});

  Future<ExternalDiffRule> upsertRule({
    required String ruleName,
    required String sourceKey,
    required String fieldPath,
    required DiffRuleOperator operatorType,
    required String thresholdValue,
    required DiffAlertSeverity severity,
    required bool notifyEmail,
    required String recipientEmail,
  });

  Future<SnapshotDetectOutcome> runSnapshotDetect({
    required String sourceKey,
    required Map<String, Object?> payload,
    bool dryRun = false,
  });

  Future<void> acknowledgeAlert(String alertId);

  bool subscribeToAlerts(void Function() onRealtimeAlert);

  Future<void> disposeSubscription();
}

enum AssetLiabilitySyncAuditType {
  preview('preview'),
  manualSync('manual_sync'),
  uploadCandidate('upload_candidate'),
  downloadCandidate('download_candidate'),
  conflictDetected('conflict_detected'),
  conflictResolved('conflict_resolved'),
  failed('failed'),
  success('success');

  final String storageKey;

  const AssetLiabilitySyncAuditType(this.storageKey);

  static AssetLiabilitySyncAuditType fromStorageKey(String value) {
    for (final type in values) {
      if (type.storageKey == value) {
        return type;
      }
    }
    return AssetLiabilitySyncAuditType.preview;
  }
}

class AssetLiabilitySyncAuditLog {
  final String id;
  final DateTime executedAt;
  final AssetLiabilitySyncAuditType type;
  final String monthKey;
  final String targetDataType;
  final int count;
  final String result;
  final String? errorMessage;

  const AssetLiabilitySyncAuditLog({
    required this.id,
    required this.executedAt,
    required this.type,
    required this.monthKey,
    required this.targetDataType,
    required this.count,
    required this.result,
    this.errorMessage,
  });

  factory AssetLiabilitySyncAuditLog.create({
    required AssetLiabilitySyncAuditType type,
    required String monthKey,
    required String targetDataType,
    required int count,
    required String result,
    String? errorMessage,
    DateTime? executedAt,
  }) {
    final timestamp = (executedAt ?? DateTime.now()).toUtc();
    return AssetLiabilitySyncAuditLog(
      id: '${timestamp.microsecondsSinceEpoch}_${type.storageKey}_$monthKey',
      executedAt: timestamp,
      type: type,
      monthKey: monthKey,
      targetDataType:
          targetDataType.trim().isEmpty ? 'unknown' : targetDataType.trim(),
      count: count < 0 ? 0 : count,
      result: result.trim().isEmpty ? 'unknown' : result.trim(),
      errorMessage: _cleanNullableString(errorMessage),
    );
  }

  factory AssetLiabilitySyncAuditLog.fromJson(Map<String, Object?> json) {
    final executedAt = DateTime.tryParse(
          json['executedAt']?.toString() ??
              json['executed_at']?.toString() ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final type = AssetLiabilitySyncAuditType.fromStorageKey(
      json['type']?.toString() ?? '',
    );
    return AssetLiabilitySyncAuditLog(
      id: _cleanString(json['id']) ??
          '${executedAt.microsecondsSinceEpoch}_${type.storageKey}',
      executedAt: executedAt.toUtc(),
      type: type,
      monthKey: _cleanString(json['monthKey']) ??
          _cleanString(json['month_key']) ??
          '',
      targetDataType: _cleanString(json['targetDataType']) ??
          _cleanString(json['target_data_type']) ??
          'unknown',
      count: _parseInt(json['count']) ?? 0,
      result: _cleanString(json['result']) ?? 'unknown',
      errorMessage: _cleanNullableString(
        json['errorMessage'] ?? json['error_message'],
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'executedAt': executedAt.toUtc().toIso8601String(),
      'type': type.storageKey,
      'monthKey': monthKey,
      'targetDataType': targetDataType,
      'count': count,
      'result': result,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  bool get isFailure => type == AssetLiabilitySyncAuditType.failed;

  bool get isConflict =>
      type == AssetLiabilitySyncAuditType.conflictDetected ||
      result.contains('conflict');
}

class AssetLiabilitySyncAuditLogTablePlan {
  static const String tableName = 'asset_liability_sync_audit_logs';

  static const List<String> futureSupabaseColumns = <String>[
    'id',
    'user_id',
    'month_key',
    'executed_at',
    'sync_type',
    'target_data_type',
    'target_count',
    'result',
    'error_message',
    'payload',
    'created_at',
    'updated_at',
  ];

  const AssetLiabilitySyncAuditLogTablePlan._();
}

String? _cleanString(Object? source) {
  final value = source?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _cleanNullableString(Object? source) {
  final value = _cleanString(source);
  return value == null || value.isEmpty ? null : value;
}

int? _parseInt(Object? source) {
  if (source is num) {
    return source.toInt();
  }
  if (source == null) {
    return null;
  }
  return int.tryParse(source.toString());
}

import 'package:supabase_flutter/supabase_flutter.dart';

/// 管理者が実行するシステム変更種別 (#2617)。
enum AdminActionType {
  rlsPolicyUpdate('rls_policy_update', 'RLSポリシー更新'),
  schemaMigration('schema_migration', 'DBスキーマ変更'),
  featureFlagToggle('feature_flag_toggle', '機能フラグ切替'),
  quotaOverride('quota_override', 'クォータ上限調整'),
  userPrivilegeChange('user_privilege_change', '管理者権限変更'),
  dataBackfill('data_backfill', '一括データ補正'),
  configChange('config_change', 'システム設定変更');

  const AdminActionType(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static AdminActionType parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final value in AdminActionType.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AdminActionType.configChange;
  }
}

/// 変更影響のリスクレベル (#2617)。
enum AdminActionRiskLevel {
  low('low', 'Low', 20, false),
  medium('medium', 'Medium', 50, true),
  high('high', 'High', 75, true),
  critical('critical', 'Critical', 95, true);

  const AdminActionRiskLevel(
    this.wireValue,
    this.label,
    this.defaultScore,
    this.requiresExplicitMitigation,
  );

  final String wireValue;
  final String label;
  final int defaultScore;
  final bool requiresExplicitMitigation;

  static AdminActionRiskLevel parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final value in AdminActionRiskLevel.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AdminActionRiskLevel.medium;
  }
}

/// 影響評価ワークフローの状態 (#2617)。
enum AdminAssessmentStatus {
  pendingReview('pending_review', '確認待ち'),
  approved('approved', '影響承認済み'),
  executed('executed', '実行完了'),
  cancelled('cancelled', '取消');

  const AdminAssessmentStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static AdminAssessmentStatus parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final value in AdminAssessmentStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AdminAssessmentStatus.pendingReview;
  }
}

/// トリガー記録される監査操作種別 (#2617)。
enum AdminAuditOperation {
  insert('INSERT', '起票'),
  update('UPDATE', '更新'),
  approve('APPROVE', '事前承認'),
  execute('EXECUTE', '実行記録'),
  cancel('CANCEL', '取消');

  const AdminAuditOperation(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static AdminAuditOperation parse(Object? raw) {
    final normalized = raw?.toString().trim().toUpperCase() ?? '';
    for (final value in AdminAuditOperation.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AdminAuditOperation.update;
  }
}

/// 変更前リスク・影響評価の決定論的結果 (#2617)。
class AdminImpactEvaluationResult {
  const AdminImpactEvaluationResult({
    required this.riskLevel,
    required this.riskScore,
    required this.requiresPreConfirmation,
    required this.warnings,
    required this.recommendedMitigation,
  });

  final AdminActionRiskLevel riskLevel;
  final int riskScore;
  final bool requiresPreConfirmation;
  final List<String> warnings;
  final String recommendedMitigation;
}

/// 重大システム変更前の決定論的リスク・影響評価ロジック (#2617)。
class AdminActionImpactEvaluator {
  const AdminActionImpactEvaluator._();

  static const List<String> _criticalKeywords = <String>[
    'auth.users',
    'user_profiles',
    'production',
    'drop ',
    'truncate',
    'delete ',
    'revoke',
    'service_role',
    'billing',
    'financial',
  ];

  static const List<String> _elevatedKeywords = <String>[
    'rls',
    'policy',
    'migration',
    'trigger',
    'schema',
    'admin',
    'quota',
    'oauth',
    'backfill',
  ];

  static AdminImpactEvaluationResult evaluate({
    required AdminActionType actionType,
    required String targetResource,
    required String changeSummary,
    String expectedImpactScope = '',
    String mitigationPlan = '',
  }) {
    final combined =
        '$targetResource $changeSummary $expectedImpactScope'.toLowerCase();
    var score = switch (actionType) {
      AdminActionType.userPrivilegeChange => 78,
      AdminActionType.rlsPolicyUpdate => 72,
      AdminActionType.schemaMigration => 68,
      AdminActionType.dataBackfill => 62,
      AdminActionType.quotaOverride => 50,
      AdminActionType.featureFlagToggle => 38,
      AdminActionType.configChange => 25,
    };

    final warnings = <String>[];
    var hitCritical = false;
    for (final kw in _criticalKeywords) {
      if (combined.contains(kw)) {
        hitCritical = true;
        score += 18;
        warnings.add('高重要度領域 ($kw) への変更が含まれます。');
        break;
      }
    }

    for (final kw in _elevatedKeywords) {
      if (combined.contains(kw)) {
        score += 10;
        break;
      }
    }

    if (expectedImpactScope.trim().isEmpty) {
      score += 8;
      warnings.add('想定影響範囲が未記入のため、事前影響調査が必要です。');
    }

    final clampedScore = score.clamp(0, 100);
    final AdminActionRiskLevel riskLevel;
    if (hitCritical || clampedScore >= 85) {
      riskLevel = AdminActionRiskLevel.critical;
    } else if (clampedScore >= 65) {
      riskLevel = AdminActionRiskLevel.high;
    } else if (clampedScore >= 40) {
      riskLevel = AdminActionRiskLevel.medium;
    } else {
      riskLevel = AdminActionRiskLevel.low;
    }

    if (riskLevel.requiresExplicitMitigation && mitigationPlan.trim().isEmpty) {
      warnings.add('Medium 以上の変更には復旧・緩和策の明記を推奨します。');
    }

    final recommendedMitigation = switch (riskLevel) {
      AdminActionRiskLevel.critical =>
        '事前バックアップ確認・ロールバックSQL準備・ステージング検証を実施してください。',
      AdminActionRiskLevel.high => '影響ユーザー範囲の特定と切り戻し手順を確認してから承認してください。',
      AdminActionRiskLevel.medium => '変更前後の差分と対象レコード件数を記録してください。',
      AdminActionRiskLevel.low => '通常の監査ログ記録のみで実行可能です。',
    };

    return AdminImpactEvaluationResult(
      riskLevel: riskLevel,
      riskScore: clampedScore,
      requiresPreConfirmation:
          riskLevel != AdminActionRiskLevel.low || clampedScore >= 30,
      warnings: List<String>.unmodifiable(warnings),
      recommendedMitigation: recommendedMitigation,
    );
  }
}

/// 変更前影響評価レコード (#2617)。
class AdminImpactAssessment {
  const AdminImpactAssessment({
    required this.id,
    required this.actorUserId,
    required this.actionType,
    required this.targetResource,
    required this.changeSummary,
    required this.expectedImpactScope,
    required this.riskLevel,
    required this.riskScore,
    required this.mitigationPlan,
    required this.requiresPreConfirmation,
    required this.impactConfirmed,
    required this.status,
    required this.approvedBy,
    required this.approvedAt,
    required this.executedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminImpactAssessment.fromJson(Map<String, Object?> json) {
    final parsedScore = switch (json['risk_score']) {
      final int v => v,
      final num v => v.toInt(),
      _ => int.tryParse(json['risk_score']?.toString() ?? '') ?? 0,
    };
    return AdminImpactAssessment(
      id: json['id']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actionType: AdminActionType.parse(json['action_type']),
      targetResource: json['target_resource']?.toString() ?? '',
      changeSummary: json['change_summary']?.toString() ?? '',
      expectedImpactScope: json['expected_impact_scope']?.toString() ?? '',
      riskLevel: AdminActionRiskLevel.parse(json['risk_level']),
      riskScore: parsedScore.clamp(0, 100),
      mitigationPlan: json['mitigation_plan']?.toString() ?? '',
      requiresPreConfirmation: json['requires_pre_confirmation'] != false,
      impactConfirmed: json['impact_confirmed'] == true,
      status: AdminAssessmentStatus.parse(json['status']),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: _parseUtcDate(json['approved_at']),
      executedAt: _parseUtcDate(json['executed_at']),
      createdAt: _parseUtcDate(json['created_at']),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }

  final String id;
  final String actorUserId;
  final AdminActionType actionType;
  final String targetResource;
  final String changeSummary;
  final String expectedImpactScope;
  final AdminActionRiskLevel riskLevel;
  final int riskScore;
  final String mitigationPlan;
  final bool requiresPreConfirmation;
  final bool impactConfirmed;
  final AdminAssessmentStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? executedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// append-only 監査ログエントリ (#2617)。
class AdminActionAuditLogEntry {
  const AdminActionAuditLogEntry({
    required this.id,
    required this.assessmentId,
    required this.actorUserId,
    required this.actorRole,
    required this.actionType,
    required this.targetTable,
    required this.targetResource,
    required this.operation,
    required this.riskLevel,
    required this.impactSummary,
    required this.preState,
    required this.postState,
    required this.impactConfirmed,
    required this.createdAt,
  });

  factory AdminActionAuditLogEntry.fromJson(Map<String, Object?> json) {
    return AdminActionAuditLogEntry(
      id: json['id']?.toString() ?? '',
      assessmentId: json['assessment_id']?.toString(),
      actorUserId: json['actor_user_id']?.toString(),
      actorRole: json['actor_role']?.toString() ?? 'admin',
      actionType: AdminActionType.parse(json['action_type']),
      targetTable:
          json['target_table']?.toString() ?? 'admin_impact_assessments',
      targetResource: json['target_resource']?.toString() ?? '',
      operation: AdminAuditOperation.parse(json['operation']),
      riskLevel: AdminActionRiskLevel.parse(json['risk_level']),
      impactSummary: json['impact_summary']?.toString() ?? '',
      preState: _asStringMap(json['pre_state']),
      postState: _asStringMap(json['post_state']),
      impactConfirmed: json['impact_confirmed'] == true,
      createdAt: _parseUtcDate(json['created_at']),
    );
  }

  final String id;
  final String? assessmentId;
  final String? actorUserId;
  final String actorRole;
  final AdminActionType actionType;
  final String targetTable;
  final String targetResource;
  final AdminAuditOperation operation;
  final AdminActionRiskLevel riskLevel;
  final String impactSummary;
  final Map<String, Object?> preState;
  final Map<String, Object?> postState;
  final bool impactConfirmed;
  final DateTime? createdAt;
}

/// 監査ログ閲覧フィルタ (#2617)。
class AdminAuditFilter {
  const AdminAuditFilter({
    this.actionType,
    this.riskLevel,
    this.operation,
    this.searchQuery = '',
  });

  final AdminActionType? actionType;
  final AdminActionRiskLevel? riskLevel;
  final AdminAuditOperation? operation;
  final String searchQuery;

  AdminAuditFilter copyWith({
    AdminActionType? actionType,
    bool clearActionType = false,
    AdminActionRiskLevel? riskLevel,
    bool clearRiskLevel = false,
    AdminAuditOperation? operation,
    bool clearOperation = false,
    String? searchQuery,
  }) {
    return AdminAuditFilter(
      actionType: clearActionType ? null : (actionType ?? this.actionType),
      riskLevel: clearRiskLevel ? null : (riskLevel ?? this.riskLevel),
      operation: clearOperation ? null : (operation ?? this.operation),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<AdminActionAuditLogEntry> apply(
    List<AdminActionAuditLogEntry> entries,
  ) {
    final query = searchQuery.trim().toLowerCase();
    return entries.where((entry) {
      if (actionType != null && entry.actionType != actionType) {
        return false;
      }
      if (riskLevel != null && entry.riskLevel != riskLevel) {
        return false;
      }
      if (operation != null && entry.operation != operation) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = '${entry.targetResource} ${entry.impactSummary} '
                '${entry.actionType.wireValue} ${entry.actionType.labelJa} '
                '${entry.operation.wireValue} ${entry.actorRole}'
            .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }
}

/// 監査ログ・影響評価サマリー (#2617)。
class AdminAuditSummary {
  const AdminAuditSummary({
    required this.totalLogs,
    required this.highOrCriticalCount,
    required this.pendingAssessmentCount,
    required this.executedCount,
    required this.confirmedLogCount,
  });

  final int totalLogs;
  final int highOrCriticalCount;
  final int pendingAssessmentCount;
  final int executedCount;
  final int confirmedLogCount;

  static AdminAuditSummary compute({
    required List<AdminActionAuditLogEntry> logs,
    required List<AdminImpactAssessment> assessments,
  }) {
    var highOrCritical = 0;
    var confirmed = 0;
    var executed = 0;
    for (final log in logs) {
      if (log.riskLevel == AdminActionRiskLevel.high ||
          log.riskLevel == AdminActionRiskLevel.critical) {
        highOrCritical += 1;
      }
      if (log.impactConfirmed) {
        confirmed += 1;
      }
      if (log.operation == AdminAuditOperation.execute) {
        executed += 1;
      }
    }
    var pending = 0;
    for (final assessment in assessments) {
      if (assessment.status == AdminAssessmentStatus.pendingReview) {
        pending += 1;
      }
    }
    return AdminAuditSummary(
      totalLogs: logs.length,
      highOrCriticalCount: highOrCritical,
      pendingAssessmentCount: pending,
      executedCount: executed,
      confirmedLogCount: confirmed,
    );
  }
}

abstract class AdminActionAuditRepository {
  Future<List<AdminActionAuditLogEntry>> listAuditLogs({int limit = 100});

  Future<List<AdminImpactAssessment>> listAssessments({int limit = 50});

  Future<AdminImpactAssessment> createImpactAssessment({
    required AdminActionType actionType,
    required String targetResource,
    required String changeSummary,
    String expectedImpactScope = '',
    String mitigationPlan = '',
  });

  Future<AdminImpactAssessment> confirmAndApproveAssessment({
    required String id,
    required bool impactConfirmed,
    String mitigationPlan = '',
  });

  Future<AdminImpactAssessment> executeApprovedAssessment({
    required String id,
  });
}

typedef AdminAuditSupabaseClientResolver = SupabaseClient Function();

/// `admin_action_audit_logs` / `admin_impact_assessments` 遅延解決リポジトリ (#2617)。
class SupabaseAdminActionAuditRepository implements AdminActionAuditRepository {
  SupabaseAdminActionAuditRepository({
    SupabaseClient? client,
    AdminAuditSupabaseClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final AdminAuditSupabaseClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<AdminActionAuditLogEntry>> listAuditLogs({
    int limit = 100,
  }) async {
    final rows = await _resolvedClient
        .from('admin_action_audit_logs')
        .select(
          'id, assessment_id, actor_user_id, actor_role, action_type, '
          'target_table, target_resource, operation, risk_level, '
          'impact_summary, pre_state, post_state, impact_confirmed, created_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return _extractRows(rows)
        .map(AdminActionAuditLogEntry.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<AdminImpactAssessment>> listAssessments({
    int limit = 50,
  }) async {
    final rows = await _resolvedClient
        .from('admin_impact_assessments')
        .select(
          'id, actor_user_id, action_type, target_resource, change_summary, '
          'expected_impact_scope, risk_level, risk_score, mitigation_plan, '
          'requires_pre_confirmation, impact_confirmed, status, approved_by, '
          'approved_at, executed_at, created_at, updated_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return _extractRows(rows)
        .map(AdminImpactAssessment.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AdminImpactAssessment> createImpactAssessment({
    required AdminActionType actionType,
    required String targetResource,
    required String changeSummary,
    String expectedImpactScope = '',
    String mitigationPlan = '',
  }) async {
    final cleanTarget = targetResource.trim();
    final cleanSummary = changeSummary.trim();
    if (cleanTarget.isEmpty || cleanSummary.isEmpty) {
      throw ArgumentError('対象リソースと変更内容サマリーは必須です');
    }
    final actorId = _resolvedClient.auth.currentUser?.id;
    if (actorId == null || actorId.isEmpty) {
      throw StateError('影響評価の起票には管理者ログインが必要です');
    }
    final evaluation = AdminActionImpactEvaluator.evaluate(
      actionType: actionType,
      targetResource: cleanTarget,
      changeSummary: cleanSummary,
      expectedImpactScope: expectedImpactScope,
      mitigationPlan: mitigationPlan,
    );
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final inserted = await _resolvedClient
        .from('admin_impact_assessments')
        .insert(<String, Object?>{
          'actor_user_id': actorId,
          'action_type': actionType.wireValue,
          'target_resource': cleanTarget,
          'change_summary': cleanSummary,
          'expected_impact_scope': expectedImpactScope.trim(),
          'risk_level': evaluation.riskLevel.wireValue,
          'risk_score': evaluation.riskScore,
          'mitigation_plan': mitigationPlan.trim(),
          'requires_pre_confirmation': evaluation.requiresPreConfirmation,
          'impact_confirmed': false,
          'status': AdminAssessmentStatus.pendingReview.wireValue,
          'updated_at': nowIso,
        })
        .select()
        .single();
    return AdminImpactAssessment.fromJson(_asStringMap(inserted));
  }

  @override
  Future<AdminImpactAssessment> confirmAndApproveAssessment({
    required String id,
    required bool impactConfirmed,
    String mitigationPlan = '',
  }) async {
    if (!impactConfirmed) {
      throw StateError('変更承認の前に影響範囲・リスクの明示的確認が必要です');
    }
    final adminId = _resolvedClient.auth.currentUser?.id;
    if (adminId == null || adminId.isEmpty) {
      throw StateError('影響評価の承認には管理者ログインが必要です');
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'impact_confirmed': true,
      'status': AdminAssessmentStatus.approved.wireValue,
      'approved_by': adminId,
      'approved_at': nowIso,
      'updated_at': nowIso,
      if (mitigationPlan.trim().isNotEmpty)
        'mitigation_plan': mitigationPlan.trim(),
    };
    final updated = await _resolvedClient
        .from('admin_impact_assessments')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return AdminImpactAssessment.fromJson(_asStringMap(updated));
  }

  @override
  Future<AdminImpactAssessment> executeApprovedAssessment({
    required String id,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updated = await _resolvedClient
        .from('admin_impact_assessments')
        .update(<String, Object?>{
          'status': AdminAssessmentStatus.executed.wireValue,
          'executed_at': nowIso,
          'updated_at': nowIso,
        })
        .eq('id', id)
        .select()
        .single();
    return AdminImpactAssessment.fromJson(_asStringMap(updated));
  }
}

List<Map<String, Object?>> _extractRows(Object? raw) {
  if (raw is! List<Object?>) {
    return const <Map<String, Object?>>[];
  }
  return raw
      .whereType<Map<Object?, Object?>>()
      .map(_asStringMap)
      .toList(growable: false);
}

Map<String, Object?> _asStringMap(Object? raw) {
  final result = <String, Object?>{};
  if (raw is Map<Object?, Object?>) {
    raw.forEach((key, value) {
      result[key.toString()] = value;
    });
  }
  return result;
}

DateTime? _parseUtcDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}

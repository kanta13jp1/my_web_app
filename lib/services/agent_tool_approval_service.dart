import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AgentToolApprovalDecision {
  approved,
  rejected,
}

class AgentToolApprovalLog {
  final String id;
  final String toolName;
  final String? actorRole;
  final bool allowed;
  final bool requiresApproval;
  final String? approvalDecision;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? blockedReason;
  final String? sideEffects;
  final List<String> requestedScopes;
  final List<String> allowedScopes;
  final List<String> highRiskScopes;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? evaluatedAt;

  const AgentToolApprovalLog({
    required this.id,
    required this.toolName,
    required this.actorRole,
    required this.allowed,
    required this.requiresApproval,
    required this.approvalDecision,
    required this.approvedBy,
    required this.approvedAt,
    required this.blockedReason,
    required this.sideEffects,
    required this.requestedScopes,
    required this.allowedScopes,
    required this.highRiskScopes,
    required this.payload,
    required this.createdAt,
    required this.evaluatedAt,
  });

  factory AgentToolApprovalLog.fromMap(Map<String, dynamic> row) {
    return AgentToolApprovalLog(
      id: row['id']?.toString() ?? '',
      toolName: row['tool_name']?.toString() ?? 'unknown_tool',
      actorRole: _nullableString(row['actor_role']),
      allowed: _toBool(row['allowed']),
      requiresApproval: _toBool(row['requires_approval']),
      approvalDecision: _nullableString(row['approval_decision']),
      approvedBy: _nullableString(row['approved_by']),
      approvedAt: _parseDate(row['approved_at']),
      blockedReason: _nullableString(row['blocked_reason']),
      sideEffects: _nullableString(row['side_effects']),
      requestedScopes: _stringList(row['requested_scopes']),
      allowedScopes: _stringList(row['allowed_scopes']),
      highRiskScopes: _stringList(row['high_risk_scopes']),
      payload: _payloadMap(row['payload']),
      createdAt: _parseDate(row['created_at']),
      evaluatedAt: _parseDate(row['evaluated_at']),
    );
  }

  bool get isPendingApproval {
    final normalized = approvalDecision?.trim().toLowerCase();
    return requiresApproval &&
        !allowed &&
        normalized != 'approved' &&
        normalized != 'rejected';
  }

  bool get isApproved => approvalDecision?.trim().toLowerCase() == 'approved';

  bool get isRejected => approvalDecision?.trim().toLowerCase() == 'rejected';

  String buildApprovalPayloadJson({
    required String approvedBy,
    DateTime? approvedAt,
  }) {
    final timestamp = (approvedAt ?? DateTime.now()).toUtc().toIso8601String();
    return const JsonEncoder.withIndent('  ').convert({
      'tool_name': toolName,
      'requested_scopes': requestedScopes,
      'approval': {
        'decision': 'approved',
        'approved_by': approvedBy,
        'approved_at': timestamp,
      },
    });
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static Map<String, dynamic> _payloadMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class AgentToolApprovalService {
  final SupabaseClient _supabase;

  AgentToolApprovalService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<List<AgentToolApprovalLog>> fetchRecentLogs({int limit = 80}) async {
    final rows = await _supabase
        .from('agent_tool_execution_logs')
        .select(
          'id, actor_role, tool_name, allowed, blocked_reason, payload, '
          'created_at, requested_scopes, allowed_scopes, high_risk_scopes, '
          'requires_approval, approval_decision, approved_by, approved_at, '
          'side_effects, evaluated_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .whereType<Map>()
        .map(
          (row) => AgentToolApprovalLog.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  Future<AgentToolApprovalLog> decide({
    required String logId,
    required AgentToolApprovalDecision decision,
  }) async {
    final user = _supabase.auth.currentUser;
    final actor = user?.email ?? user?.id ?? 'ceo';
    final now = DateTime.now().toUtc().toIso8601String();
    final decisionText = decision.name;

    final row = await _supabase
        .from('agent_tool_execution_logs')
        .update({
          'approval_decision': decisionText,
          'approved_by': actor,
          'approved_at': now,
        })
        .eq('id', logId)
        .select(
          'id, actor_role, tool_name, allowed, blocked_reason, payload, '
          'created_at, requested_scopes, allowed_scopes, high_risk_scopes, '
          'requires_approval, approval_decision, approved_by, approved_at, '
          'side_effects, evaluated_at',
        )
        .single();

    return AgentToolApprovalLog.fromMap(Map<String, dynamic>.from(row));
  }
}

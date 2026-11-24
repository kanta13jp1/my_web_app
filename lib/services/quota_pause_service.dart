import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum QuotaThresholdTier {
  normal('normal', '正常'),
  warning80('warning_80', '80% 警告'),
  paused100('paused_100', '100% 自動停止');

  const QuotaThresholdTier(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

@immutable
class QuotaPauseStateItem {
  const QuotaPauseStateItem({
    required this.tool,
    required this.usagePct,
    required this.warning80Sent,
    required this.autoPaused,
    required this.silentPauseDetected,
    required this.resumedByAdmin,
    this.warning80SentAt,
    this.pausedAt,
    this.resumedAt,
    this.adminIssueNumber,
    this.adminNote = '',
    this.updatedAt,
  });

  final String tool;
  final double usagePct;
  final bool warning80Sent;
  final DateTime? warning80SentAt;
  final bool autoPaused;
  final DateTime? pausedAt;
  final bool silentPauseDetected;
  final bool resumedByAdmin;
  final DateTime? resumedAt;
  final int? adminIssueNumber;
  final String adminNote;
  final DateTime? updatedAt;

  bool get isEffectivePaused => autoPaused && !resumedByAdmin;

  QuotaThresholdTier get tier {
    if (usagePct >= 100.0 || isEffectivePaused) {
      return QuotaThresholdTier.paused100;
    }
    if (usagePct >= 80.0 || warning80Sent) {
      return QuotaThresholdTier.warning80;
    }
    return QuotaThresholdTier.normal;
  }

  factory QuotaPauseStateItem.fromJson(Map<String, Object?> json) {
    final pctRaw = json['usage_pct'];
    final parsedPct = pctRaw is num
        ? pctRaw.toDouble()
        : (double.tryParse(pctRaw?.toString() ?? '') ?? 0.0);
    final issueRaw = json['admin_issue_number'];
    final parsedIssue = issueRaw is num
        ? issueRaw.toInt()
        : int.tryParse(issueRaw?.toString() ?? '');

    return QuotaPauseStateItem(
      tool: (json['tool']?.toString() ?? '').trim().toLowerCase(),
      usagePct: parsedPct < 0 ? 0.0 : parsedPct,
      warning80Sent: json['warning_80_sent'] == true,
      warning80SentAt: _parseUtcDate(json['warning_80_sent_at']),
      autoPaused: json['auto_paused'] == true,
      pausedAt: _parseUtcDate(json['paused_at']),
      silentPauseDetected: json['silent_pause_detected'] == true,
      resumedByAdmin: json['resumed_by_admin'] == true,
      resumedAt: _parseUtcDate(json['resumed_at']),
      adminIssueNumber:
          parsedIssue != null && parsedIssue > 0 ? parsedIssue : null,
      adminNote: (json['admin_note']?.toString() ?? '').trim(),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }
}

@immutable
class QuotaThresholdSummary {
  const QuotaThresholdSummary({
    required this.totalCount,
    required this.normalCount,
    required this.warning80Count,
    required this.paused100Count,
    required this.silentPauseCount,
  });

  final int totalCount;
  final int normalCount;
  final int warning80Count;
  final int paused100Count;
  final int silentPauseCount;

  bool get hasAnyAlert => warning80Count > 0 || paused100Count > 0;

  factory QuotaThresholdSummary.fromItems(List<QuotaPauseStateItem> items) {
    var normal = 0;
    var warning = 0;
    var paused = 0;
    var silent = 0;

    for (final item in items) {
      if (item.silentPauseDetected) {
        silent += 1;
      }
      switch (item.tier) {
        case QuotaThresholdTier.normal:
          normal += 1;
        case QuotaThresholdTier.warning80:
          warning += 1;
        case QuotaThresholdTier.paused100:
          paused += 1;
      }
    }

    return QuotaThresholdSummary(
      totalCount: items.length,
      normalCount: normal,
      warning80Count: warning,
      paused100Count: paused,
      silentPauseCount: silent,
    );
  }
}

abstract class QuotaPauseRepository {
  Future<List<QuotaPauseStateItem>> listPauseStates();

  Future<QuotaPauseStateItem> resumeTool({
    required String tool,
    String adminNote = '',
  });
}

typedef QuotaSupabaseClientResolver = SupabaseClient Function();

/// `ai_quota_pause_state` テーブルへの遅延解決 Supabase リポジトリ (#2612)。
class SupabaseQuotaPauseRepository implements QuotaPauseRepository {
  SupabaseQuotaPauseRepository({
    SupabaseClient? client,
    QuotaSupabaseClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final QuotaSupabaseClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<QuotaPauseStateItem>> listPauseStates() async {
    final rows = await _resolvedClient
        .from('ai_quota_pause_state')
        .select(
          'tool, usage_pct, warning_80_sent, warning_80_sent_at, '
          'auto_paused, paused_at, silent_pause_detected, resumed_by_admin, '
          'resumed_at, admin_issue_number, admin_note, updated_at',
        )
        .order('usage_pct', ascending: false);
    return _extractRows(rows)
        .map(QuotaPauseStateItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<QuotaPauseStateItem> resumeTool({
    required String tool,
    String adminNote = '',
  }) async {
    final adminId = _resolvedClient.auth.currentUser?.id;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'auto_paused': false,
      'resumed_by_admin': true,
      'resumed_at': nowIso,
      'admin_note': adminNote.trim(),
      'updated_at': nowIso,
      if (adminId != null && adminId.isNotEmpty) 'resumed_by': adminId,
    };
    final updated = await _resolvedClient
        .from('ai_quota_pause_state')
        .update(payload)
        .eq('tool', tool.trim().toLowerCase())
        .select()
        .single();
    return QuotaPauseStateItem.fromJson(_asStringMap(updated));
  }
}

List<Map<String, Object?>> _extractRows(Object? raw) {
  if (raw is! List<Object?>) return const <Map<String, Object?>>[];
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
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// カテゴリ別の競合発掘 API 実行記録 (#2696)。
@immutable
class CompetitorDiscoveryQueryLog {
  const CompetitorDiscoveryQueryLog({
    required this.category,
    required this.promptPreview,
    required this.candidateCount,
    this.httpStatus,
    this.responseExcerpt = '',
    this.error,
  });

  final String category;
  final String promptPreview;
  final int candidateCount;
  final int? httpStatus;
  final String responseExcerpt;
  final String? error;

  factory CompetitorDiscoveryQueryLog.fromJson(Map<String, dynamic> json) {
    final errRaw = json['error']?.toString().trim();
    return CompetitorDiscoveryQueryLog(
      category: (json['category'] as String?)?.trim() ?? '',
      promptPreview: (json['prompt_preview'] as String?)?.trim() ?? '',
      candidateCount: _asInt(json['candidate_count']) ?? 0,
      httpStatus: _asInt(json['http_status']),
      responseExcerpt: (json['response_excerpt'] as String?)?.trim() ?? '',
      error: (errRaw == null || errRaw.isEmpty) ? null : errRaw,
    );
  }
}

/// 競合発掘ワークフロー 1 回分のログエントリ (#2696)。
@immutable
class CompetitorDiscoveryLogEntry {
  const CompetitorDiscoveryLogEntry({
    required this.id,
    required this.discoveryWeek,
    required this.categories,
    required this.queries,
    required this.totalCandidates,
    required this.stagedCount,
    required this.skipCount,
    required this.errorCount,
    required this.errorLogs,
    required this.zeroResultAlertTriggered,
    this.runId,
    this.alertSummary,
    this.createdAt,
  });

  final String id;
  final String discoveryWeek;
  final String? runId;
  final List<String> categories;
  final List<CompetitorDiscoveryQueryLog> queries;
  final int totalCandidates;
  final int stagedCount;
  final int skipCount;
  final int errorCount;
  final List<String> errorLogs;
  final bool zeroResultAlertTriggered;
  final String? alertSummary;
  final DateTime? createdAt;

  bool matchesQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (discoveryWeek.toLowerCase().contains(q)) return true;
    if ((runId ?? '').toLowerCase().contains(q)) return true;
    if ((alertSummary ?? '').toLowerCase().contains(q)) return true;
    if (categories.any((c) => c.toLowerCase().contains(q))) return true;
    if (errorLogs.any((e) => e.toLowerCase().contains(q))) return true;
    return queries.any(
      (item) =>
          item.category.toLowerCase().contains(q) ||
          item.promptPreview.toLowerCase().contains(q) ||
          item.responseExcerpt.toLowerCase().contains(q) ||
          (item.error ?? '').toLowerCase().contains(q),
    );
  }

  factory CompetitorDiscoveryLogEntry.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categories = rawCategories is List
        ? rawCategories
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawQueries = json['queries_json'];
    final queries = rawQueries is List
        ? rawQueries
            .whereType<Map>()
            .map(
              (m) => CompetitorDiscoveryQueryLog.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList(growable: false)
        : const <CompetitorDiscoveryQueryLog>[];

    final rawErrors = json['error_logs'];
    final errorLogs = rawErrors is List
        ? rawErrors
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final createdAtRaw = json['created_at']?.toString();
    return CompetitorDiscoveryLogEntry(
      id: json['id']?.toString() ?? '',
      discoveryWeek: (json['discovery_week'] as String?)?.trim() ?? '',
      runId: (json['run_id'] as String?)?.trim(),
      categories: List<String>.unmodifiable(categories),
      queries: List<CompetitorDiscoveryQueryLog>.unmodifiable(queries),
      totalCandidates: _asInt(json['total_candidates']) ?? 0,
      stagedCount: _asInt(json['staged_count']) ?? 0,
      skipCount: _asInt(json['skip_count']) ?? 0,
      errorCount: _asInt(json['error_count']) ?? 0,
      errorLogs: List<String>.unmodifiable(errorLogs),
      zeroResultAlertTriggered: json['zero_result_alert_triggered'] == true,
      alertSummary: (json['alert_summary'] as String?)?.trim(),
      createdAt: createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw)?.toUtc(),
    );
  }
}

typedef CompetitorDiscoveryLogFetcher = Future<List<Map<String, dynamic>>>
    Function({int limit});

/// `competitor_discovery_logs` テーブルから競合発掘実行ログを取得・検索するサービス (#2696)。
class CompetitorDiscoveryLogService {
  const CompetitorDiscoveryLogService({
    CompetitorDiscoveryLogFetcher? fetcher,
  }) : _fetcher = fetcher;

  final CompetitorDiscoveryLogFetcher? _fetcher;

  static Future<List<Map<String, dynamic>>> _defaultFetch({
    int limit = 30,
  }) async {
    final rows = await Supabase.instance.client
        .from('competitor_discovery_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<CompetitorDiscoveryLogEntry>> fetchLogs({
    int limit = 30,
  }) async {
    final fetcher = _fetcher ?? _defaultFetch;
    final rows = await fetcher(limit: limit);
    return rows
        .map(CompetitorDiscoveryLogEntry.fromJson)
        .toList(growable: false);
  }

  static List<CompetitorDiscoveryLogEntry> filterLogs(
    List<CompetitorDiscoveryLogEntry> entries, {
    String query = '',
    bool onlyZeroResultAlerts = false,
  }) {
    return entries.where((entry) {
      if (onlyZeroResultAlerts && !entry.zeroResultAlertTriggered) {
        return false;
      }
      return entry.matchesQuery(query);
    }).toList(growable: false);
  }
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

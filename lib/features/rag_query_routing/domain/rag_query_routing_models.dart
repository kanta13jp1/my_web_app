import 'package:flutter/foundation.dart';

/// State classified from an LLM Pleias-style `<|query_report_start|>` block.
enum QueryReportState {
  trivial('trivial', 'そのまま検索 (trivial)'),
  reformulated('reformulated', '自動再定式化 (reformulated)'),
  unclear('unclear', '明確化が必要 (unclear)'),
  unknown('unknown', '判定不明 (unknown)');

  const QueryReportState(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static QueryReportState fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in QueryReportState.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return QueryReportState.unknown;
  }
}

/// Routing branch selected by `memory-search-hub` (`memory.query_route`).
enum QueryRouteAction {
  search('search', '検索実行'),
  clarify('clarify', '推論中断・再質問');

  const QueryRouteAction(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static QueryRouteAction fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in QueryRouteAction.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return QueryRouteAction.search;
  }
}

@immutable
class ParsedQueryReport {
  const ParsedQueryReport({
    required this.state,
    this.reformulatedQuery,
    this.reason,
  });

  final QueryReportState state;
  final String? reformulatedQuery;
  final String? reason;

  factory ParsedQueryReport.fromJson(final Map<String, Object?> json) {
    final reformulated = (json['reformulated_query'] ?? '').toString().trim();
    final reasonText = (json['reason'] ?? '').toString().trim();
    return ParsedQueryReport(
      state: QueryReportState.fromWire(json['state']?.toString()),
      reformulatedQuery: reformulated.isEmpty ? null : reformulated,
      reason: reasonText.isEmpty ? null : reasonText,
    );
  }
}

@immutable
class QueryRouteDecision {
  const QueryRouteDecision({
    required this.state,
    required this.action,
    required this.originalQuery,
    required this.searchQuery,
    required this.usedReformulatedQuery,
    this.feedback,
    this.reportSource = 'explicit',
    this.parsedReport,
  });

  final QueryReportState state;
  final QueryRouteAction action;
  final String originalQuery;
  final String searchQuery;
  final bool usedReformulatedQuery;
  final String? feedback;
  final String reportSource;
  final ParsedQueryReport? parsedReport;

  bool get requiresClarification =>
      action == QueryRouteAction.clarify || state == QueryReportState.unclear;

  factory QueryRouteDecision.fromJson(
    final Map<String, Object?> json, {
    final String fallbackQuery = '',
  }) {
    final original =
        (json['original_query'] ?? fallbackQuery).toString().trim();
    final effective = (json['search_query'] ?? original).toString().trim();
    final feedbackText = (json['feedback'] ?? '').toString().trim();
    final rawSource = (json['report_source'] ?? 'explicit').toString().trim();
    final parsedRaw = json['parsed_report'];
    final parsedMap = normalizeQueryRouteMap(parsedRaw);

    return QueryRouteDecision(
      state: QueryReportState.fromWire(json['state']?.toString()),
      action: QueryRouteAction.fromWire(json['action']?.toString()),
      originalQuery: original,
      searchQuery: effective.isEmpty ? original : effective,
      usedReformulatedQuery: json['used_reformulated_query'] == true,
      feedback: feedbackText.isEmpty ? null : feedbackText,
      reportSource: rawSource.isEmpty ? 'explicit' : rawSource,
      parsedReport:
          parsedMap.isEmpty ? null : ParsedQueryReport.fromJson(parsedMap),
    );
  }
}

@immutable
class QueryRouteSearchHit {
  const QueryRouteSearchHit({
    required this.filePath,
    required this.score,
    required this.matchReason,
    this.title,
    this.snippet,
    this.updatedAt,
  });

  final String filePath;
  final String? title;
  final String? snippet;
  final double score;
  final String matchReason;
  final String? updatedAt;

  String get displayTitle {
    final cleanTitle = (title ?? '').trim();
    if (cleanTitle.isNotEmpty) {
      return cleanTitle;
    }
    return filePath;
  }

  factory QueryRouteSearchHit.fromJson(final Map<String, Object?> json) {
    final rawScore = json['score'];
    final score = rawScore is num
        ? rawScore.toDouble()
        : double.tryParse(rawScore?.toString() ?? '') ?? 0.0;
    final cleanTitle = (json['title'] ?? '').toString().trim();
    final cleanSnippet = (json['snippet'] ?? '').toString().trim();
    final cleanUpdated = (json['updated_at'] ?? '').toString().trim();
    return QueryRouteSearchHit(
      filePath: (json['file_path'] ?? json['file'] ?? '').toString().trim(),
      title: cleanTitle.isEmpty ? null : cleanTitle,
      snippet: cleanSnippet.isEmpty ? null : cleanSnippet,
      score: score,
      matchReason: (json['match_reason'] ?? 'bm25').toString().trim(),
      updatedAt: cleanUpdated.isEmpty ? null : cleanUpdated,
    );
  }
}

@immutable
class QueryRouteOutcome {
  const QueryRouteOutcome({
    required this.decision,
    required this.results,
    required this.clarificationRequired,
    this.bm25Candidates = 0,
    this.vectorCandidates = 0,
    this.rawError,
  });

  final QueryRouteDecision decision;
  final List<QueryRouteSearchHit> results;
  final bool clarificationRequired;
  final int bm25Candidates;
  final int vectorCandidates;
  final String? rawError;

  factory QueryRouteOutcome.fromPayload(
    final Map<String, Object?> payload, {
    final bool clarificationRequired = false,
    final String fallbackQuery = '',
  }) {
    final routeMap = normalizeQueryRouteMap(payload['query_route']);
    final decision = QueryRouteDecision.fromJson(
      routeMap,
      fallbackQuery: (payload['original_query'] ?? fallbackQuery).toString(),
    );
    final stagesMap = normalizeQueryRouteMap(payload['stages']);
    final rawResults = payload['results'];
    final hits = rawResults is List<Object?>
        ? rawResults
            .map(normalizeQueryRouteMap)
            .where((final Map<String, Object?> row) => row.isNotEmpty)
            .map(QueryRouteSearchHit.fromJson)
            .toList(growable: false)
        : const <QueryRouteSearchHit>[];

    final needsClarification = clarificationRequired ||
        decision.requiresClarification ||
        payload['error']?.toString() == 'query_clarification_required';

    return QueryRouteOutcome(
      decision: decision,
      results: needsClarification ? const <QueryRouteSearchHit>[] : hits,
      clarificationRequired: needsClarification,
      bm25Candidates: _asInt(stagesMap['bm25_candidates']),
      vectorCandidates: _asInt(stagesMap['vector_candidates']),
      rawError: payload['error']?.toString(),
    );
  }
}

@immutable
class QueryReportTokenPreset {
  const QueryReportTokenPreset({
    required this.id,
    required this.label,
    required this.sampleQuery,
    required this.sampleReport,
  });

  final String id;
  final String label;
  final String sampleQuery;
  final String sampleReport;
}

const List<QueryReportTokenPreset> defaultQueryReportPresets =
    <QueryReportTokenPreset>[
  QueryReportTokenPreset(
    id: 'trivial',
    label: 'Trivial 検証',
    sampleQuery: 'Pleias citation tokens',
    sampleReport: '<|query_report_start|>\n'
        '<|state|>trivial\n'
        '<|reason|>検索意図が明確なため直接検索を実行します。\n'
        '<|query_report_end|>',
  ),
  QueryReportTokenPreset(
    id: 'reformulated',
    label: '再定式化 (reformulated)',
    sampleQuery: 'Pleias',
    sampleReport: '<|query_report_start|>\n'
        '<|state|>reformulated\n'
        '<|reformulated_query|>Pleias Open Data Layers enterprise RAG\n'
        '<|reason|>広範すぎる単一語を検索向け専門クエリへ自動再定式化しました。\n'
        '<|query_report_end|>',
  ),
  QueryReportTokenPreset(
    id: 'unclear',
    label: '不明瞭中断 (unclear)',
    sampleQuery: 'あれを調べて',
    sampleReport: '<|query_report_start|>\n'
        '<|state|>unclear\n'
        '<|reason|>検索対象（機能名・ドキュメント名・エラーコード等）が不足しています。\n'
        '<|query_report_end|>',
  ),
];

Map<String, Object?> normalizeQueryRouteMap(final Object? raw) {
  if (raw is Map<Object?, Object?>) {
    return raw.map<String, Object?>(
      (final Object? key, final Object? value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
  }
  return const <String, Object?>{};
}

int _asInt(final Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

abstract class RagQueryRoutingRepository {
  Future<QueryRouteOutcome> executeQueryRoute({
    required final String query,
    final String? queryReport,
    final bool autoReport = true,
    final int topK = 8,
  });
}

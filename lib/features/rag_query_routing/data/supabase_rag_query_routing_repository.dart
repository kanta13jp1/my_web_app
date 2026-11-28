import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/rag_query_routing_models.dart';

/// Supabase-backed repository for `memory-search-hub` `memory.query_route` (#2754).
class SupabaseRagQueryRoutingRepository implements RagQueryRoutingRepository {
  SupabaseRagQueryRoutingRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireAuthenticatedUser(final SupabaseClient client) {
    if (client.auth.currentUser == null) {
      throw StateError('クエリルーティング機能を利用するにはログインが必要です。');
    }
  }

  /// Extracts a `422 query_clarification_required` outcome from Edge details.
  @visibleForTesting
  static QueryRouteOutcome? parseClarificationFromErrorDetails({
    required final int status,
    required final Object? details,
    required final String fallbackQuery,
  }) {
    if (status != 422) {
      return null;
    }
    final Map<String, Object?> detailMap;
    if (details is Map<Object?, Object?>) {
      detailMap = normalizeQueryRouteMap(details);
    } else if (details is String && details.trim().isNotEmpty) {
      try {
        detailMap = normalizeQueryRouteMap(jsonDecode(details));
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }

    if (detailMap['error']?.toString() != 'query_clarification_required' &&
        !detailMap.containsKey('query_route')) {
      return null;
    }

    return QueryRouteOutcome.fromPayload(
      detailMap,
      clarificationRequired: true,
      fallbackQuery: fallbackQuery,
    );
  }

  @override
  Future<QueryRouteOutcome> executeQueryRoute({
    required final String query,
    final String? queryReport,
    final bool autoReport = true,
    final int topK = 8,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw ArgumentError('検索クエリを入力してください。');
    }

    final client = _resolvedClient;
    _requireAuthenticatedUser(client);

    final trimmedReport = queryReport?.trim() ?? '';
    final body = <String, Object?>{
      'action': 'memory.query_route',
      'query': trimmedQuery,
      'top_k': topK,
      if (trimmedReport.isNotEmpty) 'query_report': trimmedReport,
      if (trimmedReport.isEmpty) 'auto_report': autoReport,
    };

    try {
      final response = await client.functions.invoke(
        'memory-search-hub',
        body: body,
      );
      final payload = normalizeQueryRouteMap(response.data);
      if (response.status == 422 ||
          payload['error']?.toString() == 'query_clarification_required') {
        return QueryRouteOutcome.fromPayload(
          payload,
          clarificationRequired: true,
          fallbackQuery: trimmedQuery,
        );
      }
      if (payload['success'] == false) {
        throw StateError(
          payload['error']?.toString() ?? 'クエリルーティング検索に失敗しました。',
        );
      }
      return QueryRouteOutcome.fromPayload(
        payload,
        fallbackQuery: trimmedQuery,
      );
    } on FunctionException catch (error) {
      final parsedClarification = parseClarificationFromErrorDetails(
        status: error.status,
        details: error.details,
        fallbackQuery: trimmedQuery,
      );
      if (parsedClarification != null) {
        return parsedClarification;
      }
      rethrow;
    }
  }
}

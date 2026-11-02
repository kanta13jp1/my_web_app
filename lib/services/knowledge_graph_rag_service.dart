import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_graph_rag.dart';

typedef KnowledgeGraphRagInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

abstract class KnowledgeGraphRagGateway {
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  });
}

class KnowledgeGraphRagException implements Exception {
  const KnowledgeGraphRagException(this.message, {this.requiresLogin = false});

  final String message;
  final bool requiresLogin;

  @override
  String toString() => message;
}

class KnowledgeGraphRagService implements KnowledgeGraphRagGateway {
  const KnowledgeGraphRagService({
    SupabaseClient? client,
    KnowledgeGraphRagInvoker? invoker,
  })  : _client = client,
        _invoker = invoker;

  final SupabaseClient? _client;
  final KnowledgeGraphRagInvoker? _invoker;

  @override
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const KnowledgeGraphRagException('質問を入力してください。');
    }
    if (normalizedQuery.length > 1000) {
      throw const KnowledgeGraphRagException('質問は1,000文字以内で入力してください。');
    }
    if (sources.isEmpty) {
      throw const KnowledgeGraphRagException('情報源を1つ以上選択してください。');
    }

    final client =
        _client ?? (_invoker == null ? Supabase.instance.client : null);
    final userId = client?.auth.currentUser?.id;
    if (_invoker == null && userId == null) {
      throw const KnowledgeGraphRagException(
        'この機能を使うにはログインしてください。',
        requiresLogin: true,
      );
    }

    final body = buildKnowledgeGraphRagRequest(
      query: normalizedQuery,
      sources: sources,
      useLlm: useLlm,
      userId: userId,
    );
    final data = await _invoke(body, client);
    if (data['success'] != true) {
      final message = _text(
        data['error'] ?? data['message'],
        fallback: 'AI回答を生成できませんでした。',
      );
      throw KnowledgeGraphRagException(
        message,
        requiresLogin: _looksLikeLoginError(message),
      );
    }

    final answer = KnowledgeGraphRagAnswer.fromJson(data);
    if (answer.answer.isEmpty) {
      throw const KnowledgeGraphRagException('AI回答が空でした。');
    }
    return answer;
  }

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body,
    SupabaseClient? client,
  ) async {
    try {
      final invoker = _invoker;
      if (invoker != null) return await invoker(body);

      final response = await client!.functions.invoke(
        'memory-search-hub',
        body: body,
      );
      final data = _map(response.data);
      if (response.status < 200 || response.status >= 300) {
        final message = _text(
          data['error'] ?? data['message'],
          fallback: 'HTTP ${response.status}',
        );
        throw KnowledgeGraphRagException(
          message,
          requiresLogin: response.status == 401 || response.status == 403,
        );
      }
      return data;
    } on KnowledgeGraphRagException {
      rethrow;
    } catch (error) {
      final message = error.toString();
      throw KnowledgeGraphRagException(
        message,
        requiresLogin: _looksLikeLoginError(message),
      );
    }
  }
}

Map<String, dynamic> buildKnowledgeGraphRagRequest({
  required String query,
  required Set<String> sources,
  required bool useLlm,
  String? userId,
}) {
  final normalizedSources = sources
      .map((source) => source.trim().toLowerCase())
      .where((source) => source.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return <String, dynamic>{
    'action': 'memory.rag.query',
    'query': query.trim(),
    'top_k': 8,
    'sources': normalizedSources,
    'use_llm': useLlm,
    if (userId != null && userId.trim().isNotEmpty) 'user_id': userId.trim(),
  };
}

bool _looksLikeLoginError(String message) {
  return RegExp(
    r'unauthorized|forbidden|login|jwt|401|403',
    caseSensitive: false,
  ).hasMatch(message);
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _text(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

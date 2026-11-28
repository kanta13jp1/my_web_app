import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_output_validation_models.dart';

/// Supabase `ai_output_validation_logs` 向け RPC/読取リポジトリ (#2657).
class SupabaseAiOutputValidationRepository
    implements AiOutputValidationRepository {
  SupabaseAiOutputValidationRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?> _normalizeRow(final Map<Object?, Object?> raw) {
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key != null) {
        normalized[entry.key.toString()] = entry.value;
      }
    }
    return normalized;
  }

  @override
  Future<List<AiOutputValidationLog>> fetchLogs() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client
        .from('ai_output_validation_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    if (response is! List<Object?>) {
      return const <AiOutputValidationLog>[];
    }

    final items = <AiOutputValidationLog>[];
    for (final row in response) {
      if (row is Map<String, Object?>) {
        items.add(AiOutputValidationLog.fromSupabaseRow(row));
      } else if (row is Map<Object?, Object?>) {
        items.add(AiOutputValidationLog.fromSupabaseRow(_normalizeRow(row)));
      }
    }
    return List<AiOutputValidationLog>.unmodifiable(items);
  }

  @override
  Future<AiOutputValidationLog> submitValidation({
    required final String prompt,
    required final String candidateOutput,
    final OutputFormatContract formatContract =
        OutputFormatContract.markdownSections,
    final List<String> requiredHeadings = const <String>[
      '## 結論',
      '## 根拠',
    ],
    final List<String> requiredFields = const <String>[],
    final List<String> bannedTerms = const <String>[],
    final int maxLength = 4000,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object inserted = await client.rpc(
      'record_ai_output_validation',
      params: <String, Object?>{
        'p_prompt': prompt,
        'p_candidate_output': candidateOutput,
        'p_format_contract': formatContract.wireValue,
        'p_required_headings': requiredHeadings,
        'p_required_fields': requiredFields,
        'p_banned_terms': bannedTerms,
        'p_max_length': maxLength,
      },
    );

    if (inserted is Map<String, Object?>) {
      return AiOutputValidationLog.fromSupabaseRow(inserted);
    }
    if (inserted is Map<Object?, Object?>) {
      return AiOutputValidationLog.fromSupabaseRow(_normalizeRow(inserted));
    }
    throw StateError('AI出力検証RPCの保存応答が不正です。');
  }
}

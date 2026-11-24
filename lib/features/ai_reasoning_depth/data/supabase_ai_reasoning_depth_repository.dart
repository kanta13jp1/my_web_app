import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_reasoning_depth_models.dart';

/// Supabase `ai_reasoning_depth_jobs` テーブル向け遅延 DI リポジトリ (#2654).
class SupabaseAiReasoningDepthRepository implements AiReasoningDepthRepository {
  SupabaseAiReasoningDepthRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みユーザーセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?>? _asStringMap(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.key != null) {
          normalized[entry.key.toString()] = entry.value;
        }
      }
      return normalized;
    }
    return null;
  }

  @override
  Future<List<ReasoningDepthJob>> fetchJobs() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object response = await client
        .from('ai_reasoning_depth_jobs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);
    if (response is! List<Object?>) {
      return const <ReasoningDepthJob>[];
    }
    final items = <ReasoningDepthJob>[];
    for (final row in response) {
      final mapped = _asStringMap(row);
      if (mapped != null) {
        items.add(ReasoningDepthJob.fromSupabaseRow(mapped));
      }
    }
    return List<ReasoningDepthJob>.unmodifiable(items);
  }

  @override
  Future<ReasoningDepthJob> createJob(ReasoningDepthJob draft) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final payload = draft.toInsertPayload(userId: userId);
    final Object inserted = await client
        .from('ai_reasoning_depth_jobs')
        .insert(payload)
        .select()
        .single();
    final mapped = _asStringMap(inserted);
    if (mapped != null) {
      return ReasoningDepthJob.fromSupabaseRow(mapped);
    }
    throw StateError('推論ジョブの保存応答が不正です。');
  }

  @override
  Future<ReasoningDepthJob> updateJobProgress({
    required String jobId,
    required ReasoningJobStatus jobStatus,
    required int toolCallsCompleted,
    required String progressNote,
    required String resultSummary,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final sanitizedNote = ReasoningDepthPlanner.scrubSensitiveText(
      progressNote,
      maxLength: 500,
    );
    final sanitizedResult = ReasoningDepthPlanner.scrubSensitiveText(
      resultSummary,
      maxLength: 1000,
    );
    final Object updated = await client
        .from('ai_reasoning_depth_jobs')
        .update(<String, Object?>{
          'job_status': jobStatus.wireValue,
          'tool_calls_completed': toolCallsCompleted,
          'progress_note': sanitizedNote,
          'result_summary': sanitizedResult,
        })
        .eq('id', jobId)
        .eq('user_id', userId)
        .select()
        .single();
    final mapped = _asStringMap(updated);
    if (mapped != null) {
      return ReasoningDepthJob.fromSupabaseRow(mapped);
    }
    throw StateError('推論ジョブ進捗の更新応答が不正です。');
  }
}

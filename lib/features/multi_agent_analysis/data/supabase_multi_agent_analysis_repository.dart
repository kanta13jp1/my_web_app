import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/multi_agent_analysis_models.dart';

/// Supabase `multi_agent_analysis_runs` テーブル向け遅延 DI リポジトリ (#2641).
class SupabaseMultiAgentAnalysisRepository
    implements MultiAgentAnalysisRepository {
  SupabaseMultiAgentAnalysisRepository({SupabaseClient? client})
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

  @override
  Future<List<MultiAgentAnalysisRun>> fetchRuns() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object response = await client
        .from('multi_agent_analysis_runs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);
    if (response is! List<Object?>) {
      return const <MultiAgentAnalysisRun>[];
    }
    final items = <MultiAgentAnalysisRun>[];
    for (final row in response) {
      if (row is Map<String, Object?>) {
        items.add(MultiAgentAnalysisRun.fromSupabaseRow(row));
      } else if (row is Map<Object?, Object?>) {
        final normalized = <String, Object?>{};
        for (final entry in row.entries) {
          if (entry.key != null) {
            normalized[entry.key.toString()] = entry.value;
          }
        }
        items.add(MultiAgentAnalysisRun.fromSupabaseRow(normalized));
      }
    }
    return List<MultiAgentAnalysisRun>.unmodifiable(items);
  }

  @override
  Future<MultiAgentAnalysisRun> createRun(MultiAgentAnalysisRun draft) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final payload = draft.toInsertPayload(userId: userId);
    final Object inserted = await client
        .from('multi_agent_analysis_runs')
        .insert(payload)
        .select()
        .single();
    if (inserted is Map<String, Object?>) {
      return MultiAgentAnalysisRun.fromSupabaseRow(inserted);
    }
    if (inserted is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in inserted.entries) {
        if (entry.key != null) {
          normalized[entry.key.toString()] = entry.value;
        }
      }
      return MultiAgentAnalysisRun.fromSupabaseRow(normalized);
    }
    throw StateError('分析実行レコードの保存応答が不正です。');
  }

  @override
  Future<MultiAgentAnalysisRun> submitHumanReview({
    required String runId,
    required HumanReviewStatus status,
    required String note,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final sanitizedNote =
        LocalSequentialAnalysisRunner.scrubSensitiveText(note);
    final Object updated = await client
        .from('multi_agent_analysis_runs')
        .update(<String, Object?>{
          'human_review_status': status.wireValue,
          'human_review_note': sanitizedNote,
          'reviewed_at': status == HumanReviewStatus.pendingHumanReview
              ? null
              : DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', runId)
        .eq('user_id', userId)
        .select()
        .single();
    if (updated is Map<String, Object?>) {
      return MultiAgentAnalysisRun.fromSupabaseRow(updated);
    }
    if (updated is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in updated.entries) {
        if (entry.key != null) {
          normalized[entry.key.toString()] = entry.value;
        }
      }
      return MultiAgentAnalysisRun.fromSupabaseRow(normalized);
    }
    throw StateError('レビュー結果の保存応答が不正です。');
  }
}

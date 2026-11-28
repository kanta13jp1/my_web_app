import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_rlhf_feedback_models.dart';

/// Supabase `ai_rlhf_feedback` と `rlhf-feedback-webhook` EF への接続リポジトリ (#2659).
class SupabaseAiRlhfFeedbackRepository implements AiRlhfFeedbackRepository {
  SupabaseAiRlhfFeedbackRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?> _normalizeRow(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final result = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.key != null) {
          result[entry.key.toString()] = entry.value;
        }
      }
      return result;
    }
    return const <String, Object?>{};
  }

  @override
  Future<List<AiRlhfFeedbackEntry>> fetchRecentFeedback() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final rows = await client
        .from('ai_rlhf_feedback')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    final entries = <AiRlhfFeedbackEntry>[];
    for (final row in rows as List<dynamic>) {
      final normalized = _normalizeRow(row);
      if (normalized.isNotEmpty) {
        entries.add(AiRlhfFeedbackEntry.fromSupabaseRow(normalized));
      }
    }
    return List<AiRlhfFeedbackEntry>.unmodifiable(entries);
  }

  @override
  Future<AiRlhfFeedbackEntry> submitFeedback(AiRlhfFeedbackDraft draft) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final created = await client
        .from('ai_rlhf_feedback')
        .insert(<String, Object?>{
          'user_id': userId,
          'action_name': draft.actionName.trim(),
          'model_id': draft.modelId.trim(),
          'prompt_text': draft.promptText.trim(),
          'ai_output': draft.aiOutput.trim(),
          'rating_status': draft.ratingStatus.dbValue,
          'user_comment': draft.userComment.trim(),
          'dispatch_status':
              draft.ratingStatus.triggersGitHubIssue ? 'pending' : 'not_needed',
        })
        .select()
        .single();
    return AiRlhfFeedbackEntry.fromSupabaseRow(_normalizeRow(created));
  }

  @override
  Future<RlhfWebhookDispatchResult> triggerWebhookDispatch({
    required String feedbackId,
    bool dryRun = false,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'rlhf-feedback-webhook',
      body: <String, Object?>{
        'feedback_id': feedbackId,
        'dry_run': dryRun,
      },
    );
    final data = _normalizeRow(response.data);
    final issueRaw = data['issue_number'];
    final labelsRaw = data['labels'];
    final labels = <String>[];
    if (labelsRaw is List<dynamic>) {
      for (final item in labelsRaw) {
        if (item != null) {
          labels.add(item.toString());
        }
      }
    }
    return RlhfWebhookDispatchResult(
      feedbackId: feedbackId,
      dispatched: data['issue_number'] != null,
      skipped: data['skipped'] == true,
      dryRun: data['dry_run'] == true,
      issueNumber: issueRaw is num ? issueRaw.toInt() : null,
      issueUrl: data['issue_url']?.toString(),
      labels: List<String>.unmodifiable(labels),
      message: data['reason']?.toString() ?? '',
    );
  }
}

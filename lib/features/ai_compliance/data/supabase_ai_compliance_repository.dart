import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_compliance_models.dart';

/// Supabase `app-hub` repository for AI model compliance workflow (#2763).
class SupabaseAiComplianceRepository implements AiComplianceRepository {
  SupabaseAiComplianceRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireSignedIn(final SupabaseClient client) {
    if (client.auth.currentUser == null) {
      throw StateError('コンプライアンス検証ワークフローを利用するにはログインが必要です。');
    }
  }

  Future<Map<String, Object?>> _invoke(
    final Map<String, Object?> body,
  ) async {
    final client = _resolvedClient;
    _requireSignedIn(client);
    final response = await client.functions.invoke('app-hub', body: body);
    final payload = normalizeAiComplianceMap(response.data);
    if (payload['success'] == false || response.status >= 400) {
      throw StateError(
        payload['error']?.toString() ?? 'コンプライアンス情報の取得・更新に失敗しました。',
      );
    }
    return payload;
  }

  @override
  Future<AiComplianceFeedResult> listRecords({
    final String? statusFilter,
    final String? query,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_compliance.list',
      if (statusFilter != null && statusFilter.trim().isNotEmpty)
        'status': statusFilter.trim(),
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    });
    return AiComplianceFeedResult.fromPayload(payload);
  }

  @override
  Future<AiComplianceFeedResult> seedDefaults() async {
    final payload = await _invoke(const <String, Object?>{
      'action': 'ai_compliance.seed_defaults',
    });
    return AiComplianceFeedResult.fromPayload(payload);
  }

  @override
  Future<AiComplianceFeedResult> submitReview({
    required final String providerKey,
    required final String modelId,
    required final String providerName,
    final String? termsUrl,
    final String? reviewNotes,
    final ComplianceChecklistState? checklist,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_compliance.submit_review',
      'provider_key': providerKey.trim(),
      'model_id': modelId.trim(),
      'provider_name': providerName.trim(),
      if (termsUrl != null && termsUrl.trim().isNotEmpty)
        'terms_url': termsUrl.trim(),
      if (reviewNotes != null && reviewNotes.trim().isNotEmpty)
        'review_notes': reviewNotes.trim(),
      if (checklist != null) 'checklist': checklist.toJson(),
    });
    return AiComplianceFeedResult.fromPayload(payload);
  }

  @override
  Future<AiComplianceFeedResult> updateChecklist({
    required final String id,
    required final ComplianceChecklistState checklist,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_compliance.update_checklist',
      'id': id.trim(),
      'checklist': checklist.toJson(),
    });
    return AiComplianceFeedResult.fromPayload(payload);
  }

  @override
  Future<AiComplianceFeedResult> approveEntry({
    required final String id,
    required final String reviewerName,
    required final bool humanConfirmed,
    final String? approvalNote,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_compliance.approve',
      'id': id.trim(),
      'reviewer_name': reviewerName.trim(),
      'human_confirmed': humanConfirmed,
      if (approvalNote != null && approvalNote.trim().isNotEmpty)
        'approval_note': approvalNote.trim(),
    });
    return AiComplianceFeedResult.fromPayload(payload);
  }

  @override
  Future<AiComplianceGuardResult> checkInvokeGuard({
    required final String id,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_compliance.check_invoke_guard',
      'id': id.trim(),
    });
    return AiComplianceGuardResult.fromPayload(payload);
  }
}

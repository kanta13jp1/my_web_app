import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_investment_models.dart';

/// Supabase `app-hub` repository for 2026Q2 AI investment trends (#2761).
class SupabaseAiInvestmentRepository implements AiInvestmentRepository {
  SupabaseAiInvestmentRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireSignedIn(final SupabaseClient client) {
    if (client.auth.currentUser == null) {
      throw StateError('AI企業投資動向管理を利用するにはログインが必要です。');
    }
  }

  Future<Map<String, Object?>> _invoke(
    final Map<String, Object?> body,
  ) async {
    final client = _resolvedClient;
    _requireSignedIn(client);
    final response = await client.functions.invoke('app-hub', body: body);
    final payload = normalizeAiInvestmentMap(response.data);
    if (payload['success'] == false || response.status >= 400) {
      throw StateError(
        payload['error']?.toString() ?? 'AI企業投資データの取得・更新に失敗しました。',
      );
    }
    return payload;
  }

  @override
  Future<AiInvestmentFeedResult> listRecords({
    final String? quarter,
    final String? verificationStatus,
    final String? query,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_investment.list',
      if (quarter != null && quarter.trim().isNotEmpty)
        'quarter': quarter.trim(),
      if (verificationStatus != null && verificationStatus.trim().isNotEmpty)
        'verification_status': verificationStatus.trim(),
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    });
    return AiInvestmentFeedResult.fromPayload(payload);
  }

  @override
  Future<AiInvestmentFeedResult> seedDefaults() async {
    final payload = await _invoke(const <String, Object?>{
      'action': 'ai_investment.seed_defaults',
    });
    return AiInvestmentFeedResult.fromPayload(payload);
  }

  @override
  Future<AiInvestmentIngestResult> ingestPayload({
    required final String rawPayload,
    final String? sourceName,
  }) async {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('取込データ（JSON または RSS/Atom）を入力してください。');
    }
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_investment.ingest',
      'raw_payload': trimmed,
      if (sourceName != null && sourceName.trim().isNotEmpty)
        'source_name': sourceName.trim(),
    });
    return AiInvestmentIngestResult.fromPayload(payload);
  }

  @override
  Future<AiInvestmentFeedResult> verifyEntry({
    required final String id,
    required final InvestmentVerificationStatus decision,
    required final String verificationNote,
    final String? sourceUrl,
  }) async {
    final payload = await _invoke(<String, Object?>{
      'action': 'ai_investment.verify_entry',
      'id': id.trim(),
      'decision': decision.wireValue,
      'verification_note': verificationNote.trim(),
      if (sourceUrl != null && sourceUrl.trim().isNotEmpty)
        'source_url': sourceUrl.trim(),
    });
    final listPayload = await listRecords();
    final updatedRaw = payload['record'];
    if (updatedRaw is Map<Object?, Object?>) {
      final updated = AiInvestmentRecord.fromMap(updatedRaw);
      final updatedList = listPayload.records
          .map((final item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      return AiInvestmentFeedResult(
        records: updatedList,
        summary: listPayload.summary,
      );
    }
    return listPayload;
  }
}

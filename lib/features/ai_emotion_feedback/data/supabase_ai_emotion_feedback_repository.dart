import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_emotion_feedback_models.dart';

/// Supabase `app-hub` repository for AI emotion feedback (#2766).
class SupabaseAiEmotionFeedbackRepository
    implements AiEmotionFeedbackRepository {
  SupabaseAiEmotionFeedbackRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('AI感情フィードバック機能を利用するにはログインが必要です。');
    }
    return userId;
  }

  Map<String, Object?> _decodeMap(final Object? raw) {
    final normalized = raw is String ? jsonDecode(raw) : raw;
    if (normalized is Map<Object?, Object?>) {
      return normalized.map<String, Object?>(
        (final Object? k, final Object? v) => MapEntry(k.toString(), v),
      );
    }
    return const <String, Object?>{};
  }

  AiEmotionFeedbackEntry _mapEntry(final Map<String, Object?> raw) {
    final issueNumberRaw = raw['issue_number'];
    final issueNumber = issueNumberRaw is num ? issueNumberRaw.toInt() : null;
    final issueUrlRaw = raw['issue_url']?.toString();
    final skipRaw = raw['issue_skipped_reason']?.toString();
    return AiEmotionFeedbackEntry(
      id: (raw['id'] ?? '').toString(),
      category: EmotionFeedbackCategory.fromApi(raw['category']?.toString()),
      severity: EmotionFeedbackSeverity.fromApi(raw['severity']?.toString()),
      aiSnippet: (raw['ai_snippet'] ?? '').toString(),
      userComment: (raw['user_comment'] ?? '').toString(),
      sessionRef: (raw['session_ref'] ?? '').toString(),
      modelRef: (raw['model_ref'] ?? '').toString(),
      issueCreated: raw['issue_created'] == true && issueNumber != null,
      issueNumber: issueNumber,
      issueUrl:
          issueUrlRaw != null && issueUrlRaw.isNotEmpty ? issueUrlRaw : null,
      issueSkippedReason:
          skipRaw != null && skipRaw.isNotEmpty ? skipRaw : null,
      submittedAt: DateTime.tryParse((raw['submitted_at'] ?? '').toString()),
    );
  }

  List<AiEmotionFeedbackEntry> _mapEntryList(final Object? rawList) {
    if (rawList is! List<Object?>) {
      return const <AiEmotionFeedbackEntry>[];
    }
    final items = <AiEmotionFeedbackEntry>[];
    for (final raw in rawList) {
      if (raw is Map<Object?, Object?>) {
        items.add(
          _mapEntry(
            raw.map<String, Object?>(
              (final Object? k, final Object? v) => MapEntry(k.toString(), v),
            ),
          ),
        );
      }
    }
    return List<AiEmotionFeedbackEntry>.unmodifiable(items);
  }

  AiEmotionFeedbackSummary _mapSummary(
    final Object? rawSummary,
    final List<AiEmotionFeedbackEntry> entries,
  ) {
    if (rawSummary is! Map<Object?, Object?>) {
      return AiEmotionFeedbackSummary.fromEntries(entries);
    }
    final map = rawSummary.map<String, Object?>(
      (final Object? k, final Object? v) => MapEntry(k.toString(), v),
    );
    final rawByCat = map['by_category'];
    final byCategory = <EmotionFeedbackCategory, int>{
      for (final category in EmotionFeedbackCategory.values) category: 0,
    };
    if (rawByCat is Map<Object?, Object?>) {
      for (final category in EmotionFeedbackCategory.values) {
        final count = rawByCat[category.apiValue];
        if (count is num) {
          byCategory[category] = count.toInt();
        }
      }
    }
    return AiEmotionFeedbackSummary(
      totalCount: (map['total_count'] as num?)?.toInt() ?? entries.length,
      highSeverityCount: (map['high_severity_count'] as num?)?.toInt() ?? 0,
      issueCreatedCount: (map['issue_created_count'] as num?)?.toInt() ?? 0,
      byCategory: Map<EmotionFeedbackCategory, int>.unmodifiable(byCategory),
    );
  }

  String _formatFunctionError(final FunctionException error) {
    if (error.status == 401) {
      return '認証の有効期限が切れています。再ログイン後に再試行してください。';
    }
    final details = error.details;
    if (details is Map<Object?, Object?> && details['error'] != null) {
      return details['error'].toString();
    }
    if (details != null && details.toString().trim().isNotEmpty) {
      return details.toString();
    }
    return error.reasonPhrase ??
        'AI感情フィードバック API でエラーが発生しました (${error.status})';
  }

  Future<Map<String, Object?>> _invokeAppHub(
    final Map<String, Object?> body,
  ) async {
    final client = _resolvedClient;
    _requireUserId(client);
    try {
      final response = await client.functions.invoke('app-hub', body: body);
      final payload = _decodeMap(response.data);
      if (payload['error'] != null) {
        throw StateError(payload['error'].toString());
      }
      return payload;
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }

  @override
  Future<AiEmotionFeedbackSnapshot> fetchFeedbacks({
    final EmotionFeedbackCategory? categoryFilter,
    final int limit = 50,
  }) async {
    final payload = await _invokeAppHub(<String, Object?>{
      'action': 'ai_emotion_feedback.list',
      'limit': limit.clamp(1, 100),
      if (categoryFilter != null) 'category': categoryFilter.apiValue,
    });
    final entries = _mapEntryList(payload['entries']);
    return AiEmotionFeedbackSnapshot(
      entries: entries,
      summary: _mapSummary(payload['summary'], entries),
    );
  }

  @override
  Future<AiEmotionFeedbackEntry> submitFeedback({
    required final EmotionFeedbackCategory category,
    required final EmotionFeedbackSeverity severity,
    required final String aiSnippet,
    required final String userComment,
    final String sessionRef = '',
    final String modelRef = '',
  }) async {
    final payload = await _invokeAppHub(<String, Object?>{
      'action': 'ai_emotion_feedback.submit',
      'category': category.apiValue,
      'severity': severity.apiValue,
      'ai_snippet': aiSnippet,
      'user_comment': userComment,
      'session_ref': sessionRef,
      'model_ref': modelRef,
    });
    final rawFeedback = payload['feedback'];
    if (rawFeedback is Map<Object?, Object?>) {
      return _mapEntry(
        rawFeedback.map<String, Object?>(
          (final Object? k, final Object? v) => MapEntry(k.toString(), v),
        ),
      );
    }
    throw StateError('フィードバック保存結果を取得できませんでした。');
  }

  @override
  Future<AiEmotionFeedbackSnapshot> seedDefaults() async {
    final payload = await _invokeAppHub(const <String, Object?>{
      'action': 'ai_emotion_feedback.seed_defaults',
    });
    final entries = _mapEntryList(payload['entries']);
    return AiEmotionFeedbackSnapshot(
      entries: entries,
      summary: _mapSummary(payload['summary'], entries),
      seededCount: (payload['seeded_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<NotebookLmIntakePackage> exportNotebookLmIntake({
    final int limit = 100,
  }) async {
    final payload = await _invokeAppHub(<String, Object?>{
      'action': 'ai_emotion_feedback.export_notebooklm_intake',
      'limit': limit.clamp(1, 100),
    });
    final bundle = payload['json_bundle'];
    final jsonText = bundle == null
        ? '{}'
        : const JsonEncoder.withIndent('  ').convert(bundle);
    return NotebookLmIntakePackage(
      notebookId: (payload['notebook_id'] ?? '').toString(),
      notebookTitle: (payload['notebook_title'] ?? '').toString(),
      exportedAt: (payload['exported_at'] ?? '').toString(),
      recordCount: (payload['record_count'] as num?)?.toInt() ?? 0,
      markdownSummary: (payload['markdown_summary'] ?? '').toString(),
      jsonBundleText: jsonText,
    );
  }
}

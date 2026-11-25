import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/synthetic_media_audit_models.dart';

/// 合成メディア動画倫理監査リポジトリの抽象インターフェース (#2661).
abstract class SyntheticMediaAuditRepository {
  Future<bool> fetchIsAdmin();

  Future<List<SyntheticMediaVideo>> fetchVideos({
    final int limit = 60,
  });

  Future<List<SyntheticMediaAuditLogEntry>> fetchAuditLogs({
    final int limit = 60,
  });

  Future<SyntheticMediaVideo> submitVideo(
    final SubmitSyntheticMediaInput input,
  );

  Future<SyntheticMediaVideo> reviewVideo({
    required final String videoId,
    required final SyntheticMediaModerationStatus decision,
    final String? reviewNote,
  });
}

/// Supabase RPC / テーブル経由で合成メディア動画監査を扱う実装 (#2661).
class SupabaseSyntheticMediaAuditRepository
    implements SyntheticMediaAuditRepository {
  SupabaseSyntheticMediaAuditRepository({
    final SupabaseClient? client,
  }) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Map<String, Object?> _normalizeRow(final Map<Object?, Object?> raw) {
    final Map<String, Object?> normalized = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      if (entry.key != null) {
        normalized[entry.key.toString()] = entry.value;
      }
    }
    return normalized;
  }

  @override
  Future<bool> fetchIsAdmin() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return false;
    }
    final Object row = await _client
            .from('user_profiles')
            .select('is_admin')
            .eq('user_id', user.id)
            .maybeSingle() ??
        const <String, bool>{};
    if (row is Map) {
      return row['is_admin'] == true;
    }
    return false;
  }

  @override
  Future<List<SyntheticMediaVideo>> fetchVideos({
    final int limit = 60,
  }) async {
    final Object response = await _client
        .from('synthetic_media_videos')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    if (response is! List) {
      return const <SyntheticMediaVideo>[];
    }
    final List<SyntheticMediaVideo> items = <SyntheticMediaVideo>[];
    for (final item in response) {
      if (item is Map) {
        items.add(
          SyntheticMediaVideo.fromSupabaseRow(
            _normalizeRow(Map<Object?, Object?>.from(item)),
          ),
        );
      }
    }
    return List<SyntheticMediaVideo>.unmodifiable(items);
  }

  @override
  Future<List<SyntheticMediaAuditLogEntry>> fetchAuditLogs({
    final int limit = 60,
  }) async {
    final Object response = await _client
        .from('synthetic_media_audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    if (response is! List) {
      return const <SyntheticMediaAuditLogEntry>[];
    }
    final List<SyntheticMediaAuditLogEntry> items =
        <SyntheticMediaAuditLogEntry>[];
    for (final item in response) {
      if (item is Map) {
        items.add(
          SyntheticMediaAuditLogEntry.fromSupabaseRow(
            _normalizeRow(Map<Object?, Object?>.from(item)),
          ),
        );
      }
    }
    return List<SyntheticMediaAuditLogEntry>.unmodifiable(items);
  }

  @override
  Future<SyntheticMediaVideo> submitVideo(
    final SubmitSyntheticMediaInput input,
  ) async {
    final String? validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final Object result = await _client.rpc(
      'submit_synthetic_media_video',
      params: <String, Object>{
        'p_title': input.title.trim(),
        'p_video_url': input.videoUrl.trim(),
        'p_source_provider': input.sourceProvider.trim(),
        'p_copyright_consent_status': input.copyrightConsentStatus.wireValue,
        'p_likeness_consent_status': input.likenessConsentStatus.wireValue,
        'p_commercial_watermark_present': input.commercialWatermarkPresent,
        'p_celebrity_likeness_cleared': input.celebrityLikenessCleared,
        'p_track_and_trace_provider': input.trackAndTraceProvider.wireValue,
        'p_track_and_trace_id': input.trackAndTraceId?.trim() ?? '',
        'p_track_and_trace_metadata': input.trackAndTraceMetadata,
      },
    );
    if (result is Map) {
      return SyntheticMediaVideo.fromSupabaseRow(
        _normalizeRow(Map<Object?, Object?>.from(result)),
      );
    }
    throw StateError('合成メディア動画の登録応答が不正です。');
  }

  @override
  Future<SyntheticMediaVideo> reviewVideo({
    required final String videoId,
    required final SyntheticMediaModerationStatus decision,
    final String? reviewNote,
  }) async {
    if (decision == SyntheticMediaModerationStatus.pending) {
      throw ArgumentError('審査決定は approved または rejected のみ指定できます。');
    }
    if (decision == SyntheticMediaModerationStatus.rejected &&
        (reviewNote == null || reviewNote.trim().isEmpty)) {
      throw ArgumentError('却下時は理由コメントの入力が必須です。');
    }

    final Object result = await _client.rpc(
      'review_synthetic_media_video',
      params: <String, Object>{
        'p_video_id': videoId.trim(),
        'p_decision': decision.wireValue,
        'p_review_note': reviewNote?.trim() ?? '',
      },
    );
    if (result is Map) {
      return SyntheticMediaVideo.fromSupabaseRow(
        _normalizeRow(Map<Object?, Object?>.from(result)),
      );
    }
    throw StateError('合成メディア動画の審査応答が不正です。');
  }
}

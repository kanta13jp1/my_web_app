import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/multilingual_video_player_models.dart';

/// 多言語動画翻訳リポジトリの抽象インターフェース (#2660).
abstract class MultilingualVideoRepository {
  Future<List<VideoTranslationTrack>> fetchTranslations({
    final String? sourceVideoId,
    final int limit = 50,
  });

  Future<VideoTranslationTrack> queueTranslation(
    final QueueVideoTranslationInput input,
  );
}

/// Supabase 経由で `multilingual_video_translations` を操作する実装 (#2660).
class SupabaseMultilingualVideoRepository
    implements MultilingualVideoRepository {
  SupabaseMultilingualVideoRepository({
    final SupabaseClient? client,
  }) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  Future<List<VideoTranslationTrack>> fetchTranslations({
    final String? sourceVideoId,
    final int limit = 50,
  }) async {
    final List<Object?> rows;
    if (sourceVideoId != null && sourceVideoId.trim().isNotEmpty) {
      rows = await _client
          .from('multilingual_video_translations')
          .select()
          .eq('source_video_id', sourceVideoId.trim())
          .order('created_at', ascending: false)
          .limit(limit);
    } else {
      rows = await _client
          .from('multilingual_video_translations')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
    }

    return rows
        .whereType<Map<Object?, Object?>>()
        .map(
          (final Map<Object?, Object?> raw) => VideoTranslationTrack.fromMap(
            <String, Object?>{
              for (final MapEntry<Object?, Object?> entry in raw.entries)
                if (entry.key != null) entry.key.toString(): entry.value,
            },
          ),
        )
        .toList();
  }

  @override
  Future<VideoTranslationTrack> queueTranslation(
    final QueueVideoTranslationInput input,
  ) async {
    final String? err = input.validate();
    if (err != null) {
      throw ArgumentError(err);
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('翻訳ジョブの登録にはログインが必要です。');
    }

    final String code =
        input.languageCode.trim().toLowerCase().replaceAll('_', '-');
    final String didName = resolveDidLanguageName(code) ?? 'English';

    // status / provider_job_id / result_url は DB トリガーにより管理され、
    // クライアントからは queued のみ安全に登録する。
    final Map<String, Object?> inserted = await _client
        .from('multilingual_video_translations')
        .insert(<String, Object?>{
          'user_id': user.id,
          'source_video_id': input.sourceVideoId.trim(),
          'source_video_url': input.sourceVideoUrl.trim(),
          'language_code': code,
          'did_language_name': didName,
          'status': VideoTranslationStatus.queued.wireValue,
          'duration_seconds': input.durationSeconds,
          'max_duration_cap_seconds': input.maxDurationCapSeconds,
          'estimated_cost_usd': input.estimatedCostUsd,
          'max_cost_cap_usd': input.maxCostCapUsd,
        })
        .select()
        .single();

    return VideoTranslationTrack.fromMap(inserted);
  }
}

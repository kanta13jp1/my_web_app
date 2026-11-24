import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/image_moderation_models.dart';

/// Supabase `moderated_image_assets` テーブル向け遅延 DI リポジトリ (#2644).
class SupabaseImageModerationRepository implements ImageModerationRepository {
  SupabaseImageModerationRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  @override
  Future<List<ModeratedImageAsset>> fetchAssets() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object? response = await client
        .from('moderated_image_assets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(40);
    if (response is! List<Object?>) {
      return const <ModeratedImageAsset>[];
    }
    final items = <ModeratedImageAsset>[];
    for (final row in response) {
      if (row is Map<String, Object?>) {
        items.add(ModeratedImageAsset.fromSupabaseRow(row));
      } else if (row is Map<Object?, Object?>) {
        final normalized = <String, Object?>{};
        for (final entry in row.entries) {
          if (entry.key != null) {
            normalized[entry.key.toString()] = entry.value;
          }
        }
        items.add(ModeratedImageAsset.fromSupabaseRow(normalized));
      }
    }
    return List<ModeratedImageAsset>.unmodifiable(items);
  }

  @override
  Future<ModeratedImageAsset> registerUploadedImage(
    ModeratedImageAsset draft,
  ) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object? inserted = await client
        .from('moderated_image_assets')
        .insert(draft.toInsertPayload(userId: userId))
        .select()
        .single();
    if (inserted is Map<String, Object?>) {
      return ModeratedImageAsset.fromSupabaseRow(inserted);
    }
    if (inserted is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in inserted.entries) {
        if (entry.key != null) {
          normalized[entry.key.toString()] = entry.value;
        }
      }
      return ModeratedImageAsset.fromSupabaseRow(normalized);
    }
    throw StateError('画像解析レコードの保存応答が不正です。');
  }
}

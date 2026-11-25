import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unified_media_library_models.dart';

/// `media-hub` Edge Function 経由の統合メディアライブラリ永続化実装 (#2714)。
class SupabaseUnifiedMediaLibraryRepository
    implements UnifiedMediaLibraryRepository {
  SupabaseUnifiedMediaLibraryRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver ?? _defaultClient;

  final SupabaseClient Function() _clientResolver;

  static SupabaseClient _defaultClient() => Supabase.instance.client;

  Future<Map<String, Object?>> _invokeMediaHub(
    Map<String, Object?> payload,
  ) async {
    final SupabaseClient client = _clientResolver();
    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: payload,
    );
    final Object? raw = response.data;
    final Map<String, Object?> body = raw is Map<Object?, Object?>
        ? Map<String, Object?>.from(raw)
        : const <String, Object?>{};
    final String errorText = (body['error'] as String? ?? '').trim();
    if (response.status >= 400 || errorText.isNotEmpty) {
      throw StateError(
        errorText.isNotEmpty
            ? errorText
            : 'Media library request failed (${response.status})',
      );
    }
    return body;
  }

  @override
  Future<List<UnifiedMediaAsset>> searchAssets({
    String query = '',
    MediaAssetKind? assetKind,
    String? tag,
    String? projectKey,
  }) async {
    final Map<String, Object?> data = await _invokeMediaHub(
      <String, Object?>{
        'action': 'media_library.search',
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (assetKind != null) 'asset_kind': assetKind.wireValue,
        if ((tag ?? '').trim().isNotEmpty) 'tag': tag!.trim(),
        if ((projectKey ?? '').trim().isNotEmpty)
          'project_key': projectKey!.trim(),
      },
    );
    final Object? rawAssets = data['assets'];
    if (rawAssets is! List<Object?>) {
      return const <UnifiedMediaAsset>[];
    }
    return rawAssets
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> entry) =>
              UnifiedMediaAsset.fromJson(Map<String, Object?>.from(entry)),
        )
        .toList(growable: false);
  }

  @override
  Future<MediaUploadResult> uploadOrDeduplicateAsset({
    required String title,
    required MediaAssetKind assetKind,
    required String contentBase64,
    String description = '',
    List<String> tags = const <String>[],
    AutoTagModelPreference aiModel =
        AutoTagModelPreference.deterministicFallback,
    int? durationSec,
    String? projectKey,
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
  }) async {
    final Map<String, Object?> data = await _invokeMediaHub(
      <String, Object?>{
        'action': 'media_library.upload_or_deduplicate',
        'title': title.trim(),
        'description': description.trim(),
        'asset_kind': assetKind.wireValue,
        'mime_type': assetKind.defaultMimeType,
        'content_base64': contentBase64,
        'tags': tags,
        'ai_model': aiModel.wireValue,
        if (durationSec != null) 'duration_sec': durationSec,
        if ((projectKey ?? '').trim().isNotEmpty)
          'project_key': projectKey!.trim(),
        'pipeline_stage': pipelineStage.wireValue,
      },
    );
    final Object? rawAsset = data['asset'];
    if (rawAsset is! Map<Object?, Object?>) {
      throw StateError('Missing asset in upload response');
    }
    final Object? rawUsage = data['usage'];
    return MediaUploadResult(
      deduplicated: data['deduplicated'] as bool? ?? false,
      storageUploadSkipped: data['storage_upload_skipped'] as bool? ?? false,
      bytesSaved: (data['bytes_saved'] as num?)?.toInt() ?? 0,
      asset: UnifiedMediaAsset.fromJson(
        Map<String, Object?>.from(rawAsset),
      ),
      usage: rawUsage is Map<Object?, Object?>
          ? MediaProjectUsage.fromJson(Map<String, Object?>.from(rawUsage))
          : null,
    );
  }

  @override
  Future<UnifiedMediaAsset> reuseAssetInProject({
    required UnifiedMediaAsset asset,
    required String projectKey,
    String projectTitle = '',
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
    String notes = '',
  }) async {
    final Map<String, Object?> data = await _invokeMediaHub(
      <String, Object?>{
        'action': 'media_library.reuse_in_project',
        'asset_id': asset.id,
        'project_key': projectKey.trim(),
        if (projectTitle.trim().isNotEmpty)
          'project_title': projectTitle.trim(),
        'pipeline_stage': pipelineStage.wireValue,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    final Object? rawAsset = data['asset'];
    if (rawAsset is! Map<Object?, Object?>) {
      throw StateError('Missing asset in reuse response');
    }
    return UnifiedMediaAsset.fromJson(
      Map<String, Object?>.from(rawAsset),
    );
  }

  @override
  Future<UnifiedMediaAsset> updateAssetTags({
    required UnifiedMediaAsset asset,
    required List<String> tags,
    bool refreshAutoTags = false,
    AutoTagModelPreference aiModel =
        AutoTagModelPreference.deterministicFallback,
  }) async {
    final Map<String, Object?> data = await _invokeMediaHub(
      <String, Object?>{
        'action': 'media_library.update_tags',
        'asset_id': asset.id,
        'tags': tags,
        'refresh_auto_tags': refreshAutoTags,
        'ai_model': aiModel.wireValue,
      },
    );
    final Object? rawAsset = data['asset'];
    if (rawAsset is! Map<Object?, Object?>) {
      throw StateError('Missing asset in tag update response');
    }
    return UnifiedMediaAsset.fromJson(
      Map<String, Object?>.from(rawAsset),
    );
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    await _invokeMediaHub(
      <String, Object?>{
        'action': 'media_library.delete',
        'asset_id': assetId,
      },
    );
  }
}

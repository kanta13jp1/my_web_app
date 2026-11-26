/// 統合メディアライブラリ＆アセット再利用ドメインモデル (#2714)。
enum MediaAssetKind {
  video('video', '動画'),
  audio('audio', '音声'),
  image('image', '画像');

  const MediaAssetKind(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  String get defaultMimeType {
    switch (this) {
      case MediaAssetKind.video:
        return 'video/mp4';
      case MediaAssetKind.audio:
        return 'audio/mpeg';
      case MediaAssetKind.image:
        return 'image/png';
    }
  }

  static MediaAssetKind fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final MediaAssetKind value in MediaAssetKind.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return MediaAssetKind.video;
  }
}

enum PipelineReuseStage {
  videoTimeline('video_timeline', 'メインタイムライン'),
  audioTrack('audio_track', '音声トラック'),
  bRoll('b_roll', 'Bロール素材'),
  thumbnail('thumbnail', 'サムネイル'),
  voiceover('voiceover', 'ナレーション'),
  adCreative('ad_creative', '動画広告');

  const PipelineReuseStage(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static PipelineReuseStage fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final PipelineReuseStage value in PipelineReuseStage.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return PipelineReuseStage.videoTimeline;
  }
}

enum AutoTagModelPreference {
  deterministicFallback('deterministic-fallback', '決定的自動タグ'),
  claudeSonnet46('claude-sonnet-4-6', 'Claude Sonnet 4.6'),
  gemini31Pro('gemini-3.1-pro', 'Gemini 3.1 Pro');

  const AutoTagModelPreference(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static AutoTagModelPreference fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final AutoTagModelPreference value in AutoTagModelPreference.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AutoTagModelPreference.deterministicFallback;
  }
}

class MediaProjectUsage {
  const MediaProjectUsage({
    required this.id,
    required this.assetId,
    required this.projectKey,
    required this.projectTitle,
    required this.pipelineStage,
    required this.notes,
    required this.updatedAtIso,
  });

  final String id;
  final String assetId;
  final String projectKey;
  final String projectTitle;
  final PipelineReuseStage pipelineStage;
  final String notes;
  final String updatedAtIso;

  factory MediaProjectUsage.fromJson(Map<String, Object?> json) {
    return MediaProjectUsage(
      id: (json['id'] as String? ?? '').trim(),
      assetId: (json['asset_id'] as String? ?? '').trim(),
      projectKey: (json['project_key'] as String? ?? '').trim(),
      projectTitle: (json['project_title'] as String? ?? '').trim(),
      pipelineStage: PipelineReuseStage.fromWire(
        json['pipeline_stage'] as String?,
      ),
      notes: (json['notes'] as String? ?? '').trim(),
      updatedAtIso: (json['updated_at'] as String? ?? '').trim(),
    );
  }
}

class UnifiedMediaAsset {
  const UnifiedMediaAsset({
    required this.id,
    required this.assetKind,
    required this.mimeType,
    required this.title,
    required this.description,
    required this.contentSha256,
    required this.byteSize,
    required this.storageObjectPath,
    required this.tags,
    required this.autoTags,
    required this.taggingModel,
    required this.reuseCount,
    required this.usages,
    this.durationSec,
    this.updatedAtIso = '',
  });

  final String id;
  final MediaAssetKind assetKind;
  final String mimeType;
  final String title;
  final String description;
  final String contentSha256;
  final int byteSize;
  final int? durationSec;
  final String storageObjectPath;
  final List<String> tags;
  final List<String> autoTags;
  final AutoTagModelPreference taggingModel;
  final int reuseCount;
  final List<MediaProjectUsage> usages;
  final String updatedAtIso;

  List<String> get allSearchTags {
    final Set<String> combined = <String>{...tags, ...autoTags};
    return List<String>.unmodifiable(combined);
  }

  UnifiedMediaAsset copyWith({
    List<String>? tags,
    List<String>? autoTags,
    AutoTagModelPreference? taggingModel,
    int? reuseCount,
    List<MediaProjectUsage>? usages,
  }) {
    return UnifiedMediaAsset(
      id: id,
      assetKind: assetKind,
      mimeType: mimeType,
      title: title,
      description: description,
      contentSha256: contentSha256,
      byteSize: byteSize,
      durationSec: durationSec,
      storageObjectPath: storageObjectPath,
      tags: tags ?? this.tags,
      autoTags: autoTags ?? this.autoTags,
      taggingModel: taggingModel ?? this.taggingModel,
      reuseCount: reuseCount ?? this.reuseCount,
      usages: usages ?? this.usages,
      updatedAtIso: updatedAtIso,
    );
  }

  factory UnifiedMediaAsset.fromJson(Map<String, Object?> json) {
    final Object? rawUsages = json['usages'];
    final List<MediaProjectUsage> parsedUsages = <MediaProjectUsage>[];
    if (rawUsages is List<Object?>) {
      for (final Object? entry in rawUsages) {
        if (entry is Map<Object?, Object?>) {
          parsedUsages.add(
            MediaProjectUsage.fromJson(Map<String, Object?>.from(entry)),
          );
        }
      }
    }

    return UnifiedMediaAsset(
      id: (json['id'] as String? ?? '').trim(),
      assetKind: MediaAssetKind.fromWire(json['asset_kind'] as String?),
      mimeType: (json['mime_type'] as String? ?? 'video/mp4').trim(),
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      contentSha256: (json['content_sha256'] as String? ?? '').trim(),
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      storageObjectPath: (json['storage_object_path'] as String? ?? '').trim(),
      tags: _parseTags(json['tags']),
      autoTags: _parseTags(json['auto_tags']),
      taggingModel: AutoTagModelPreference.fromWire(
        json['tagging_model'] as String?,
      ),
      reuseCount: (json['reuse_count'] as num?)?.toInt() ?? 0,
      usages: List<MediaProjectUsage>.unmodifiable(parsedUsages),
      updatedAtIso: (json['updated_at'] as String? ?? '').trim(),
    );
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is! List<Object?>) {
      return const <String>[];
    }
    return raw
        .map((Object? item) => (item ?? '').toString().trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.deduplicated,
    required this.storageUploadSkipped,
    required this.bytesSaved,
    required this.asset,
    this.usage,
  });

  final bool deduplicated;
  final bool storageUploadSkipped;
  final int bytesSaved;
  final UnifiedMediaAsset asset;
  final MediaProjectUsage? usage;
}

/// 統合メディアライブラリ＆ハッシュベース重複排除リポジトリ契約 (#2714)。
abstract class UnifiedMediaLibraryRepository {
  Future<List<UnifiedMediaAsset>> searchAssets({
    String query = '',
    MediaAssetKind? assetKind,
    String? tag,
    String? projectKey,
  });

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
  });

  Future<UnifiedMediaAsset> reuseAssetInProject({
    required UnifiedMediaAsset asset,
    required String projectKey,
    String projectTitle = '',
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
    String notes = '',
  });

  Future<UnifiedMediaAsset> updateAssetTags({
    required UnifiedMediaAsset asset,
    required List<String> tags,
    bool refreshAutoTags = false,
    AutoTagModelPreference aiModel =
        AutoTagModelPreference.deterministicFallback,
  });

  Future<void> deleteAsset(String assetId);
}

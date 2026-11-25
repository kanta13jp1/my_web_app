import 'dart:convert';
import 'dart:typed_data';

/// Gemini Embedding 2 が統合ベクトル空間で扱うモダリティ種別 (#2687)。
enum MultimodalModality {
  all,
  text,
  image,
  audio,
  video,
  pdf,
  mixed;

  String get wireValue => name;

  String get displayLabel {
    switch (this) {
      case MultimodalModality.all:
        return 'すべて';
      case MultimodalModality.text:
        return 'テキスト';
      case MultimodalModality.image:
        return '画像';
      case MultimodalModality.audio:
        return '音声';
      case MultimodalModality.video:
        return '動画';
      case MultimodalModality.pdf:
        return 'PDF';
      case MultimodalModality.mixed:
        return '複合';
    }
  }

  static MultimodalModality fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final MultimodalModality value in MultimodalModality.values) {
      if (value.name == normalized) {
        return value;
      }
    }
    return MultimodalModality.text;
  }
}

/// Embedding 生成モード。GEMINI_API_KEY 未設定時は決定論的フォールバックを用いる。
enum MultimodalEmbeddingMode {
  live,
  offlineFallback;

  static MultimodalEmbeddingMode fromWire(String? raw) {
    return (raw ?? '').trim().toLowerCase() == 'live'
        ? MultimodalEmbeddingMode.live
        : MultimodalEmbeddingMode.offlineFallback;
  }

  String get displayLabel => this == MultimodalEmbeddingMode.live
      ? 'Gemini Embedding 2 (Live)'
      : 'Offline Deterministic Fallback';
}

/// 1x1 透過 PNG の検証済みサンプルバイト列（Web 上の画像クエリ動作確認用）。
final Uint8List kSampleMultimodalPngBytes = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

/// Gemini Embedding 2 の入力上限 (動画120秒・音声180秒・PDF6ページ・テキスト1400文字)
/// に基づきチャンク分割数を事前見積もりする。
int estimateMultimodalChunkCount({
  required String contentText,
  required String mimeType,
  int? durationSec,
  int? pageCount,
}) {
  final String normalizedMime = mimeType.trim().toLowerCase();
  if (normalizedMime.startsWith('video/')) {
    final int sec = durationSec != null && durationSec > 0 ? durationSec : 120;
    return ((sec + 119) ~/ 120).clamp(1, 32);
  }
  if (normalizedMime.startsWith('audio/')) {
    final int sec = durationSec != null && durationSec > 0 ? durationSec : 180;
    return ((sec + 179) ~/ 180).clamp(1, 32);
  }
  if (normalizedMime == 'application/pdf') {
    final int pages = pageCount != null && pageCount > 0 ? pageCount : 1;
    return ((pages + 5) ~/ 6).clamp(1, 32);
  }
  if (normalizedMime.startsWith('image/')) {
    return 1;
  }
  final String trimmed = contentText.trim();
  if (trimmed.isEmpty) {
    return 1;
  }
  const int maxChars = 1400;
  const int overlap = 160;
  if (trimmed.length <= maxChars) {
    return 1;
  }
  const int step = maxChars - overlap;
  final int remaining = trimmed.length - maxChars;
  return (1 + ((remaining + step - 1) ~/ step)).clamp(1, 32);
}

/// 添付画像バイト列が PNG/JPEG のマジックバイトに一致するかを検証する。
bool hasSupportedImageMagicBytes(Uint8List bytes, String mimeType) {
  final String normalized = mimeType.trim().toLowerCase();
  if (normalized == 'image/png') {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
  }
  if (normalized == 'image/jpeg') {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
  return false;
}

class MultimodalQueryRequest {
  const MultimodalQueryRequest({
    required this.queryText,
    this.queryImageBytes,
    this.queryImageMimeType = 'image/png',
    this.queryImageName = '',
    this.modalities = const <MultimodalModality>[],
    this.limit = 10,
  });

  final String queryText;
  final Uint8List? queryImageBytes;
  final String queryImageMimeType;
  final String queryImageName;
  final List<MultimodalModality> modalities;
  final int limit;

  bool get hasImageQuery =>
      queryImageBytes != null && queryImageBytes!.isNotEmpty;

  String? get queryImageBase64 =>
      hasImageQuery ? base64Encode(queryImageBytes!) : null;
}

class MultimodalIngestRequest {
  const MultimodalIngestRequest({
    required this.sourceKey,
    required this.title,
    required this.contentText,
    this.mediaBytes,
    this.mimeType = 'text/plain',
    this.durationSec,
    this.pageCount,
  });

  final String sourceKey;
  final String title;
  final String contentText;
  final Uint8List? mediaBytes;
  final String mimeType;
  final int? durationSec;
  final int? pageCount;

  bool get hasMedia => mediaBytes != null && mediaBytes!.isNotEmpty;

  String? get mediaBase64 => hasMedia ? base64Encode(mediaBytes!) : null;
}

class MultimodalRagItem {
  const MultimodalRagItem({
    required this.id,
    required this.sourceKey,
    required this.title,
    required this.modality,
    required this.mimeType,
    required this.contentText,
    required this.chunkCount,
    required this.embeddingModel,
    required this.embeddingMode,
    this.storageObjectPath,
    this.byteSize = 0,
    this.durationSec,
    this.pageCount,
    this.updatedAtIso = '',
  });

  final String id;
  final String sourceKey;
  final String title;
  final MultimodalModality modality;
  final String mimeType;
  final String contentText;
  final int chunkCount;
  final String embeddingModel;
  final MultimodalEmbeddingMode embeddingMode;
  final String? storageObjectPath;
  final int byteSize;
  final int? durationSec;
  final int? pageCount;
  final String updatedAtIso;

  bool get hasStorageLink =>
      storageObjectPath != null && storageObjectPath!.trim().isNotEmpty;

  factory MultimodalRagItem.fromJson(Map<String, Object?> json) {
    return MultimodalRagItem(
      id: (json['id'] ?? '').toString(),
      sourceKey: (json['source_key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      modality: MultimodalModality.fromWire(json['modality']?.toString()),
      mimeType: (json['mime_type'] ?? 'text/plain').toString(),
      storageObjectPath: json['storage_object_path']?.toString(),
      contentText: (json['content_text'] ?? '').toString(),
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      pageCount: (json['page_count'] as num?)?.toInt(),
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 1,
      embeddingModel:
          (json['embedding_model'] ?? 'gemini-embedding-2').toString(),
      embeddingMode:
          MultimodalEmbeddingMode.fromWire(json['embedding_mode']?.toString()),
      updatedAtIso: (json['updated_at'] ?? '').toString(),
    );
  }
}

class MultimodalSearchHit {
  const MultimodalSearchHit({
    required this.itemId,
    required this.sourceKey,
    required this.title,
    required this.modality,
    required this.mimeType,
    required this.matchedExcerpt,
    required this.chunkCount,
    required this.embeddingModel,
    required this.embeddingMode,
    required this.similarityScore,
    this.storageObjectPath,
    this.signedUrl,
    this.updatedAtIso = '',
  });

  final String itemId;
  final String sourceKey;
  final String title;
  final MultimodalModality modality;
  final String mimeType;
  final String matchedExcerpt;
  final int chunkCount;
  final String embeddingModel;
  final MultimodalEmbeddingMode embeddingMode;
  final double similarityScore;
  final String? storageObjectPath;
  final String? signedUrl;
  final String updatedAtIso;

  bool get hasStorageLink =>
      storageObjectPath != null && storageObjectPath!.trim().isNotEmpty;

  factory MultimodalSearchHit.fromJson(Map<String, Object?> json) {
    return MultimodalSearchHit(
      itemId: (json['item_id'] ?? '').toString(),
      sourceKey: (json['source_key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      modality: MultimodalModality.fromWire(json['modality']?.toString()),
      mimeType: (json['mime_type'] ?? 'text/plain').toString(),
      storageObjectPath: json['storage_object_path']?.toString(),
      matchedExcerpt: (json['matched_excerpt'] ?? '').toString(),
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 1,
      embeddingModel:
          (json['embedding_model'] ?? 'gemini-embedding-2').toString(),
      embeddingMode:
          MultimodalEmbeddingMode.fromWire(json['embedding_mode']?.toString()),
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      signedUrl: json['signed_url']?.toString(),
      updatedAtIso: (json['updated_at'] ?? '').toString(),
    );
  }
}

class MultimodalSearchResult {
  const MultimodalSearchResult({
    required this.queryModality,
    required this.embeddingModel,
    required this.embeddingMode,
    required this.hits,
    this.isSampleData = false,
  });

  final MultimodalModality queryModality;
  final String embeddingModel;
  final MultimodalEmbeddingMode embeddingMode;
  final List<MultimodalSearchHit> hits;
  final bool isSampleData;
}

abstract class MultimodalRagRepository {
  Future<List<MultimodalRagItem>> listItems({int limit = 30});

  Future<MultimodalRagItem> ingestItem(MultimodalIngestRequest request);

  Future<MultimodalSearchResult> search(MultimodalQueryRequest request);

  Future<String> requestSignedUrl(String itemId);

  Future<void> deleteItem(String itemId);
}

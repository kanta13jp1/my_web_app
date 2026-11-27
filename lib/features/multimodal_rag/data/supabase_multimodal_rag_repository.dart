import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/multimodal_rag_models.dart';

/// `media-hub` Edge Function (`multimodal_rag.*`) 経由で Gemini Embedding 2 +
/// pgvector + Supabase Storage 連携を実行するリポジトリ実装 (#2687)。
class SupabaseMultimodalRagRepository implements MultimodalRagRepository {
  SupabaseMultimodalRagRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver;

  final SupabaseClient Function()? _clientResolver;

  final List<MultimodalRagItem> _sampleItems = <MultimodalRagItem>[
    const MultimodalRagItem(
      id: 'sample-mm-1',
      sourceKey: 'manual-rag-diagram',
      title: 'マルチモーダルRAG配線図（サンプル）',
      modality: MultimodalModality.mixed,
      mimeType: 'image/png',
      storageObjectPath: 'sample-user/2026-11-25/manual-rag-diagram.png',
      contentText:
          'Gemini Embedding 2 により画像・動画・テキストを同一 768 次元 pgvector 空間で検索します。',
      byteSize: 2048,
      chunkCount: 1,
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.offlineFallback,
      updatedAtIso: '2026-11-25T04:00:00Z',
    ),
    const MultimodalRagItem(
      id: 'sample-mm-2',
      sourceKey: 'demo-walkthrough-video',
      title: 'UI操作デモ動画 120秒チャンク（サンプル）',
      modality: MultimodalModality.video,
      mimeType: 'video/mp4',
      storageObjectPath: 'sample-user/2026-11-25/demo-walkthrough.mp4',
      contentText: '動画は最大120秒ウィンドウごとにチャンク化され Supabase Storage に安全保管されます。',
      byteSize: 524288,
      durationSec: 120,
      chunkCount: 1,
      embeddingModel: 'gemini-embedding-2',
      embeddingMode: MultimodalEmbeddingMode.offlineFallback,
      updatedAtIso: '2026-11-25T03:30:00Z',
    ),
  ];

  @override
  Future<List<MultimodalRagItem>> listItems({int limit = 30}) async {
    final SupabaseClient? client = _tryResolveSignedInClient();
    if (client == null) {
      return List<MultimodalRagItem>.unmodifiable(_sampleItems.take(limit));
    }

    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: <String, Object?>{
        'action': 'multimodal_rag.list',
        'limit': limit,
      },
    );
    final Map<String, Object?> map = _asJsonMap(response.data);
    final List<Object?> rawItems =
        (map['items'] as List<Object?>?) ?? const <Object?>[];
    return rawItems
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) => MultimodalRagItem.fromJson(
            Map<String, Object?>.from(item),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MultimodalRagItem> ingestItem(MultimodalIngestRequest request) async {
    final SupabaseClient? client = _tryResolveSignedInClient();
    if (client == null) {
      final int chunks = estimateMultimodalChunkCount(
        contentText: request.contentText,
        mimeType: request.mimeType,
        durationSec: request.durationSec,
        pageCount: request.pageCount,
      );
      final MultimodalRagItem created = MultimodalRagItem(
        id: 'sample-mm-${_sampleItems.length + 1}',
        sourceKey: request.sourceKey.trim(),
        title: request.title.trim(),
        modality: _inferModality(request),
        mimeType: request.mimeType,
        storageObjectPath: request.hasMedia
            ? 'sample-user/local/${request.sourceKey.trim()}'
            : null,
        contentText: request.contentText.trim(),
        byteSize: request.mediaBytes?.length ?? request.contentText.length,
        durationSec: request.durationSec,
        pageCount: request.pageCount,
        chunkCount: chunks,
        embeddingModel: 'deterministic-fallback',
        embeddingMode: MultimodalEmbeddingMode.offlineFallback,
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      );
      _sampleItems.insert(0, created);
      return created;
    }

    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: <String, Object?>{
        'action': 'multimodal_rag.ingest',
        'source_key': request.sourceKey.trim(),
        'title': request.title.trim(),
        'content_text': request.contentText.trim(),
        'mime_type': request.mimeType,
        if (request.mediaBase64 != null) 'media_base64': request.mediaBase64,
        if (request.durationSec != null) 'duration_sec': request.durationSec,
        if (request.pageCount != null) 'page_count': request.pageCount,
      },
    );
    final Map<String, Object?> map = _asJsonMap(response.data);
    final Object? rawItem = map['item'];
    if (rawItem is! Map<Object?, Object?>) {
      throw StateError(
        (map['error'] ?? 'Failed to ingest multimodal item').toString(),
      );
    }
    return MultimodalRagItem.fromJson(Map<String, Object?>.from(rawItem));
  }

  @override
  Future<MultimodalSearchResult> search(MultimodalQueryRequest request) async {
    final SupabaseClient? client = _tryResolveSignedInClient();
    if (client == null) {
      return _searchSamples(request);
    }

    final List<String> modalityWires = request.modalities
        .where((MultimodalModality m) => m != MultimodalModality.all)
        .map((MultimodalModality m) => m.wireValue)
        .toList(growable: false);

    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: <String, Object?>{
        'action': 'multimodal_rag.search',
        'query_text': request.queryText.trim(),
        if (request.queryImageBase64 != null)
          'query_image_base64': request.queryImageBase64,
        if (request.hasImageQuery)
          'query_image_mime_type': request.queryImageMimeType,
        if (modalityWires.isNotEmpty) 'modalities': modalityWires,
        'limit': request.limit,
      },
    );
    final Map<String, Object?> map = _asJsonMap(response.data);
    final List<Object?> rawHits =
        (map['hits'] as List<Object?>?) ?? const <Object?>[];
    return MultimodalSearchResult(
      queryModality:
          MultimodalModality.fromWire(map['query_modality']?.toString()),
      embeddingModel:
          (map['embedding_model'] ?? 'gemini-embedding-2').toString(),
      embeddingMode: MultimodalEmbeddingMode.fromWire(
        map['embedding_mode']?.toString(),
      ),
      hits: rawHits
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> h) => MultimodalSearchHit.fromJson(
              Map<String, Object?>.from(h),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<String> requestSignedUrl(String itemId) async {
    final SupabaseClient? client = _tryResolveSignedInClient();
    if (client == null) {
      return 'https://storage.local/signed/$itemId';
    }
    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: <String, Object?>{
        'action': 'multimodal_rag.signed_url',
        'item_id': itemId,
      },
    );
    final Map<String, Object?> map = _asJsonMap(response.data);
    final String url = (map['signed_url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError(
        (map['error'] ?? 'Signed URL unavailable').toString(),
      );
    }
    return url;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final SupabaseClient? client = _tryResolveSignedInClient();
    if (client == null) {
      _sampleItems.removeWhere((MultimodalRagItem item) => item.id == itemId);
      return;
    }
    final FunctionResponse response = await client.functions.invoke(
      'media-hub',
      body: <String, Object?>{
        'action': 'multimodal_rag.delete',
        'item_id': itemId,
      },
    );
    final Map<String, Object?> map = _asJsonMap(response.data);
    if (map['success'] != true) {
      throw StateError((map['error'] ?? 'Delete failed').toString());
    }
  }

  MultimodalSearchResult _searchSamples(MultimodalQueryRequest request) {
    final String needle = request.queryText.trim().toLowerCase();
    final Set<MultimodalModality> filters = request.modalities
        .where((MultimodalModality m) => m != MultimodalModality.all)
        .toSet();

    final List<MultimodalSearchHit> hits = _sampleItems
        .where(
      (MultimodalRagItem item) =>
          filters.isEmpty || filters.contains(item.modality),
    )
        .map((MultimodalRagItem item) {
      final String hay =
          '${item.title} ${item.contentText} ${item.sourceKey}'.toLowerCase();
      double score = 0.42;
      if (request.hasImageQuery && item.hasStorageLink) {
        score += 0.36;
      }
      if (needle.isNotEmpty && hay.contains(needle)) {
        score += 0.21;
      }
      return MultimodalSearchHit(
        itemId: item.id,
        sourceKey: item.sourceKey,
        title: item.title,
        modality: item.modality,
        mimeType: item.mimeType,
        storageObjectPath: item.storageObjectPath,
        matchedExcerpt: item.contentText,
        chunkCount: item.chunkCount,
        embeddingModel: item.embeddingModel,
        embeddingMode: item.embeddingMode,
        similarityScore: score.clamp(0.0, 1.0),
        signedUrl: item.hasStorageLink
            ? 'https://storage.local/signed/${item.id}'
            : null,
        updatedAtIso: item.updatedAtIso,
      );
    }).toList()
      ..sort(
        (MultimodalSearchHit a, MultimodalSearchHit b) =>
            b.similarityScore.compareTo(a.similarityScore),
      );

    return MultimodalSearchResult(
      queryModality: request.hasImageQuery && needle.isNotEmpty
          ? MultimodalModality.mixed
          : (request.hasImageQuery
              ? MultimodalModality.image
              : MultimodalModality.text),
      embeddingModel: 'deterministic-fallback',
      embeddingMode: MultimodalEmbeddingMode.offlineFallback,
      hits: hits.take(request.limit).toList(growable: false),
      isSampleData: true,
    );
  }

  MultimodalModality _inferModality(MultimodalIngestRequest req) {
    if (req.hasMedia && req.contentText.trim().isNotEmpty) {
      return MultimodalModality.mixed;
    }
    if (req.mimeType.startsWith('image/')) return MultimodalModality.image;
    if (req.mimeType.startsWith('audio/')) return MultimodalModality.audio;
    if (req.mimeType.startsWith('video/')) return MultimodalModality.video;
    if (req.mimeType == 'application/pdf') return MultimodalModality.pdf;
    return MultimodalModality.text;
  }

  Map<String, Object?> _asJsonMap(Object? data) {
    if (data is Map<Object?, Object?>) {
      return Map<String, Object?>.from(data);
    }
    return const <String, Object?>{};
  }

  SupabaseClient? _tryResolveSignedInClient() {
    try {
      final SupabaseClient client =
          (_clientResolver ?? () => Supabase.instance.client)();
      if (client.auth.currentUser?.id == null) {
        return null;
      }
      return client;
    } catch (_) {
      return null;
    }
  }
}

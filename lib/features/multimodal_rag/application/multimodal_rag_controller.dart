import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../domain/multimodal_rag_models.dart';

/// マルチモーダル RAG 画面の状態管理コントローラ (#2687)。
class MultimodalRagController extends ChangeNotifier {
  MultimodalRagController({required MultimodalRagRepository repository})
      : _repository = repository;

  final MultimodalRagRepository _repository;

  bool _disposed = false;
  bool isLoading = false;
  bool isSearching = false;
  bool isIngesting = false;

  String statusMessage = '';
  String errorMessage = '';
  MultimodalModality selectedModality = MultimodalModality.all;
  String activeEmbeddingModel = 'gemini-embedding-2';
  MultimodalEmbeddingMode activeEmbeddingMode =
      MultimodalEmbeddingMode.offlineFallback;

  Uint8List? queryImageBytes;
  String queryImageMimeType = 'image/png';
  String queryImageName = '';

  List<MultimodalRagItem> items = const <MultimodalRagItem>[];
  List<MultimodalSearchHit> hits = const <MultimodalSearchHit>[];
  String lastSignedUrl = '';

  bool get hasQueryImage =>
      queryImageBytes != null && queryImageBytes!.isNotEmpty;

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    isLoading = true;
    errorMessage = '';
    _notifySafely();
    try {
      items = await _repository.listItems();
      final MultimodalSearchResult initial = await _repository.search(
        MultimodalQueryRequest(
          queryText: '',
          modalities: _effectiveModalities(),
        ),
      );
      hits = initial.hits;
      activeEmbeddingModel = initial.embeddingModel;
      activeEmbeddingMode = initial.embeddingMode;
      statusMessage = initial.isSampleData
          ? 'マルチモーダルRAGプレビューを表示中です（${items.length}件）。'
          : 'マルチモーダルインデックスを読み込みました（${items.length}件）。';
    } catch (error) {
      errorMessage = 'マルチモーダルインデックスの読込に失敗しました: $error';
    } finally {
      isLoading = false;
      _notifySafely();
    }
  }

  void attachQueryImage({
    required Uint8List bytes,
    required String mimeType,
    String fileName = 'query.png',
  }) {
    if (!hasSupportedImageMagicBytes(bytes, mimeType)) {
      errorMessage = 'PNG または JPEG の有効な画像データを指定してください。';
      _notifySafely();
      return;
    }
    queryImageBytes = bytes;
    queryImageMimeType = mimeType;
    queryImageName = fileName;
    errorMessage = '';
    statusMessage = '画像クエリを添付しました（$fileName / ${bytes.length} bytes）。';
    _notifySafely();
  }

  void clearQueryImage() {
    queryImageBytes = null;
    queryImageName = '';
    statusMessage = '画像クエリを解除しました。';
    _notifySafely();
  }

  void setModalityFilter(MultimodalModality modality) {
    selectedModality = modality;
    _notifySafely();
  }

  Future<void> runSearch(String queryText) async {
    final String cleanText = queryText.trim();
    if (cleanText.isEmpty && !hasQueryImage) {
      errorMessage = 'テキストクエリまたは画像クエリを指定してください。';
      _notifySafely();
      return;
    }
    isSearching = true;
    errorMessage = '';
    _notifySafely();
    try {
      final MultimodalSearchResult result = await _repository.search(
        MultimodalQueryRequest(
          queryText: cleanText,
          queryImageBytes: queryImageBytes,
          queryImageMimeType: queryImageMimeType,
          queryImageName: queryImageName,
          modalities: _effectiveModalities(),
        ),
      );
      hits = result.hits;
      activeEmbeddingModel = result.embeddingModel;
      activeEmbeddingMode = result.embeddingMode;
      statusMessage =
          '${result.queryModality.displayLabel}クエリで ${hits.length}件取得（${activeEmbeddingMode.displayLabel}）。';
    } catch (error) {
      errorMessage = 'マルチモーダル検索に失敗しました: $error';
    } finally {
      isSearching = false;
      _notifySafely();
    }
  }

  Future<bool> ingestItem({
    required String sourceKey,
    required String title,
    required String contentText,
    Uint8List? mediaBytes,
    String mimeType = 'text/plain',
    int? durationSec,
    int? pageCount,
  }) async {
    final String cleanTitle = title.trim();
    final String cleanText = contentText.trim();
    if (cleanTitle.isEmpty) {
      errorMessage = 'タイトルを入力してください。';
      _notifySafely();
      return false;
    }
    if (cleanText.isEmpty && (mediaBytes == null || mediaBytes.isEmpty)) {
      errorMessage = 'テキストまたはメディアデータを入力してください。';
      _notifySafely();
      return false;
    }
    isIngesting = true;
    errorMessage = '';
    _notifySafely();
    try {
      final MultimodalRagItem created = await _repository.ingestItem(
        MultimodalIngestRequest(
          sourceKey: sourceKey.trim().isEmpty
              ? cleanTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '-')
              : sourceKey.trim(),
          title: cleanTitle,
          contentText: cleanText,
          mediaBytes: mediaBytes,
          mimeType: mimeType,
          durationSec: durationSec,
          pageCount: pageCount,
        ),
      );
      items = await _repository.listItems();
      activeEmbeddingModel = created.embeddingModel;
      activeEmbeddingMode = created.embeddingMode;
      statusMessage =
          '「${created.title}」を登録しました（チャンク ${created.chunkCount}件 / Storage連携: ${created.hasStorageLink ? '有効' : 'テキストのみ'}）。';
      return true;
    } catch (error) {
      errorMessage = 'マルチモーダル登録に失敗しました: $error';
      return false;
    } finally {
      isIngesting = false;
      _notifySafely();
    }
  }

  Future<void> refreshSignedUrl(String itemId) async {
    errorMessage = '';
    try {
      lastSignedUrl = await _repository.requestSignedUrl(itemId);
      statusMessage = '署名付き Storage URL を発行しました（有効期限 300秒）。';
    } catch (error) {
      errorMessage = 'Storage URL 発行に失敗しました: $error';
    } finally {
      _notifySafely();
    }
  }

  Future<void> deleteItem(String itemId) async {
    errorMessage = '';
    try {
      await _repository.deleteItem(itemId);
      items = items
          .where((MultimodalRagItem item) => item.id != itemId)
          .toList(growable: false);
      hits = hits
          .where((MultimodalSearchHit hit) => hit.itemId != itemId)
          .toList(growable: false);
      statusMessage = '対象アイテムと関連 Storage オブジェクトを削除しました。';
    } catch (error) {
      errorMessage = 'アイテム削除に失敗しました: $error';
    } finally {
      _notifySafely();
    }
  }

  List<MultimodalModality> _effectiveModalities() {
    if (selectedModality == MultimodalModality.all) {
      return const <MultimodalModality>[];
    }
    return <MultimodalModality>[selectedModality];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

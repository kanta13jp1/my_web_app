import 'package:flutter/foundation.dart';

import '../data/long_form_summary_repository.dart';
import '../domain/long_form_summary_models.dart';

/// 長文自動要約の一覧取得・保存キュー登録・折りたたみ展開を管理する Controller (#2642)。
class LongFormSummaryController extends ChangeNotifier {
  LongFormSummaryController({
    LongFormSummaryRepository? repository,
    List<LongFormDocumentWithSummary>? initialItems,
  })  : _repository = repository ?? const SupabaseLongFormSummaryRepository(),
        _items = List<LongFormDocumentWithSummary>.from(
          initialItems ?? const <LongFormDocumentWithSummary>[],
        );

  final LongFormSummaryRepository _repository;
  final List<LongFormDocumentWithSummary> _items;
  final Set<String> _expandedDocumentIds = <String>{};

  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  String _statusMessage = '';
  String _errorMessage = '';

  List<LongFormDocumentWithSummary> get items =>
      List<LongFormDocumentWithSummary>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  bool isExpanded(String documentId) =>
      _expandedDocumentIds.contains(documentId);

  void toggleExpanded(String documentId) {
    if (_expandedDocumentIds.contains(documentId)) {
      _expandedDocumentIds.remove(documentId);
    } else {
      _expandedDocumentIds.add(documentId);
    }
    _notifySafely();
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final List<LongFormDocumentWithSummary> fetched =
          await _repository.fetchDocuments();
      _items
        ..clear()
        ..addAll(fetched);
      _statusMessage = '長文ドキュメントと要約を ${_items.length} 件読み込みました。';
    } catch (error) {
      if (_items.isEmpty) {
        _items.addAll(_defaultFallbackItems());
      }
      _errorMessage = 'リモート同期に失敗したため、ローカル要約プレビューを表示しています: $error';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<bool> submitDocument({
    required String title,
    required String bodyText,
  }) async {
    final String? validationError = LongFormSummaryBuilder.validateDocument(
      title: title,
      bodyText: bodyText,
    );
    if (validationError != null) {
      _errorMessage = validationError;
      _notifySafely();
      return false;
    }

    _isSaving = true;
    _errorMessage = '';
    _statusMessage = '';
    _notifySafely();

    try {
      final LongFormDocumentWithSummary saved = await _repository.saveDocument(
        title: title.trim(),
        bodyText: bodyText.trim(),
      );
      _items
        ..removeWhere(
          (LongFormDocumentWithSummary item) =>
              item.documentId == saved.documentId,
        )
        ..insert(0, saved);
      _expandedDocumentIds.remove(saved.documentId);
      _statusMessage = saved.status == LongFormSummaryStatus.rateLimited
          ? 'レート制限中のため ${saved.retryAfterSeconds} 秒後に要約が再試行されます。'
          : 'ドキュメントを保存し、要約プレビューを生成キューへ登録しました。';
      return true;
    } catch (error) {
      final String localId = 'local-doc-${_items.length + 1}';
      final String preview = LongFormSummaryBuilder.buildLocalPreviewSummary(
        bodyText,
      );
      _items.insert(
        0,
        LongFormDocumentWithSummary(
          documentId: localId,
          title: title.trim(),
          bodyText: bodyText.trim(),
          charCount: bodyText.trim().length,
          summaryText: preview,
          status: LongFormSummaryStatus.completed,
          modelName: 'extractive-local-v1',
        ),
      );
      _expandedDocumentIds.remove(localId);
      _errorMessage = 'リモート保存に失敗したため、オフライン抽出プレビューを先行作成しました: $error';
      return false;
    } finally {
      _isSaving = false;
      _notifySafely();
    }
  }

  Future<void> refreshDocumentSummary(String documentId) async {
    _errorMessage = '';
    try {
      final LongFormDocumentWithSummary? updated =
          await _repository.fetchByDocumentId(documentId);
      if (updated == null) {
        return;
      }
      final int idx = _items.indexWhere(
        (LongFormDocumentWithSummary item) => item.documentId == documentId,
      );
      if (idx >= 0) {
        _items[idx] = updated;
      } else {
        _items.insert(0, updated);
      }
      _statusMessage = '「${updated.title}」の要約ステータスを更新しました。';
    } catch (error) {
      _errorMessage = '要約状態の再取得に失敗しました: $error';
    } finally {
      _notifySafely();
    }
  }

  static List<LongFormDocumentWithSummary> _defaultFallbackItems() {
    const String sampleBody =
        'Self-Attention 機構を採用した Transformer モデルは、系列長に依存せずトークン間の依存関係を直接計算できるため、'
        '長文コンテンツの主題抽出とコンテキスト要約に適しています。バックグラウンドトリガーにより長文保存直後から自動で要約キューが起動し、'
        'UI では全文を展開する前に生成済み要約プレビューを即時確認できるため、閲覧時の認知負荷を大幅に軽減します。'
        'さらにスライディングウィンドウ型のレート制限ハンドリングを備えており、過負荷時には待機秒数を明示したうえで再試行します。';
    return <LongFormDocumentWithSummary>[
      LongFormDocumentWithSummary(
        documentId: 'sample-long-doc-1',
        title: 'Attention Is All You Need 長文要約サンプル',
        bodyText: sampleBody,
        charCount: sampleBody.length,
        summaryText:
            LongFormSummaryBuilder.buildLocalPreviewSummary(sampleBody),
        status: LongFormSummaryStatus.completed,
        modelName: 'extractive-local-v1',
      ),
    ];
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}

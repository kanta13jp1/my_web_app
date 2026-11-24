import 'package:flutter/foundation.dart';

import '../domain/rls_ai_search_models.dart';

/// RLS 連動 AI 検索・ACL 即時付与/剥奪・プロンプト混入防止コントローラー。
class RlsAiSearchController extends ChangeNotifier {
  RlsAiSearchController({
    required RlsAiSearchRepository repository,
  }) : _repository = repository;

  final RlsAiSearchRepository _repository;

  final List<RlsAiDocumentHit> _hits = <RlsAiDocumentHit>[];
  final List<RlsDocumentAclEntry> _aclEntries = <RlsDocumentAclEntry>[];

  bool _isBusy = false;
  bool _disposed = false;
  int _excludedUnauthorizedCount = 0;
  String _lastQuery = '';
  String _promptContextPreview = '';
  String _statusMessage = '';
  String _errorMessage = '';

  List<RlsAiDocumentHit> get hits => List<RlsAiDocumentHit>.unmodifiable(_hits);
  List<RlsDocumentAclEntry> get aclEntries =>
      List<RlsDocumentAclEntry>.unmodifiable(_aclEntries);
  bool get isBusy => _isBusy;
  int get excludedUnauthorizedCount => _excludedUnauthorizedCount;
  String get lastQuery => _lastQuery;
  String get promptContextPreview => _promptContextPreview;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  int get activeAclCount =>
      _aclEntries.where((RlsDocumentAclEntry e) => e.isActive).length;

  int get revokedAclCount =>
      _aclEntries.where((RlsDocumentAclEntry e) => !e.isActive).length;

  Future<void> runAuthorizedSearch({String query = ''}) async {
    _isBusy = true;
    _errorMessage = '';
    _lastQuery = query.trim();
    _notifySafely();
    try {
      final RlsAiSearchResult result =
          await _repository.searchAuthorizedDocuments(
        query: _lastQuery,
        limit: 10,
      );
      _hits
        ..clear()
        ..addAll(result.hits);
      _aclEntries
        ..clear()
        ..addAll(result.aclEntries);
      _excludedUnauthorizedCount = result.excludedUnauthorizedCount;
      _promptContextPreview = result.promptContextPreview;
      _statusMessage =
          '認可済みソース ${_hits.length} 件を取得（権限外/剥奪済み $_excludedUnauthorizedCount 件を除外）。';
    } catch (error) {
      _errorMessage = 'RLS検索の実行に失敗しました: $error';
      _statusMessage = '';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> toggleAclAccess({
    required RlsDocumentAclEntry entry,
    required bool grantAccess,
    RlsAccessLevel level = RlsAccessLevel.viewer,
  }) async {
    if (!entry.canManage) {
      _errorMessage = 'ACL変更にはドキュメント所有者権限が必要です。';
      _notifySafely();
      return false;
    }
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final RlsDocumentAclEntry updated = await _repository.setAclAccess(
        entry: entry,
        grantAccess: grantAccess,
        level: level,
      );
      final int idx = _aclEntries.indexWhere(
        (RlsDocumentAclEntry item) => item.id == entry.id,
      );
      if (idx >= 0) {
        _aclEntries[idx] = updated;
      }

      final RlsAiSearchResult refreshed =
          await _repository.searchAuthorizedDocuments(
        query: _lastQuery,
        limit: 10,
      );
      _hits
        ..clear()
        ..addAll(refreshed.hits);
      _aclEntries
        ..clear()
        ..addAll(refreshed.aclEntries);
      _excludedUnauthorizedCount = refreshed.excludedUnauthorizedCount;
      _promptContextPreview = refreshed.promptContextPreview;
      _statusMessage = grantAccess
          ? '${updated.externalSourceKey} のアクセス権を付与し、検索インデックスへ即時同期しました (v${updated.aclVersion})。'
          : '${updated.externalSourceKey} のアクセス権を即時剥奪し、AIコンテキストから除外しました (v${updated.aclVersion})。';
      return true;
    } catch (error) {
      _errorMessage = 'ACL同期の更新に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
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

import 'package:flutter/foundation.dart';

import '../domain/realtime_lock_models.dart';

/// Supabase Realtime Presence・ライブ競合検知・楽観的ロック状態制御 (#2744)。
class RealtimeLockController extends ChangeNotifier {
  RealtimeLockController({
    required RealtimeLockRepository repository,
    String sessionId = 'session-local',
    String displayName = '編集ユーザー (自分)',
    List<LockedDocumentRecord>? initialDocuments,
  })  : _repository = repository,
        _sessionId = sessionId,
        _displayName = displayName,
        _documents = List<LockedDocumentRecord>.from(
          initialDocuments ?? const <LockedDocumentRecord>[],
        ) {
    if (_documents.isNotEmpty) {
      _bindDocument(_documents.first, resubscribe: false);
    }
  }

  final RealtimeLockRepository _repository;
  final String _sessionId;
  final String _displayName;
  final List<LockedDocumentRecord> _documents;
  final List<PresenceEditor> _activeEditors = <PresenceEditor>[];

  RealtimeLockSubscriptionHandle? _subscription;
  bool _isBusy = false;
  bool _disposed = false;
  String? _selectedRecordId;
  int _baseRevision = 1;
  String _baseUpdatedAtIso = '';
  String _draftTitle = '';
  String _draftContent = '';
  RevisionAlertEvent? _liveConflictAlert;
  String _statusMessage = '';
  String _errorMessage = '';

  List<LockedDocumentRecord> get documents =>
      List<LockedDocumentRecord>.unmodifiable(_documents);
  List<PresenceEditor> get activeEditors =>
      List<PresenceEditor>.unmodifiable(_activeEditors);
  bool get isBusy => _isBusy;
  String? get selectedRecordId => _selectedRecordId;
  int get baseRevision => _baseRevision;
  String get draftTitle => _draftTitle;
  String get draftContent => _draftContent;
  RevisionAlertEvent? get liveConflictAlert => _liveConflictAlert;
  bool get hasConflict => _liveConflictAlert != null;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  LockedDocumentRecord? get selectedDocument {
    final String? id = _selectedRecordId;
    if (id == null) {
      return _documents.isEmpty ? null : _documents.first;
    }
    for (final LockedDocumentRecord doc in _documents) {
      if (doc.id == id) {
        return doc;
      }
    }
    return _documents.isEmpty ? null : _documents.first;
  }

  void updateDraftTitle(String title) {
    _draftTitle = title;
    _notifySafely();
  }

  void updateDraftContent(String content) {
    _draftContent = content;
    _notifySafely();
  }

  void selectDocument(String recordId) {
    for (final LockedDocumentRecord doc in _documents) {
      if (doc.id == recordId) {
        _bindDocument(doc, resubscribe: true);
        _notifySafely();
        return;
      }
    }
  }

  Future<void> loadDocuments() async {
    _setBusy(true);
    _clearFeedback();
    try {
      final List<LockedDocumentRecord> loaded =
          await _repository.loadDocuments();
      if (_disposed) {
        return;
      }
      _documents
        ..clear()
        ..addAll(loaded);
      final LockedDocumentRecord? current = selectedDocument;
      if (current != null) {
        _bindDocument(current, resubscribe: true);
      } else {
        await _teardownSubscription();
        if (_disposed) {
          return;
        }
      }
      _statusMessage = '${_documents.length} 件のロック対象レコードを読み込みました';
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = error.toString();
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> createDocument({
    required String title,
    required String content,
  }) async {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      _errorMessage = 'ドキュメントタイトルを入力してください';
      _statusMessage = '';
      _notifySafely();
      return false;
    }

    _setBusy(true);
    _clearFeedback();
    try {
      final LockedDocumentRecord created = await _repository.createDocument(
        title: cleanTitle,
        content: content,
        updatedBy: _displayName,
      );
      if (_disposed) {
        return false;
      }
      _documents.insert(0, created);
      _bindDocument(created, resubscribe: true);
      _statusMessage =
          'ドキュメント "${created.title}" (r${created.revision}) を作成しました';
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> saveDraft({bool forceUseServerRevision = false}) async {
    final LockedDocumentRecord? target = selectedDocument;
    if (target == null) {
      _errorMessage = '保存対象のドキュメントを選択してください';
      _statusMessage = '';
      _notifySafely();
      return false;
    }

    final int expectedRev = forceUseServerRevision && _liveConflictAlert != null
        ? _liveConflictAlert!.newRevision
        : _baseRevision;
    final String expectedUpdatedAt =
        forceUseServerRevision && _liveConflictAlert != null
            ? _liveConflictAlert!.updatedAtIso
            : _baseUpdatedAtIso;

    _setBusy(true);
    _clearFeedback();
    try {
      final SaveLockedRecordOutcome outcome =
          await _repository.saveWithOptimisticLock(
        recordId: target.id,
        expectedRevision: expectedRev,
        expectedUpdatedAtIso: expectedUpdatedAt,
        title: _draftTitle.trim().isEmpty ? target.title : _draftTitle.trim(),
        content: _draftContent,
        updatedBy: _displayName,
      );
      if (_disposed) {
        return false;
      }
      if (outcome.conflict) {
        final LockedDocumentRecord? srv = outcome.serverRecord;
        _liveConflictAlert = RevisionAlertEvent(
          recordId: target.id,
          newRevision: outcome.currentRevision ?? srv?.revision ?? expectedRev,
          updatedBy: srv?.updatedBy ?? 'concurrent-editor',
          updatedAtIso: srv?.updatedAtIso ?? '',
          sourceActor: srv?.sourceActor ?? 'remote',
          serverRecord: srv,
        );
        if (srv != null) {
          _upsertDocument(srv);
        }
        _errorMessage = outcome.message;
        return false;
      }

      final LockedDocumentRecord? saved = outcome.record;
      if (saved != null) {
        _upsertDocument(saved);
        _baseRevision = saved.revision;
        _baseUpdatedAtIso = saved.updatedAtIso;
        _draftTitle = saved.title;
        _draftContent = saved.content;
      }
      _liveConflictAlert = null;
      _statusMessage = outcome.message.isNotEmpty
          ? outcome.message
          : '楽観的ロック検証を通過し r$_baseRevision で保存しました';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// サーバー側の最新内容を再読込し、競合アラートを解消する。
  void acceptServerVersion() {
    final LockedDocumentRecord? latest =
        _liveConflictAlert?.serverRecord ?? selectedDocument;
    if (latest == null) {
      return;
    }
    _upsertDocument(latest);
    _baseRevision = latest.revision;
    _baseUpdatedAtIso = latest.updatedAtIso;
    _draftTitle = latest.title;
    _draftContent = latest.content;
    _liveConflictAlert = null;
    _errorMessage = '';
    _statusMessage = 'サーバー最新リビジョン (r${latest.revision}) を再読込しました';
    _notifySafely();
  }

  /// バックグラウンドバッチ等による外部更新を発生させ、リアルタイム競合検知を検証する。
  Future<void> simulateExternalBatchUpdate() async {
    final LockedDocumentRecord? target = selectedDocument;
    if (target == null) {
      _errorMessage = '対象ドキュメントがありません';
      _notifySafely();
      return;
    }
    _setBusy(true);
    _clearFeedback();
    try {
      final LockedDocumentRecord updated = await _repository.triggerBatchUpdate(
        recordId: target.id,
      );
      if (_disposed) {
        return;
      }
      _upsertDocument(updated);
      _handleIncomingRevisionEvent(
        RevisionAlertEvent(
          recordId: updated.id,
          newRevision: updated.revision,
          updatedBy: updated.updatedBy,
          updatedAtIso: updated.updatedAtIso,
          sourceActor: updated.sourceActor,
          serverRecord: updated,
        ),
      );
      _statusMessage =
          '外部バッチ (${updated.updatedBy}) が r${updated.revision} へ更新しました';
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setBusy(false);
    }
  }

  void _bindDocument(
    LockedDocumentRecord doc, {
    required bool resubscribe,
  }) {
    _selectedRecordId = doc.id;
    _baseRevision = doc.revision;
    _baseUpdatedAtIso = doc.updatedAtIso;
    _draftTitle = doc.title;
    _draftContent = doc.content;
    _liveConflictAlert = null;
    if (resubscribe) {
      _resubscribe(doc.id);
    }
  }

  void _resubscribe(String recordId) {
    if (_disposed) {
      return;
    }
    final RealtimeLockSubscriptionHandle? prev = _subscription;
    _subscription = null;
    prev?.dispose();
    _subscription = _repository.subscribeToDocument(
      recordId: recordId,
      sessionId: _sessionId,
      displayName: _displayName,
      onPresenceChanged: _handlePresenceChanged,
      onRevisionChanged: _handleIncomingRevisionEvent,
    );
  }

  void _handlePresenceChanged(List<PresenceEditor> editors) {
    if (_disposed) {
      return;
    }
    _activeEditors
      ..clear()
      ..addAll(editors);
    _notifySafely();
  }

  void _handleIncomingRevisionEvent(RevisionAlertEvent event) {
    if (_disposed || event.recordId != _selectedRecordId) {
      return;
    }
    if (event.serverRecord != null) {
      _upsertDocument(event.serverRecord!);
    }
    if (event.newRevision > _baseRevision) {
      _liveConflictAlert = event;
      _notifySafely();
    }
  }

  void _upsertDocument(LockedDocumentRecord record) {
    final int idx = _documents.indexWhere(
      (LockedDocumentRecord item) => item.id == record.id,
    );
    if (idx >= 0) {
      _documents[idx] = record;
    } else {
      _documents.insert(0, record);
    }
  }

  Future<void> _teardownSubscription() async {
    final RealtimeLockSubscriptionHandle? current = _subscription;
    _subscription = null;
    if (current != null) {
      await current.dispose();
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notifySafely();
  }

  void _clearFeedback() {
    _errorMessage = '';
    _statusMessage = '';
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final RealtimeLockSubscriptionHandle? current = _subscription;
    _subscription = null;
    current?.dispose();
    super.dispose();
  }
}

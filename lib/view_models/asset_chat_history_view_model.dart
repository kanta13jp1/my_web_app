import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/asset_chat.dart';
import '../services/asset_chat_history_repository.dart';

class AssetChatHistoryViewModel extends ChangeNotifier {
  AssetChatHistoryViewModel({required AssetChatHistoryRepository repository})
      : _repository = repository;

  static const int threadPageSize = 50;
  static const int messagePageSize = 100;

  final AssetChatHistoryRepository _repository;
  final List<AssetChatThreadSummary> _threads = [];
  final List<AssetChatStoredMessage> _messages = [];

  bool _isLoadingThreads = false;
  bool _isLoadingMessages = false;
  bool _isDeleting = false;
  bool _hasMoreThreads = false;
  bool _hasOlderMessages = false;
  String _searchQuery = '';
  String? _errorMessage;
  AssetChatThreadSummary? _selectedThread;
  int _threadRequestVersion = 0;
  int _messageRequestVersion = 0;

  UnmodifiableListView<AssetChatThreadSummary> get threads =>
      UnmodifiableListView(_threads);
  UnmodifiableListView<AssetChatStoredMessage> get messages =>
      UnmodifiableListView(_messages);
  bool get isLoadingThreads => _isLoadingThreads;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isDeleting => _isDeleting;
  bool get hasMoreThreads => _hasMoreThreads;
  bool get hasOlderMessages => _hasOlderMessages;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  AssetChatThreadSummary? get selectedThread => _selectedThread;

  Future<void> initialize() => loadThreads(reset: true);

  Future<void> search(String value) async {
    final normalized = value.trim();
    if (normalized == _searchQuery && _threads.isNotEmpty) return;
    _searchQuery = normalized;
    await loadThreads(reset: true);
  }

  Future<void> clearSearch() => search('');

  Future<void> loadThreads({bool reset = false}) async {
    if (_isLoadingThreads && !reset) return;
    if (!reset && !_hasMoreThreads && _threads.isNotEmpty) return;
    final requestVersion = ++_threadRequestVersion;
    _isLoadingThreads = true;
    _errorMessage = null;
    if (reset) {
      _threads.clear();
      _hasMoreThreads = false;
    }
    notifyListeners();

    try {
      final page = await _repository.fetchThreads(
        searchQuery: _searchQuery,
        offset: reset ? 0 : _threads.length,
        limit: threadPageSize,
      );
      if (requestVersion != _threadRequestVersion) return;
      _appendUniqueThreads(page.items);
      _hasMoreThreads = page.hasMore;

      final selectedId = _selectedThread?.id;
      final selectedStillVisible = selectedId != null &&
          _threads.any((thread) => thread.id == selectedId);
      if (!selectedStillVisible) {
        _selectedThread = null;
        _messages.clear();
        _hasOlderMessages = false;
      }
    } catch (error) {
      if (requestVersion == _threadRequestVersion) {
        _errorMessage = _safeError(error);
      }
    } finally {
      if (requestVersion == _threadRequestVersion) {
        _isLoadingThreads = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectThread(AssetChatThreadSummary thread) async {
    final requestVersion = ++_messageRequestVersion;
    _selectedThread = thread;
    _messages.clear();
    _hasOlderMessages = false;
    _isLoadingMessages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _repository.fetchMessages(
        threadId: thread.id,
        limit: messagePageSize,
      );
      if (requestVersion != _messageRequestVersion) return;
      _messages.addAll(page.items.reversed);
      _hasOlderMessages = page.hasMore;
    } catch (error) {
      if (requestVersion == _messageRequestVersion) {
        _errorMessage = _safeError(error);
      }
    } finally {
      if (requestVersion == _messageRequestVersion) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadOlderMessages() async {
    final thread = _selectedThread;
    if (thread == null || _isLoadingMessages || !_hasOlderMessages) return;
    final requestVersion = ++_messageRequestVersion;
    _isLoadingMessages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _repository.fetchMessages(
        threadId: thread.id,
        offset: _messages.length,
        limit: messagePageSize,
      );
      if (requestVersion != _messageRequestVersion ||
          _selectedThread?.id != thread.id) {
        return;
      }
      final knownIds = _messages.map((message) => message.id).toSet();
      final older = page.items
          .where((message) => !knownIds.contains(message.id))
          .toList(growable: false)
          .reversed;
      _messages.insertAll(0, older);
      _hasOlderMessages = page.hasMore;
    } catch (error) {
      if (requestVersion == _messageRequestVersion) {
        _errorMessage = _safeError(error);
      }
    } finally {
      if (requestVersion == _messageRequestVersion) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteThread(AssetChatThreadSummary thread) async {
    if (_isDeleting) return false;
    _isDeleting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteThread(thread.id);
      final wasSelected = _selectedThread?.id == thread.id;
      _threads.removeWhere((item) => item.id == thread.id);
      if (wasSelected) {
        ++_messageRequestVersion;
        _selectedThread = null;
        _messages.clear();
        _hasOlderMessages = false;
      }
      return true;
    } catch (error) {
      _errorMessage = _safeError(error);
      return false;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _appendUniqueThreads(Iterable<AssetChatThreadSummary> items) {
    final knownIds = _threads.map((thread) => thread.id).toSet();
    for (final item in items) {
      if (knownIds.add(item.id)) _threads.add(item);
    }
  }
}

String _safeError(Object error) {
  if (error is AssetChatHistoryRepositoryException) {
    return switch (error.code) {
      'login_required' => 'チャット履歴を表示するにはログインしてください。',
      'thread_not_found' => 'このチャットは見つからないか、既に削除されています。',
      'thread_delete_failed' => 'チャットを削除できませんでした。時間をおいて再試行してください。',
      _ => 'チャット履歴を読み込めませんでした。時間をおいて再試行してください。',
    };
  }
  return 'チャット履歴を読み込めませんでした。時間をおいて再試行してください。';
}

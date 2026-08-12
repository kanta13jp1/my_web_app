import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/musubi_engagement_models.dart';
import 'musubi_engagement_repository.dart';

class MusubiDiscoveryController extends ChangeNotifier {
  MusubiDiscoveryController({required MusubiDiscoveryRepository repository})
      : _repository = repository;

  final MusubiDiscoveryRepository _repository;
  List<MusubiSearchResult> _results = const <MusubiSearchResult>[];
  bool _isSearching = false;
  String _query = '';
  String? _notice;

  List<MusubiSearchResult> get results => List.unmodifiable(_results);
  bool get isSearching => _isSearching;
  String get query => _query;
  String? get notice => _notice;

  Future<void> initialize() => search('');

  Future<void> search(String query) async {
    final normalized = query.trim();
    _query = normalized;
    _isSearching = true;
    _notice = null;
    notifyListeners();
    try {
      _results = await _repository.search(normalized);
      if (_results.isEmpty) _notice = '一致する人・投稿・コミュニティはありませんでした。';
    } catch (_) {
      _notice = '検索に接続できませんでした。時間をおいて再試行してください。';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}

class MusubiMessagesController extends ChangeNotifier {
  MusubiMessagesController({required MusubiMessagingRepository repository})
      : _repository = repository;

  final MusubiMessagingRepository _repository;
  StreamSubscription<List<MusubiDirectMessage>>? _subscription;
  List<MusubiConversation> _conversations = const <MusubiConversation>[];
  List<MusubiDirectMessage> _messages = const <MusubiDirectMessage>[];
  String? _activeThreadId;
  bool _isLoading = false;
  bool _isSending = false;
  String? _notice;

  List<MusubiConversation> get conversations =>
      List.unmodifiable(_conversations);
  List<MusubiDirectMessage> get messages => List.unmodifiable(_messages);
  String? get activeThreadId => _activeThreadId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get notice => _notice;

  MusubiConversation? get activeConversation {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == _activeThreadId,
    );
    return index < 0 ? null : _conversations[index];
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _conversations = await _repository.loadConversations();
      if (_conversations.isNotEmpty) {
        await selectConversation(_conversations.first.id);
      }
    } catch (_) {
      _notice = 'メッセージ一覧を読み込めませんでした。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(String threadId) async {
    if (_activeThreadId == threadId && _messages.isNotEmpty) return;
    _activeThreadId = threadId;
    _isLoading = true;
    _notice = null;
    notifyListeners();
    await _subscription?.cancel();
    try {
      _messages = await _repository.loadMessages(threadId);
      _subscription = _repository.watchMessages(threadId).listen(
        (messages) {
          _messages = messages;
          notifyListeners();
        },
        onError: (_) {
          _notice = 'リアルタイム受信が中断しました。再接続を待っています。';
          notifyListeners();
        },
      );
    } catch (_) {
      _notice = '会話を読み込めませんでした。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String body) async {
    final normalized = body.trim();
    final threadId = _activeThreadId;
    if (normalized.isEmpty || threadId == null || _isSending) return false;
    _isSending = true;
    _notice = null;
    notifyListeners();
    try {
      final message = await _repository.sendMessage(threadId, normalized);
      if (!_messages.any((item) => item.id == message.id)) {
        _messages = <MusubiDirectMessage>[..._messages, message];
      }
      return true;
    } catch (_) {
      _notice = '送信できませんでした。接続を確認してください。';
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> startConversation(MusubiSearchResult person) async {
    final participantId = person.authorId;
    if (participantId == null) return;
    try {
      final threadId = await _repository.startDirectThread(participantId);
      _conversations = await _repository.loadConversations();
      if (!_conversations.any((item) => item.id == threadId)) {
        _conversations = <MusubiConversation>[
          MusubiConversation(
            id: threadId,
            title: person.title,
            handle: person.subtitle.split('・').first.trim(),
            avatarLabel: String.fromCharCodes(person.title.runes.take(2)),
            lastMessage: '会話を始めましょう',
            updatedAt: DateTime.now(),
            participantId: participantId,
          ),
          ..._conversations,
        ];
      }
      await selectConversation(threadId);
    } catch (_) {
      _notice = 'この相手との会話を開始できませんでした。';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class MusubiTrustController extends ChangeNotifier {
  MusubiTrustController({required MusubiTrustRepository repository})
      : _repository = repository;

  final MusubiTrustRepository _repository;
  List<MusubiModerationCase> _queue = const <MusubiModerationCase>[];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _notice;

  List<MusubiModerationCase> get queue => List.unmodifiable(_queue);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get notice => _notice;

  Future<void> initialize() => loadQueue();

  Future<void> loadQueue() async {
    _isLoading = true;
    notifyListeners();
    try {
      _queue = await _repository.loadQueue();
    } catch (_) {
      _queue = const <MusubiModerationCase>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> reportPost({
    required String postId,
    required MusubiReportReason reason,
    String details = '',
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _notice = null;
    notifyListeners();
    try {
      await _repository.reportPost(
        postId: postId,
        reason: reason,
        details: details.trim(),
      );
      _notice = '報告を受け付けました。判断理由と結果は監査ログに残ります。';
      await loadQueue();
      return true;
    } catch (_) {
      _notice = '報告を送信できませんでした。緊急時は地域の相談窓口を利用してください。';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> resolveCase(
    String caseId,
    MusubiModerationStatus status,
  ) async {
    await _repository.resolveCase(caseId, status);
    await loadQueue();
  }
}

class MusubiResearchController extends ChangeNotifier {
  MusubiResearchController({required MusubiResearchRepository repository})
      : _repository = repository;

  final MusubiResearchRepository _repository;
  int _fatigue = 3;
  int _trust = 3;
  int _belonging = 3;
  bool _consent = false;
  MusubiResearchConsent? _activeConsent;
  bool _isSubmitting = false;
  String? _notice;

  int get fatigue => _fatigue;
  int get trust => _trust;
  int get belonging => _belonging;
  bool get consent => _consent;
  bool get hasActiveConsent => _activeConsent != null;
  MusubiResearchConsent? get activeConsent => _activeConsent;
  bool get isSubmitting => _isSubmitting;
  String? get notice => _notice;

  Future<void> initialize() async {
    try {
      _activeConsent = await _repository.loadConsent();
      _consent = _activeConsent != null;
    } catch (_) {
      _notice = '研究同意の状態を確認できませんでした。操作イベントは保存しません。';
    } finally {
      notifyListeners();
    }
  }

  void setFatigue(int value) {
    _fatigue = value.clamp(1, 5);
    notifyListeners();
  }

  void setTrust(int value) {
    _trust = value.clamp(1, 5);
    notifyListeners();
  }

  void setBelonging(int value) {
    _belonging = value.clamp(1, 5);
    notifyListeners();
  }

  void setConsent(bool value) {
    _consent = value;
    notifyListeners();
  }

  Future<bool> submit(String comment) async {
    if (!_consent || _isSubmitting) {
      _notice = '匿名化した研究利用への同意を確認してください。';
      notifyListeners();
      return false;
    }
    _isSubmitting = true;
    _notice = null;
    notifyListeners();
    try {
      await _repository.submitFeedback(
        MusubiResearchFeedback(
          fatigue: _fatigue,
          trust: _trust,
          belonging: _belonging,
          consentToResearch: true,
          comment: comment.trim(),
        ),
      );
      _activeConsent = MusubiResearchConsent(
        cohort: musubiFirstUserCohort,
        consentVersion: musubiResearchConsentVersion,
        consentedAt: DateTime.now(),
      );
      _consent = true;
      _notice = '回答を保存しました。いつでも研究参加を取り消せます。';
      return true;
    } catch (_) {
      _notice = '回答を保存できませんでした。';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> withdraw() async {
    _activeConsent = null;
    _consent = false;
    _isSubmitting = true;
    _notice = null;
    notifyListeners();
    try {
      await _repository.withdrawResearchData();
      _notice = '研究参加を取り消し、保存済みの回答と操作イベントを削除しました。';
    } catch (_) {
      try {
        _activeConsent = await _repository.loadConsent();
        _consent = _activeConsent != null;
      } catch (_) {
        _activeConsent = null;
        _consent = false;
      }
      _notice = '取り消し処理を完了できませんでした。';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> record(
    String name, [
    Map<String, Object?> properties = const {},
  ]) async {
    final activeConsent = _activeConsent;
    if (activeConsent == null) return;
    return _repository.recordEvent(
      MusubiResearchEvent(
        name: name,
        properties: properties,
        cohort: activeConsent.cohort,
        consentVersion: activeConsent.consentVersion,
      ),
    );
  }
}

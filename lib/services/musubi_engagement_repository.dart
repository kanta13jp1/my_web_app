import '../models/musubi_engagement_models.dart';
import '../models/musubi_social_models.dart';
import 'musubi_social_repository.dart';
import 'musubi_supabase_service.dart';

abstract interface class MusubiRealtimeRepository {
  bool get isPreview;
  Stream<List<MusubiPost>> watchFeed();
}

abstract interface class MusubiDiscoveryRepository {
  Future<List<MusubiSearchResult>> search(String query);
}

abstract interface class MusubiMessagingRepository {
  Future<List<MusubiConversation>> loadConversations();
  Future<List<MusubiDirectMessage>> loadMessages(String threadId);
  Stream<List<MusubiDirectMessage>> watchMessages(String threadId);
  Future<MusubiDirectMessage> sendMessage(String threadId, String body);
  Future<String> startDirectThread(String participantId);
}

abstract interface class MusubiTrustRepository {
  Future<void> reportPost({
    required String postId,
    required MusubiReportReason reason,
    required String details,
  });
  Future<List<MusubiModerationCase>> loadQueue();
  Future<void> resolveCase(String caseId, MusubiModerationStatus status);
}

abstract interface class MusubiResearchRepository {
  Future<MusubiResearchConsent?> loadConsent();
  Future<void> submitFeedback(MusubiResearchFeedback feedback);
  Future<void> withdrawResearchData();
  Future<void> recordEvent(MusubiResearchEvent event);
}

class SupabaseMusubiRealtimeRepository implements MusubiRealtimeRepository {
  SupabaseMusubiRealtimeRepository(this._service);

  final MusubiSupabaseService _service;

  @override
  bool get isPreview => !_service.isAuthenticated;

  @override
  Stream<List<MusubiPost>> watchFeed() {
    if (isPreview) return const Stream<List<MusubiPost>>.empty();
    return _service.watchPosts().map(
          (rows) => rows
              .map(
                (row) => musubiPostFromDatabaseRow(
                  row,
                  currentUserId: _service.currentUserId,
                ),
              )
              .where((post) => post.content.isNotEmpty)
              .toList(),
        );
  }
}

class SupabaseMusubiDiscoveryRepository implements MusubiDiscoveryRepository {
  SupabaseMusubiDiscoveryRepository(this._service, this._preview);

  final MusubiSupabaseService _service;
  final PreviewMusubiEngagementRepository _preview;

  @override
  Future<List<MusubiSearchResult>> search(String query) async {
    if (!_service.isAuthenticated) return _preview.search(query);
    try {
      final rows = await _service.search(query);
      return rows.map(_searchResultFromRow).toList();
    } catch (_) {
      return _preview.search(query);
    }
  }
}

class SupabaseMusubiMessagingRepository implements MusubiMessagingRepository {
  SupabaseMusubiMessagingRepository(this._service, this._preview);

  final MusubiSupabaseService _service;
  final PreviewMusubiEngagementRepository _preview;

  @override
  Future<List<MusubiConversation>> loadConversations() async {
    if (!_service.isAuthenticated) return _preview.loadConversations();
    try {
      final rows = await _service.listThreads();
      return rows.map(_conversationFromRow).toList();
    } catch (_) {
      return _preview.loadConversations();
    }
  }

  @override
  Future<List<MusubiDirectMessage>> loadMessages(String threadId) async {
    if (!_service.isAuthenticated || threadId.startsWith('preview-')) {
      return _preview.loadMessages(threadId);
    }
    final rows = await _service.listMessages(threadId);
    return rows
        .map(
          (row) => _messageFromRow(
            row,
            currentUserId: _service.currentUserId,
          ),
        )
        .toList();
  }

  @override
  Stream<List<MusubiDirectMessage>> watchMessages(String threadId) {
    if (!_service.isAuthenticated || threadId.startsWith('preview-')) {
      return _preview.watchMessages(threadId);
    }
    return _service.watchMessages(threadId).map(
          (rows) => rows
              .map(
                (row) => _messageFromRow(
                  row,
                  currentUserId: _service.currentUserId,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<MusubiDirectMessage> sendMessage(
    String threadId,
    String body,
  ) async {
    if (!_service.isAuthenticated || threadId.startsWith('preview-')) {
      return _preview.sendMessage(threadId, body);
    }
    final row = await _service.sendMessage(threadId: threadId, body: body);
    return _messageFromRow(row, currentUserId: _service.currentUserId);
  }

  @override
  Future<String> startDirectThread(String participantId) async {
    if (!_service.isAuthenticated || participantId.startsWith('preview-')) {
      return _preview.startDirectThread(participantId);
    }
    return _service.startDirectThread(participantId);
  }
}

class SupabaseMusubiTrustRepository implements MusubiTrustRepository {
  SupabaseMusubiTrustRepository(this._service, this._preview);

  final MusubiSupabaseService _service;
  final PreviewMusubiEngagementRepository _preview;

  @override
  Future<void> reportPost({
    required String postId,
    required MusubiReportReason reason,
    required String details,
  }) async {
    if (!_service.isAuthenticated || postId.startsWith('preview-')) {
      return _preview.reportPost(
        postId: postId,
        reason: reason,
        details: details,
      );
    }
    await _service.createReport(
      targetPostId: postId,
      reason: reason.name,
      details: details,
    );
  }

  @override
  Future<List<MusubiModerationCase>> loadQueue() async {
    if (!_service.isAuthenticated) return _preview.loadQueue();
    try {
      final rows = await _service.listModerationQueue();
      return rows.map(_moderationCaseFromRow).toList();
    } catch (_) {
      return const <MusubiModerationCase>[];
    }
  }

  @override
  Future<void> resolveCase(
    String caseId,
    MusubiModerationStatus status,
  ) async {
    if (!_service.isAuthenticated || caseId.startsWith('preview-')) {
      return _preview.resolveCase(caseId, status);
    }
    await _service.updateModerationStatus(caseId, status.name);
  }
}

class SupabaseMusubiResearchRepository implements MusubiResearchRepository {
  SupabaseMusubiResearchRepository(this._service, this._preview);

  final MusubiSupabaseService _service;
  final PreviewMusubiEngagementRepository _preview;

  @override
  Future<MusubiResearchConsent?> loadConsent() async {
    if (!_service.isAuthenticated) return _preview.loadConsent();
    final row = await _service.fetchLatestResearchConsent();
    if (row == null) return null;
    return MusubiResearchConsent(
      cohort: row['cohort']?.toString() ?? musubiFirstUserCohort,
      consentVersion:
          row['consent_version']?.toString() ?? musubiResearchConsentVersion,
      consentedAt: DateTime.tryParse(row['consented_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<void> submitFeedback(MusubiResearchFeedback feedback) async {
    if (!_service.isAuthenticated) return _preview.submitFeedback(feedback);
    await _service.insertResearchFeedback(<String, dynamic>{
      'user_id': _service.currentUserId,
      'cohort': feedback.cohort,
      'fatigue_score': feedback.fatigue,
      'trust_score': feedback.trust,
      'belonging_score': feedback.belonging,
      'comment': feedback.comment,
      'consent_to_research': feedback.consentToResearch,
      'consent_version': feedback.consentVersion,
    });
  }

  @override
  Future<void> withdrawResearchData() async {
    if (!_service.isAuthenticated) return _preview.withdrawResearchData();
    await _service.deleteResearchData();
  }

  @override
  Future<void> recordEvent(MusubiResearchEvent event) async {
    if (!_service.isAuthenticated) return _preview.recordEvent(event);
    await _service.insertResearchEvent(<String, dynamic>{
      'user_id': _service.currentUserId,
      'event_name': event.name,
      'properties': event.properties,
      'cohort': event.cohort,
      'consent_version': event.consentVersion,
    });
  }
}

class PreviewMusubiEngagementRepository
    implements
        MusubiRealtimeRepository,
        MusubiDiscoveryRepository,
        MusubiMessagingRepository,
        MusubiTrustRepository,
        MusubiResearchRepository {
  final List<MusubiDirectMessage> _sentMessages = <MusubiDirectMessage>[];
  final List<MusubiModerationCase> _cases = <MusubiModerationCase>[];

  @override
  bool get isPreview => true;

  @override
  Stream<List<MusubiPost>> watchFeed() =>
      const Stream<List<MusubiPost>>.empty();

  @override
  Future<List<MusubiSearchResult>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return musubiPreviewSearchResults();
    return musubiPreviewSearchResults()
        .where(
          (item) =>
              item.title.toLowerCase().contains(normalized) ||
              item.subtitle.toLowerCase().contains(normalized) ||
              (item.highlight?.toLowerCase().contains(normalized) ?? false),
        )
        .toList();
  }

  @override
  Future<List<MusubiConversation>> loadConversations() async =>
      musubiPreviewConversations();

  @override
  Future<List<MusubiDirectMessage>> loadMessages(String threadId) async {
    return <MusubiDirectMessage>[
      ...musubiPreviewMessages(threadId),
      ..._sentMessages.where((message) => message.threadId == threadId),
    ];
  }

  @override
  Stream<List<MusubiDirectMessage>> watchMessages(String threadId) =>
      const Stream<List<MusubiDirectMessage>>.empty();

  @override
  Future<MusubiDirectMessage> sendMessage(String threadId, String body) async {
    final message = MusubiDirectMessage(
      id: 'local-message-${DateTime.now().microsecondsSinceEpoch}',
      threadId: threadId,
      senderId: 'preview-me',
      body: body.trim(),
      createdAt: DateTime.now(),
      isMine: true,
    );
    _sentMessages.add(message);
    return message;
  }

  @override
  Future<String> startDirectThread(String participantId) async =>
      'preview-thread-$participantId';

  @override
  Future<void> reportPost({
    required String postId,
    required MusubiReportReason reason,
    required String details,
  }) async {
    _cases.add(
      MusubiModerationCase(
        id: 'preview-case-${_cases.length + 1}',
        targetPostId: postId,
        reason: reason,
        status: MusubiModerationStatus.open,
        createdAt: DateTime.now(),
        details: details,
      ),
    );
  }

  @override
  Future<List<MusubiModerationCase>> loadQueue() async =>
      List<MusubiModerationCase>.unmodifiable(_cases);

  @override
  Future<void> resolveCase(
    String caseId,
    MusubiModerationStatus status,
  ) async {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index >= 0) _cases[index] = _cases[index].copyWith(status: status);
  }

  @override
  Future<void> submitFeedback(MusubiResearchFeedback feedback) async {}

  @override
  Future<MusubiResearchConsent?> loadConsent() async => null;

  @override
  Future<void> withdrawResearchData() async {}

  @override
  Future<void> recordEvent(MusubiResearchEvent event) async {}
}

MusubiSearchResult _searchResultFromRow(Map<String, dynamic> row) {
  final kindName = row['kind']?.toString() ?? 'post';
  return MusubiSearchResult(
    id: row['id']?.toString() ?? '',
    kind: MusubiSearchKind.values.firstWhere(
      (kind) => kind.name == kindName,
      orElse: () => MusubiSearchKind.post,
    ),
    title: row['title']?.toString() ?? '',
    subtitle: row['subtitle']?.toString() ?? '',
    highlight: row['highlight']?.toString(),
    authorId: row['author_id']?.toString(),
    postId: row['post_id']?.toString(),
  );
}

MusubiConversation _conversationFromRow(Map<String, dynamic> row) {
  return MusubiConversation(
    id: row['thread_id']?.toString() ?? row['id']?.toString() ?? '',
    title: row['display_name']?.toString() ?? 'MUSUBIメンバー',
    handle: '@${row['handle']?.toString() ?? 'member'}',
    avatarLabel: row['avatar_label']?.toString() ?? '結',
    lastMessage: row['last_message']?.toString() ?? '会話を始めましょう',
    updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    participantId: row['participant_id']?.toString(),
    unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
    isOnline: row['is_online'] == true,
  );
}

MusubiDirectMessage _messageFromRow(
  Map<String, dynamic> row, {
  String? currentUserId,
}) {
  final senderId = row['sender_id']?.toString() ?? '';
  return MusubiDirectMessage(
    id: row['id']?.toString() ?? '',
    threadId: row['thread_id']?.toString() ?? '',
    senderId: senderId,
    body: row['body']?.toString() ?? '',
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    isMine: senderId == currentUserId,
  );
}

MusubiModerationCase _moderationCaseFromRow(Map<String, dynamic> row) {
  final rawPost = row['musubi_posts'];
  final post = rawPost is Map
      ? Map<String, dynamic>.from(rawPost)
      : const <String, dynamic>{};
  return MusubiModerationCase(
    id: row['id']?.toString() ?? '',
    targetPostId: row['target_post_id']?.toString() ?? '',
    reason: MusubiReportReason.values.firstWhere(
      (reason) => reason.name == row['reason']?.toString(),
      orElse: () => MusubiReportReason.other,
    ),
    status: MusubiModerationStatus.values.firstWhere(
      (status) => status.name == row['status']?.toString(),
      orElse: () => MusubiModerationStatus.open,
    ),
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    details: row['details']?.toString() ?? '',
    targetExcerpt: post['content']?.toString() ?? '',
  );
}

List<MusubiSearchResult> musubiPreviewSearchResults() =>
    const <MusubiSearchResult>[
      MusubiSearchResult(
        id: 'preview-person-hikari',
        kind: MusubiSearchKind.person,
        title: '佐伯 ひかり',
        subtitle: '@hikari.local ・ 地域の共創プロジェクト',
        highlight: '本人確認済み ・ やさしい未来都市',
        authorId: 'preview-hikari',
      ),
      MusubiSearchResult(
        id: 'preview-community-makers',
        kind: MusubiSearchKind.community,
        title: 'つくる人の広場',
        subtitle: '完成品より途中の学びを共有',
        highlight: '8.1K人 ・ 公開ガバナンス',
      ),
      MusubiSearchResult(
        id: 'preview-post-feed-mixer',
        kind: MusubiSearchKind.post,
        title: 'ユーザーが決めるフィードの実験',
        subtitle: '@maya.builds',
        highlight: '疲労感を減らしながら探索範囲が広がった',
        authorId: 'preview-maya',
        postId: 'preview-2',
      ),
      MusubiSearchResult(
        id: 'preview-post-safety',
        kind: MusubiSearchKind.post,
        title: '地域防災情報の文脈確認',
        subtitle: '@minato.ready',
        highlight: '自治体の一次情報と位置情報の粒度を確認',
        authorId: 'preview-minato',
        postId: 'preview-3',
      ),
    ];

List<MusubiConversation> musubiPreviewConversations() {
  final now = DateTime.now();
  return <MusubiConversation>[
    MusubiConversation(
      id: 'preview-thread-hikari',
      title: '佐伯 ひかり',
      handle: '@hikari.local',
      avatarLabel: '光',
      lastMessage: '安全ガイドラインを共有しました',
      updatedAt: now.subtract(const Duration(minutes: 4)),
      participantId: 'preview-hikari',
      unreadCount: 1,
      isOnline: true,
    ),
    MusubiConversation(
      id: 'preview-thread-maya',
      title: 'Maya Chen',
      handle: '@maya.builds',
      avatarLabel: 'MC',
      lastMessage: 'The mixer data is open for review.',
      updatedAt: now.subtract(const Duration(hours: 2)),
      participantId: 'preview-maya',
    ),
  ];
}

List<MusubiDirectMessage> musubiPreviewMessages(String threadId) {
  final now = DateTime.now();
  if (threadId.contains('maya')) {
    return <MusubiDirectMessage>[
      MusubiDirectMessage(
        id: 'preview-message-maya-1',
        threadId: threadId,
        senderId: 'preview-maya',
        body: 'The feed-mixer dataset is now available for independent review.',
        createdAt: now.subtract(const Duration(hours: 2)),
        isMine: false,
      ),
    ];
  }
  return <MusubiDirectMessage>[
    MusubiDirectMessage(
      id: 'preview-message-hikari-1',
      threadId: threadId,
      senderId: 'preview-hikari',
      body: '工作室の安全ガイドラインを共有しました。気になる点を教えてください。',
      createdAt: now.subtract(const Duration(minutes: 12)),
      isMine: false,
    ),
    MusubiDirectMessage(
      id: 'preview-message-hikari-2',
      threadId: threadId,
      senderId: 'preview-me',
      body: '確認しました。工具を使う時間帯の見守り人数も追記できますか？',
      createdAt: now.subtract(const Duration(minutes: 7)),
      isMine: true,
    ),
  ];
}

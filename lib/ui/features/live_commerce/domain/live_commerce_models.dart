enum LiveCommerceRole { viewer, host }

enum LiveCommerceConnectionState {
  preview,
  connecting,
  connected,
  syncing,
  degraded,
}

enum LiveCommerceEventType {
  viewerQuestion,
  questionHighlighted,
  questionUnhighlighted,
  productPushed,
  purchaseAnnounced,
}

class LiveCommerceQuestion {
  const LiveCommerceQuestion({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.isHighlighted = false,
  });

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final bool isHighlighted;

  LiveCommerceQuestion copyWith({bool? isHighlighted}) {
    return LiveCommerceQuestion(
      id: id,
      authorName: authorName,
      body: body,
      createdAt: createdAt,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}

class LiveCommerceEvent {
  const LiveCommerceEvent({
    required this.id,
    required this.roomId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.schemaVersion = 1,
    this.question,
    this.questionId,
    this.productId,
    this.announcement,
  });

  final String id;
  final String roomId;
  final int sequence;
  final LiveCommerceEventType type;
  final DateTime occurredAt;
  final int schemaVersion;
  final LiveCommerceQuestion? question;
  final String? questionId;
  final String? productId;
  final String? announcement;
}

class LiveCommerceRoomSnapshot {
  const LiveCommerceRoomSnapshot({
    required this.roomId,
    required this.title,
    required this.hostName,
    required this.role,
    required this.isLive,
    required this.featuredProductId,
    required this.questions,
    required this.purchaseAnnouncements,
    required this.lastSequence,
    this.appliedEventIds = const <String>{},
    this.syncMessage,
  });

  final String roomId;
  final String title;
  final String hostName;
  final LiveCommerceRole role;
  final bool isLive;
  final String? featuredProductId;
  final List<LiveCommerceQuestion> questions;
  final List<String> purchaseAnnouncements;
  final int lastSequence;
  final Set<String> appliedEventIds;
  final String? syncMessage;

  bool get needsResync => syncMessage != null;

  LiveCommerceRoomSnapshot copyWith({
    String? featuredProductId,
    bool clearFeaturedProduct = false,
    List<LiveCommerceQuestion>? questions,
    List<String>? purchaseAnnouncements,
    int? lastSequence,
    Set<String>? appliedEventIds,
    String? syncMessage,
    bool clearSyncMessage = false,
  }) {
    return LiveCommerceRoomSnapshot(
      roomId: roomId,
      title: title,
      hostName: hostName,
      role: role,
      isLive: isLive,
      featuredProductId: clearFeaturedProduct
          ? null
          : featuredProductId ?? this.featuredProductId,
      questions: questions ?? this.questions,
      purchaseAnnouncements:
          purchaseAnnouncements ?? this.purchaseAnnouncements,
      lastSequence: lastSequence ?? this.lastSequence,
      appliedEventIds: appliedEventIds ?? this.appliedEventIds,
      syncMessage: clearSyncMessage ? null : syncMessage ?? this.syncMessage,
    );
  }
}

/// Applies only contiguous, supported server events.
///
/// Realtime delivery is treated as a notification stream, not as an
/// authoritative ledger. A gap or an unsupported schema version pauses
/// application until the gateway returns a fresh snapshot.
abstract final class LiveCommerceEventReducer {
  static const supportedSchemaVersion = 1;
  static const _recentEventLimit = 256;

  static LiveCommerceRoomSnapshot apply(
    LiveCommerceRoomSnapshot snapshot,
    LiveCommerceEvent event,
  ) {
    if (event.roomId != snapshot.roomId) return snapshot;
    if (snapshot.appliedEventIds.contains(event.id) ||
        event.sequence <= snapshot.lastSequence) {
      return snapshot;
    }
    if (event.schemaVersion != supportedSchemaVersion) {
      return snapshot.copyWith(syncMessage: '新しいイベント形式を受信しました。再同期が必要です。');
    }
    if (event.sequence != snapshot.lastSequence + 1) {
      return snapshot.copyWith(syncMessage: 'ライブ更新に欠落を検出しました。再同期しています。');
    }

    var questions = snapshot.questions;
    var announcements = snapshot.purchaseAnnouncements;
    var featuredProductId = snapshot.featuredProductId;

    switch (event.type) {
      case LiveCommerceEventType.viewerQuestion:
        final question = event.question;
        if (question != null &&
            !questions.any((candidate) => candidate.id == question.id)) {
          questions = <LiveCommerceQuestion>[question, ...questions];
        }
      case LiveCommerceEventType.questionHighlighted:
      case LiveCommerceEventType.questionUnhighlighted:
        final questionId = event.questionId;
        if (questionId != null) {
          final highlighted =
              event.type == LiveCommerceEventType.questionHighlighted;
          questions = questions
              .map(
                (question) => question.id == questionId
                    ? question.copyWith(isHighlighted: highlighted)
                    : question,
              )
              .toList(growable: false);
        }
      case LiveCommerceEventType.productPushed:
        final productId = event.productId?.trim();
        if (productId != null && productId.isNotEmpty) {
          featuredProductId = productId;
        }
      case LiveCommerceEventType.purchaseAnnounced:
        final announcement = event.announcement?.trim();
        if (announcement != null && announcement.isNotEmpty) {
          announcements = <String>[
            announcement,
            ...announcements,
          ].take(5).toList(growable: false);
        }
    }

    final recentEventIds = <String>[...snapshot.appliedEventIds, event.id];
    final boundedEventIds = recentEventIds.length <= _recentEventLimit
        ? recentEventIds
        : recentEventIds.sublist(recentEventIds.length - _recentEventLimit);
    return snapshot.copyWith(
      featuredProductId: featuredProductId,
      questions: questions,
      purchaseAnnouncements: announcements,
      lastSequence: event.sequence,
      appliedEventIds: boundedEventIds.toSet(),
      clearSyncMessage: true,
    );
  }
}

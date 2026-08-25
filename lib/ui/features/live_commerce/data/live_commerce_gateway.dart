import 'dart:async';

import '../domain/live_commerce_models.dart';

abstract interface class LiveCommerceGateway {
  bool get isPreview;

  Future<LiveCommerceRoomSnapshot> loadRoom(
    String roomId, {
    String? preferredProductId,
  });

  Stream<LiveCommerceEvent> watchEvents(
    String roomId, {
    required int afterSequence,
  });

  Future<LiveCommerceEvent> sendQuestion({
    required String roomId,
    required String body,
  });

  Future<LiveCommerceEvent> setQuestionHighlighted({
    required String roomId,
    required String questionId,
    required bool highlighted,
  });

  Future<LiveCommerceEvent> pushProduct({
    required String roomId,
    required String productId,
  });
}

/// Safe local preview used until room membership, moderation, retention and
/// Realtime RLS have an approved production contract.
class PreviewLiveCommerceGateway implements LiveCommerceGateway {
  PreviewLiveCommerceGateway({
    this.role = LiveCommerceRole.viewer,
    this.defaultProductId = 'hexciv-win64',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LiveCommerceRole role;
  final String defaultProductId;
  final DateTime Function() _now;
  int _sequence = 2;

  @override
  bool get isPreview => true;

  @override
  Future<LiveCommerceRoomSnapshot> loadRoom(
    String roomId, {
    String? preferredProductId,
  }) async {
    final current = _now();
    return LiveCommerceRoomSnapshot(
      roomId: roomId,
      title: '制作スタジオ・ライブ',
      hostName: 'MY WEB APP ストア',
      role: role,
      isLive: false,
      featuredProductId: preferredProductId?.trim().isNotEmpty == true
          ? preferredProductId!.trim()
          : defaultProductId,
      questions: <LiveCommerceQuestion>[
        LiveCommerceQuestion(
          id: 'preview-question-2',
          authorName: '視聴者B',
          body: '購入後はどこから再ダウンロードできますか？',
          createdAt: current.subtract(const Duration(minutes: 2)),
          isHighlighted: true,
        ),
        LiveCommerceQuestion(
          id: 'preview-question-1',
          authorName: '視聴者A',
          body: '対応環境を教えてください。',
          createdAt: current.subtract(const Duration(minutes: 4)),
        ),
      ],
      purchaseAnnouncements: const <String>[],
      lastSequence: _sequence,
    );
  }

  @override
  Stream<LiveCommerceEvent> watchEvents(
    String roomId, {
    required int afterSequence,
  }) {
    return const Stream<LiveCommerceEvent>.empty();
  }

  @override
  Future<LiveCommerceEvent> sendQuestion({
    required String roomId,
    required String body,
  }) async {
    final sequence = ++_sequence;
    return LiveCommerceEvent(
      id: 'preview-event-$sequence',
      roomId: roomId,
      sequence: sequence,
      type: LiveCommerceEventType.viewerQuestion,
      occurredAt: _now(),
      question: LiveCommerceQuestion(
        id: 'preview-question-$sequence',
        authorName: 'あなた（プレビュー）',
        body: body,
        createdAt: _now(),
      ),
    );
  }

  @override
  Future<LiveCommerceEvent> setQuestionHighlighted({
    required String roomId,
    required String questionId,
    required bool highlighted,
  }) async {
    _requireHost();
    final sequence = ++_sequence;
    return LiveCommerceEvent(
      id: 'preview-event-$sequence',
      roomId: roomId,
      sequence: sequence,
      type: highlighted
          ? LiveCommerceEventType.questionHighlighted
          : LiveCommerceEventType.questionUnhighlighted,
      occurredAt: _now(),
      questionId: questionId,
    );
  }

  @override
  Future<LiveCommerceEvent> pushProduct({
    required String roomId,
    required String productId,
  }) async {
    _requireHost();
    final sequence = ++_sequence;
    return LiveCommerceEvent(
      id: 'preview-event-$sequence',
      roomId: roomId,
      sequence: sequence,
      type: LiveCommerceEventType.productPushed,
      occurredAt: _now(),
      productId: productId,
    );
  }

  void _requireHost() {
    if (role != LiveCommerceRole.host) {
      throw const LiveCommerceException('配信者だけが操作できます。');
    }
  }
}

class LiveCommerceException implements Exception {
  const LiveCommerceException(this.message);

  final String message;

  @override
  String toString() => message;
}

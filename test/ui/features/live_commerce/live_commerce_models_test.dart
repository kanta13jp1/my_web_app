import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/live_commerce/domain/live_commerce_models.dart';

void main() {
  group('LiveCommerceEventReducer', () {
    test('applies contiguous events and ignores duplicate delivery', () {
      final initial = _snapshot(lastSequence: 4);
      final event = LiveCommerceEvent(
        id: 'event-5',
        roomId: 'room-1',
        sequence: 5,
        type: LiveCommerceEventType.viewerQuestion,
        occurredAt: DateTime(2026, 8, 26, 12),
        question: LiveCommerceQuestion(
          id: 'question-5',
          authorName: '視聴者',
          body: '再ダウンロードできますか？',
          createdAt: DateTime(2026, 8, 26, 12),
        ),
      );

      final applied = LiveCommerceEventReducer.apply(initial, event);
      final duplicate = LiveCommerceEventReducer.apply(applied, event);

      expect(applied.lastSequence, 5);
      expect(applied.questions.single.id, 'question-5');
      expect(duplicate.lastSequence, 5);
      expect(duplicate.questions, hasLength(1));
    });

    test('pauses application when a sequence gap is detected', () {
      final initial = _snapshot(lastSequence: 4);
      final event = LiveCommerceEvent(
        id: 'event-7',
        roomId: 'room-1',
        sequence: 7,
        type: LiveCommerceEventType.productPushed,
        occurredAt: DateTime(2026, 8, 26, 12),
        productId: 'new-product',
      );

      final result = LiveCommerceEventReducer.apply(initial, event);

      expect(result.lastSequence, 4);
      expect(result.featuredProductId, 'product-1');
      expect(result.needsResync, isTrue);
      expect(result.syncMessage, contains('欠落'));
    });

    test('rejects unsupported event schema without changing state', () {
      final initial = _snapshot(lastSequence: 4);
      final event = LiveCommerceEvent(
        id: 'event-5',
        roomId: 'room-1',
        sequence: 5,
        schemaVersion: 2,
        type: LiveCommerceEventType.purchaseAnnounced,
        occurredAt: DateTime(2026, 8, 26, 12),
        announcement: '購入されました',
      );

      final result = LiveCommerceEventReducer.apply(initial, event);

      expect(result.lastSequence, 4);
      expect(result.purchaseAnnouncements, isEmpty);
      expect(result.needsResync, isTrue);
      expect(result.syncMessage, contains('イベント形式'));
    });

    test('highlight state is reversible and purchase copy is bounded', () {
      var state = _snapshot(
        lastSequence: 1,
        questions: <LiveCommerceQuestion>[
          LiveCommerceQuestion(
            id: 'question-1',
            authorName: '視聴者',
            body: '質問',
            createdAt: DateTime(2026, 8, 26, 12),
          ),
        ],
      );
      state = LiveCommerceEventReducer.apply(
        state,
        LiveCommerceEvent(
          id: 'event-2',
          roomId: 'room-1',
          sequence: 2,
          type: LiveCommerceEventType.questionHighlighted,
          occurredAt: DateTime(2026, 8, 26, 12),
          questionId: 'question-1',
        ),
      );
      state = LiveCommerceEventReducer.apply(
        state,
        LiveCommerceEvent(
          id: 'event-3',
          roomId: 'room-1',
          sequence: 3,
          type: LiveCommerceEventType.questionUnhighlighted,
          occurredAt: DateTime(2026, 8, 26, 12),
          questionId: 'question-1',
        ),
      );
      for (var sequence = 4; sequence <= 10; sequence++) {
        state = LiveCommerceEventReducer.apply(
          state,
          LiveCommerceEvent(
            id: 'event-$sequence',
            roomId: 'room-1',
            sequence: sequence,
            type: LiveCommerceEventType.purchaseAnnounced,
            occurredAt: DateTime(2026, 8, 26, 12),
            announcement: '購入のお知らせ $sequence',
          ),
        );
      }

      expect(state.questions.single.isHighlighted, isFalse);
      expect(state.purchaseAnnouncements, hasLength(5));
      expect(state.purchaseAnnouncements.first, '購入のお知らせ 10');
    });

    test('keeps only a bounded recent event id window', () {
      var state = _snapshot(lastSequence: 0);
      for (var sequence = 1; sequence <= 300; sequence++) {
        state = LiveCommerceEventReducer.apply(
          state,
          LiveCommerceEvent(
            id: 'event-$sequence',
            roomId: 'room-1',
            sequence: sequence,
            type: LiveCommerceEventType.productPushed,
            occurredAt: DateTime(2026, 8, 26, 12),
            productId: 'product-1',
          ),
        );
      }

      expect(state.appliedEventIds, hasLength(256));
      expect(state.appliedEventIds, isNot(contains('event-1')));
      expect(state.appliedEventIds, contains('event-300'));
    });
  });
}

LiveCommerceRoomSnapshot _snapshot({
  required int lastSequence,
  List<LiveCommerceQuestion> questions = const <LiveCommerceQuestion>[],
}) {
  return LiveCommerceRoomSnapshot(
    roomId: 'room-1',
    title: 'ライブ',
    hostName: '配信者',
    role: LiveCommerceRole.viewer,
    isLive: true,
    featuredProductId: 'product-1',
    questions: questions,
    purchaseAnnouncements: const <String>[],
    lastSequence: lastSequence,
  );
}

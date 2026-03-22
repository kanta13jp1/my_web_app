import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/behavior_review_service.dart';

void main() {
  group('BehaviorReviewService', () {
    test('maps wealth struggles into action entries', () {
      final entry = BehaviorReviewService.mapWealthStruggle({
        'id': '1',
        'action_type': 'expense',
        'amount': 4800,
        'description': '[現金] ビール [浪費:飲酒]',
        'occurred_at': '2026-03-22T10:00:00.000Z',
      });

      expect(entry, isNotNull);
      expect(entry!.kind, BehaviorReviewEntryKind.action);
      expect(entry.source, '資産管理');
      expect(entry.title, contains('浪費・飲酒'));
      expect(entry.detail, '[現金] ビール');
    });

    test('maps notes into utterance entries', () {
      final entry = BehaviorReviewService.mapNote({
        'id': 'n1',
        'title': '会議メモ',
        'content': '次回は感情で反応せず、論点を先に整理してから話す。',
        'created_at': '2026-03-22T09:00:00.000Z',
      });

      expect(entry, isNotNull);
      expect(entry!.kind, BehaviorReviewEntryKind.utterance);
      expect(entry.source, 'メモ');
      expect(entry.title, '会議メモ');
    });

    test('builds reflection prompt with headings and logs', () {
      final prompt = BehaviorReviewService.buildReflectionPrompt(
        [
          BehaviorReviewEntry(
            id: 'a1',
            kind: BehaviorReviewEntryKind.action,
            source: '資産管理',
            title: '浪費・飲酒 ¥4,800',
            detail: '[現金] ビール',
            timestamp: DateTime(2026, 3, 22, 10, 30),
          ),
        ],
        days: 30,
      );

      expect(prompt, contains('直近30日間'));
      expect(prompt, contains('1. 全体所見'));
      expect(prompt, contains('浪費・飲酒'));
    });
  });
}

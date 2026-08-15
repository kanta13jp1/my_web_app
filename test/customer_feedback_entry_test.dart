import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/customer_feedback_entry.dart';

void main() {
  group('parseCustomerFeedback', () {
    test('parses nested metadata comment from EF response', () {
      final entries = parseCustomerFeedback({
        'success': true,
        'feedbacks': [
          {
            'id': 'a',
            'metadata': {
              'type': 'general',
              'rating': 4,
              'comment': 'とても使いやすい',
              'feature': 'dashboard',
              'status': 'open',
              'user_id': 'u1',
            },
            'created_at': '2026-07-10T09:00:00Z',
          },
        ],
      });

      final e = entries.single;
      expect(e.comment, 'とても使いやすい');
      expect(e.displayText, 'とても使いやすい');
      expect(e.type, 'general');
      expect(e.rating, 4);
      expect(e.feature, 'dashboard');
      expect(e.status, 'open');
      expect(e.createdAt, '2026-07-10T09:00:00Z');
    });

    test(
        'does NOT render the raw row map as text '
        '(regression: old code fell through to item.toString())', () {
      // 旧実装は item['feedback']/['text']/['content'] を読み、いずれも無いため
      // item.toString() = 行 Map 全体を見出しに描画していた。
      final entries = parseCustomerFeedback({
        'feedbacks': [
          {
            'id': 'abc',
            'metadata': {'comment': '改善してほしい点があります', 'type': 'bug'},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      final e = entries.single;
      expect(e.displayText, '改善してほしい点があります');
      expect(
        e.displayText,
        isNot(contains('metadata')),
        reason: '生の行 Map を描画してはならない',
      );
      expect(
        e.displayText,
        isNot(contains('{')),
        reason: 'Map の toString を描画してはならない',
      );
    });

    test('falls back through legacy flat keys', () {
      final entries = parseCustomerFeedback({
        'feedbacks': [
          {'feedback': '旧形式コメント', 'created_at': ''},
        ],
      });
      expect(entries.single.comment, '旧形式コメント');
    });

    test('uses placeholder when comment is missing (no map dump)', () {
      final entries = parseCustomerFeedback({
        'feedbacks': [
          {
            'metadata': {'type': 'general', 'rating': 5},
            'created_at': '',
          },
        ],
      });
      final e = entries.single;
      expect(e.comment, '');
      expect(e.displayText, '(コメントなし)');
      expect(e.rating, 5);
    });

    test('handles null / malformed / bare list responses', () {
      expect(parseCustomerFeedback(null), isEmpty);
      expect(parseCustomerFeedback('oops'), isEmpty);
      final bare = parseCustomerFeedback([
        {
          'metadata': {'comment': 'A'},
          'created_at': '',
        },
      ]);
      expect(bare.single.comment, 'A');
    });
  });
}

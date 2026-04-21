import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_fsrs_service.dart';

void main() {
  group('AiFsrsService', () {
    test('gradeLabel returns Japanese labels for normalized FSRS grades', () {
      expect(AiFsrsService.gradeLabel(1), 'もう一度');
      expect(AiFsrsService.gradeLabel(2), '難しい');
      expect(AiFsrsService.gradeLabel(3), '覚えた');
      expect(AiFsrsService.gradeLabel(4), '簡単');
      expect(AiFsrsService.gradeLabel(0), 'もう一度');
      expect(AiFsrsService.gradeLabel(5), '簡単');
    });

    test('normalizeGrade clamps invalid client values before edge call', () {
      expect(AiFsrsService.normalizeGrade(-2), 1);
      expect(AiFsrsService.normalizeGrade(0), 1);
      expect(AiFsrsService.normalizeGrade(1), 1);
      expect(AiFsrsService.normalizeGrade(4), 4);
      expect(AiFsrsService.normalizeGrade(99), 4);
    });

    test('nextDueLabel uses calendar days instead of elapsed hours', () {
      final now = DateTime(2026, 4, 21, 23, 50);

      expect(
        AiFsrsService.nextDueLabel(DateTime(2026, 4, 21, 8), now: now),
        '今日',
      );
      expect(
        AiFsrsService.nextDueLabel(DateTime(2026, 4, 22, 0, 10), now: now),
        '明日',
      );
      expect(
        AiFsrsService.nextDueLabel(DateTime(2026, 4, 24, 9), now: now),
        '3日後',
      );
    });
  });

  group('FsrsCard', () {
    test('fromJson reads Supabase FSRS payload and defaults state', () {
      final card = FsrsCard.fromJson({
        'question_id': 'q-1',
        'provider': 'openai',
        'due_date': '2026-04-22T00:00:00Z',
        'stability': 2,
      });

      expect(card.questionId, 'q-1');
      expect(card.provider, 'openai');
      expect(card.dueDate.toUtc(), DateTime.utc(2026, 4, 22));
      expect(card.stability, 2.0);
      expect(card.state, 'new');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/english_reading_models.dart';

void main() {
  group('countEnglishWords', () {
    test('counts whitespace-separated tokens', () {
      expect(countEnglishWords('Hello world'), 2);
      expect(countEnglishWords('  a   b  c '), 3);
      expect(countEnglishWords('one\ntwo\tthree four'), 4);
    });

    test('empty or blank text is zero', () {
      expect(countEnglishWords(''), 0);
      expect(countEnglishWords('    '), 0);
    });
  });

  group('kEnglishReadingLevels', () {
    test('has 6 ascending levels with ascending target wpm', () {
      expect(kEnglishReadingLevels.length, 6);
      for (var i = 1; i < kEnglishReadingLevels.length; i++) {
        expect(
          kEnglishReadingLevels[i].targetWpm >
              kEnglishReadingLevels[i - 1].targetWpm,
          isTrue,
        );
        expect(
          kEnglishReadingLevels[i].level,
          kEnglishReadingLevels[i - 1].level + 1,
        );
      }
      expect(kEnglishReadingLevels.last.targetWpm, kNativeReadingWpm);
    });
  });

  group('englishReadingLevelOf', () {
    test('returns the matching level', () {
      expect(englishReadingLevelOf(3).cefr, 'B1+');
      expect(englishReadingLevelOf(6).labelJa, 'ネイティブ速度');
    });

    test('clamps out-of-range levels to the nearest edge', () {
      expect(englishReadingLevelOf(0).level, 1);
      expect(englishReadingLevelOf(99).level, 6);
    });
  });

  group('EnglishReadingLesson.fromJson', () {
    test('parses fields, questions and derives word count from passage', () {
      final lesson = EnglishReadingLesson.fromJson(const <String, dynamic>{
        'id': 'uuid-1',
        'lesson_code': 'L1-01',
        'level': 1,
        'cefr': 'A2',
        'title': 'A Morning Walk',
        'topic': 'daily life',
        'target_wpm': 100,
        'passage': 'Every morning Mia takes a walk',
        'word_count': 999,
        'source': 'seed',
        'questions': <dynamic>[
          <String, dynamic>{
            'q': 'When?',
            'choices': <dynamic>['Morning', 'Night', 'Noon', 'Dawn'],
            'answer_index': 0,
            'explanation': 'It is a morning walk.',
          },
        ],
      });

      expect(lesson.lessonCode, 'L1-01');
      expect(lesson.level, 1);
      expect(lesson.targetWpm, 100);
      // word count derived from the passage (6 words), not the declared 999.
      expect(lesson.wordCount, 6);
      expect(lesson.isAiGenerated, isFalse);
      expect(lesson.questions.length, 1);
      expect(lesson.questions.first.choices.length, 4);
      expect(lesson.questions.first.answerIndex, 0);
    });

    test('falls back to declared word count when passage is empty', () {
      final lesson = EnglishReadingLesson.fromJson(const <String, dynamic>{
        'lesson_code': 'AI-1',
        'level': 5,
        'passage': '',
        'word_count': 42,
        'source': 'ai',
      });
      expect(lesson.wordCount, 42);
      expect(lesson.isAiGenerated, isTrue);
      expect(lesson.questions, isEmpty);
    });

    test('clamps an out-of-range answer_index into the choices range', () {
      final lesson = EnglishReadingLesson.fromJson(const <String, dynamic>{
        'lesson_code': 'AI-2',
        'level': 3,
        'passage': 'one two three',
        'questions': <dynamic>[
          <String, dynamic>{
            'q': 'bogus index?',
            'choices': <dynamic>['a', 'b', 'c', 'd'],
            'answer_index': 9,
          },
        ],
        'source': 'ai',
      });
      // 9 is out of range for 4 choices -> clamped to 3 (last valid index).
      expect(lesson.questions.first.answerIndex, 3);
    });
  });

  group('EnglishReadingAttempt.fromJson', () {
    test('parses numeric fields and timestamp', () {
      final attempt = EnglishReadingAttempt.fromJson(const <String, dynamic>{
        'id': 'x',
        'lesson_code': 'L2-01',
        'level': 2,
        'mode': 'measure',
        'word_count': 120,
        'elapsed_ms': 48000,
        'wpm': 150,
        'comprehension_correct': 3,
        'comprehension_total': 4,
        'effective_wpm': 113,
        'created_at': '2026-06-20T01:02:03Z',
      });
      expect(attempt.level, 2);
      expect(attempt.wpm, 150);
      expect(attempt.comprehensionRatio, closeTo(0.75, 0.0001));
      expect(attempt.createdAt.year, 2026);
    });
  });
}

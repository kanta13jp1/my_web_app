import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/english_reading_models.dart';
import 'package:my_web_app/services/english_reading_ability.dart';

EnglishReadingAttempt _attempt({
  required int wpm,
  required int level,
  required int day,
  String mode = 'measure',
  int correct = 4,
  int total = 4,
  int? effective,
  int wordCount = 120,
}) {
  final eff = effective ??
      EnglishReadingMetrics.effectiveWpm(
        wpm: wpm,
        comprehensionCorrect: correct,
        comprehensionTotal: total,
      );
  return EnglishReadingAttempt(
    id: 'a$day',
    lessonCode: 'L$level-01',
    level: level,
    mode: mode,
    wordCount: wordCount,
    elapsedMs: 60000,
    wpm: wpm,
    comprehensionCorrect: correct,
    comprehensionTotal: total,
    effectiveWpm: eff,
    createdAt: DateTime(2026, 6, day),
  );
}

void main() {
  group('EnglishReadingMetrics.wpm', () {
    test('computes words per minute', () {
      expect(EnglishReadingMetrics.wpm(wordCount: 250, elapsedMs: 60000), 250);
      expect(EnglishReadingMetrics.wpm(wordCount: 250, elapsedMs: 30000), 500);
    });

    test('guards against zero / negative inputs', () {
      expect(EnglishReadingMetrics.wpm(wordCount: 0, elapsedMs: 60000), 0);
      expect(EnglishReadingMetrics.wpm(wordCount: 100, elapsedMs: 0), 0);
      expect(EnglishReadingMetrics.wpm(wordCount: -5, elapsedMs: 60000), 0);
    });
  });

  group('EnglishReadingMetrics.effectiveWpm', () {
    test('scales wpm by comprehension ratio', () {
      expect(
        EnglishReadingMetrics.effectiveWpm(
          wpm: 200,
          comprehensionCorrect: 3,
          comprehensionTotal: 4,
        ),
        150,
      );
    });

    test('returns raw wpm when there is no quiz (RSVP)', () {
      expect(
        EnglishReadingMetrics.effectiveWpm(
          wpm: 240,
          comprehensionCorrect: 0,
          comprehensionTotal: 0,
        ),
        240,
      );
    });

    test('is zero when wpm is zero', () {
      expect(
        EnglishReadingMetrics.effectiveWpm(
          wpm: 0,
          comprehensionCorrect: 4,
          comprehensionTotal: 4,
        ),
        0,
      );
    });
  });

  group('EnglishReadingMetrics.levelForEffectiveWpm', () {
    test('maps effective wpm to the highest reached level', () {
      expect(EnglishReadingMetrics.levelForEffectiveWpm(80).level, 1);
      expect(EnglishReadingMetrics.levelForEffectiveWpm(100).level, 1);
      expect(EnglishReadingMetrics.levelForEffectiveWpm(150).level, 2);
      expect(EnglishReadingMetrics.levelForEffectiveWpm(225).level, 4);
      expect(EnglishReadingMetrics.levelForEffectiveWpm(260).level, 5);
      expect(EnglishReadingMetrics.levelForEffectiveWpm(330).level, 6);
    });
  });

  group('EnglishReadingMetrics.nativeRatio', () {
    test('is ratio against 300 wpm, clamped to 1.0', () {
      expect(EnglishReadingMetrics.nativeRatio(150), closeTo(0.5, 0.0001));
      expect(EnglishReadingMetrics.nativeRatio(300), 1.0);
      expect(EnglishReadingMetrics.nativeRatio(600), 1.0);
      expect(EnglishReadingMetrics.nativeRatio(0), 0.0);
    });
  });

  group('EnglishReadingAbilitySummary.fromAttempts', () {
    test('empty attempts yield an empty summary', () {
      final summary = EnglishReadingAbilitySummary.fromAttempts(const []);
      expect(summary.hasData, isFalse);
      expect(summary.totalSessions, 0);
      expect(summary.estimatedLevel.level, 1);
      expect(summary.trend, isEmpty);
    });

    test('aggregates latest / best / average from measure attempts', () {
      final attempts = <EnglishReadingAttempt>[
        _attempt(wpm: 120, level: 2, day: 1, correct: 3),
        _attempt(wpm: 200, level: 4, day: 2, correct: 4),
        _attempt(wpm: 160, level: 3, day: 3, correct: 4),
      ];
      final summary = EnglishReadingAbilitySummary.fromAttempts(attempts);

      expect(summary.totalSessions, 3);
      // latest = day 3 (wpm 160, comp 4/4 -> effective 160)
      expect(summary.latestWpm, 160);
      expect(summary.latestEffectiveWpm, 160);
      expect(summary.bestWpm, 200);
      expect(summary.averageWpm, ((120 + 200 + 160) / 3).round());
      expect(summary.trend.length, 3);
      // trend is chronological (oldest first)
      expect(summary.trend.first.wpm, 120);
      expect(summary.trend.last.wpm, 160);
    });

    test(
      'marks a level cleared only at target wpm and >=75% comprehension',
      () {
        final attempts = <EnglishReadingAttempt>[
          // Lv2 target 150: 160 wpm, 4/4 -> cleared
          _attempt(wpm: 160, level: 2, day: 1, correct: 4, total: 4),
          // Lv4 target 220: 200 wpm (too slow) -> not cleared
          _attempt(wpm: 200, level: 4, day: 2, correct: 4, total: 4),
          // Lv3 target 180: 200 wpm but 2/4 comprehension -> not cleared
          _attempt(wpm: 200, level: 3, day: 3, correct: 2, total: 4),
        ];
        final summary = EnglishReadingAbilitySummary.fromAttempts(attempts);
        expect(summary.clearedLevels.contains(2), isTrue);
        expect(summary.clearedLevels.contains(4), isFalse);
        expect(summary.clearedLevels.contains(3), isFalse);
      },
    );

    test('falls back to rsvp attempts when no measure attempts exist', () {
      final attempts = <EnglishReadingAttempt>[
        _attempt(
          wpm: 300,
          level: 6,
          day: 1,
          mode: 'rsvp',
          correct: 0,
          total: 0,
          effective: 300,
        ),
      ];
      final summary = EnglishReadingAbilitySummary.fromAttempts(attempts);
      expect(summary.hasData, isTrue);
      expect(summary.latestEffectiveWpm, 300);
      expect(summary.reachedNative, isTrue);
    });
  });
}

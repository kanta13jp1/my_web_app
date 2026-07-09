import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_dashboard_signals.dart';

void main() {
  group('formatRatePercent (n=0 honesty)', () {
    test('denominator 0 → 「—」 not fabricated 0.0%', () {
      expect(formatRatePercent(0, 0), '—');
      expect(formatRatePercent(5, 0), '—');
    });

    test('real 0 registrations with views is a true 0.0%', () {
      expect(formatRatePercent(0, 5), '0.0%');
    });

    test('normal rate', () {
      expect(formatRatePercent(1, 10), '10.0%');
      expect(formatRatePercent(3, 8), '37.5%');
    });
  });

  group('resolveXGrowthLoop', () {
    test('no measured data and no post today → hidden', () {
      final r = resolveXGrowthLoop(
        measuredCount: 0,
        distinctVariantCount: 0,
        postedTodayCount: 0,
      );
      expect(r.state, XGrowthLoopState.hidden);
    });

    test('posted today but 0 measured → awaitingMetrics (cron warning)', () {
      final r = resolveXGrowthLoop(
        measuredCount: 0,
        distinctVariantCount: 0,
        postedTodayCount: 1,
      );
      expect(r.state, XGrowthLoopState.awaitingMetrics);
    });

    test('measured but <2 variants → sampling', () {
      final r = resolveXGrowthLoop(
        measuredCount: 3,
        distinctVariantCount: 1,
        postedTodayCount: 0,
      );
      expect(r.state, XGrowthLoopState.sampling);
      expect(r.measuredCount, 3);
    });

    test('>=2 distinct variants → unlocked', () {
      final r = resolveXGrowthLoop(
        measuredCount: 6,
        distinctVariantCount: 3,
        postedTodayCount: 1,
      );
      expect(r.state, XGrowthLoopState.unlocked);
    });
  });

  group('distinctMeasuredVariants', () {
    test('excludes unknown and empty', () {
      final variants = [
        {'variant': 'daily_briefing', 'averageScore': 12, 'count': 4},
        {'variant': 'unknown', 'averageScore': 3, 'count': 2},
        {'variant': 'question_post', 'averageScore': 20, 'count': 1},
        {'variant': '', 'averageScore': 0, 'count': 1},
      ];
      expect(distinctMeasuredVariants(variants), 2);
    });

    test('null → 0', () {
      expect(distinctMeasuredVariants(null), 0);
    });
  });

  group('R18 distinctMeasuredVariants folds _fallback into base', () {
    test('base + its fallback count as 1 (no false 勝ち型 unlock)', () {
      final variants = [
        {'variant': 'daily_briefing', 'averageScore': 124, 'count': 8},
        {'variant': 'daily_briefing_fallback', 'averageScore': 94, 'count': 1},
      ];
      expect(distinctMeasuredVariants(variants), 1);
    });

    test('two distinct bases each with a fallback count as 2', () {
      final variants = [
        {'variant': 'daily_briefing', 'count': 4},
        {'variant': 'daily_briefing_fallback', 'count': 1},
        {'variant': 'question_post', 'count': 2},
        {'variant': 'question_post_fallback', 'count': 1},
      ];
      expect(distinctMeasuredVariants(variants), 2);
    });

    test('bare _fallback and unknown excluded', () {
      final variants = [
        {'variant': '_fallback', 'count': 1},
        {'variant': 'unknown', 'count': 3},
      ];
      expect(distinctMeasuredVariants(variants), 0);
    });
  });

  group('R18 weeklyDigestCardState', () {
    test('not loaded → loading', () {
      expect(
        weeklyDigestCardState(loaded: false, hasData: false),
        WeeklyDigestCardState.loading,
      );
    });
    test('loaded but no data → empty (not infinite spinner)', () {
      expect(
        weeklyDigestCardState(loaded: true, hasData: false),
        WeeklyDigestCardState.empty,
      );
    });
    test('loaded with data → data', () {
      expect(
        weeklyDigestCardState(loaded: true, hasData: true),
        WeeklyDigestCardState.data,
      );
    });
  });

  group('R18 streakAtWindowCap', () {
    test('streak below window → false', () {
      expect(streakAtWindowCap(12, 30), isFalse);
    });
    test('streak saturates window → true (show N日以上)', () {
      expect(streakAtWindowCap(30, 30), isTrue);
    });
    test('zero streak → false', () {
      expect(streakAtWindowCap(0, 30), isFalse);
    });
  });
}

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
}

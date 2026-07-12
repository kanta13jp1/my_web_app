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

  group('R19 admin user list (contract bug + fabrication)', () {
    test('adminUserIsAnonymous: empty email = anonymous auth', () {
      expect(adminUserIsAnonymous({'email': ''}), isTrue);
      expect(adminUserIsAnonymous({'email': '  '}), isTrue);
      expect(adminUserIsAnonymous(<String, dynamic>{}), isTrue);
      expect(adminUserIsAnonymous({'email': 'a@b.com'}), isFalse);
    });

    test('adminUserCreatedRaw: snake created_at preferred, camel fallback', () {
      // edge が返す snake が優先される(契約バグの本丸)。
      expect(
        adminUserCreatedRaw({'created_at': '2026-07-01T00:00:00Z'}),
        '2026-07-01T00:00:00Z',
      );
      // 旧 UI の camel も後方互換で拾う。
      expect(
        adminUserCreatedRaw({'createdAt': '2026-07-02T00:00:00Z'}),
        '2026-07-02T00:00:00Z',
      );
      // どちらも無ければ空 → 呼び出し側で「日付なし」へ。
      expect(adminUserCreatedRaw(<String, dynamic>{}), '');
    });

    test('summarizeAdminUsers: real vs anonymous split', () {
      final users = <Map<String, dynamic>>[
        {'email': 'real1@x.com'},
        {'email': 'real2@x.com'},
        {'email': ''},
        <String, dynamic>{},
        {'email': '  '},
      ];
      final s = summarizeAdminUsers(users);
      expect(s.real, 2);
      expect(s.anon, 3);
    });
  });

  group('R20 X成長ループ freshness (perf-context source, not today-status)', () {
    final now = DateTime(2026, 7, 10, 12, 0);

    test('measuredCount 0 → 計測待ち (the only honest waiting state)', () {
      expect(
        resolveXGrowthLoopFreshness(
          measuredCount: 0,
          newestMeasuredAt: null,
          now: now,
        ),
        '最終計測: 計測待ち',
      );
    });

    test('measured but no parseable date → 計測済み N件, never 計測待ち', () {
      final r = resolveXGrowthLoopFreshness(
        measuredCount: 12,
        newestMeasuredAt: null,
        now: now,
      );
      expect(r, '計測済み 12件');
      expect(r.contains('計測待ち'), isFalse);
    });

    test('measured with recent date → 最新サンプル relative', () {
      expect(
        resolveXGrowthLoopFreshness(
          measuredCount: 12,
          newestMeasuredAt: now.subtract(const Duration(days: 3)),
          now: now,
        ),
        '最新サンプル: 3日前',
      );
      expect(
        resolveXGrowthLoopFreshness(
          measuredCount: 12,
          newestMeasuredAt: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        '最新サンプル: 2時間前',
      );
    });

    test('future timestamp → falls through to 計測済み N件', () {
      expect(
        resolveXGrowthLoopFreshness(
          measuredCount: 12,
          newestMeasuredAt: now.add(const Duration(hours: 5)),
          now: now,
        ),
        '計測済み 12件',
      );
    });

    test('newestMeasuredCreatedAt: max across rows (rows are score-sorted)',
        () {
      // rows[0] は高スコアの古い投稿、後続に新しい投稿 → 最新を返すこと。
      final rows = [
        {'createdAt': '2026-07-01T00:00:00Z', 'score': 200},
        {'createdAt': '2026-07-08T00:00:00Z', 'score': 10},
        {'createdAt': '2026-07-05T00:00:00Z', 'score': 50},
      ];
      expect(
        newestMeasuredCreatedAt(rows),
        DateTime.parse('2026-07-08T00:00:00Z'),
      );
      expect(newestMeasuredCreatedAt(null), isNull);
      expect(
        newestMeasuredCreatedAt([
          {'createdAt': 'bad'},
        ]),
        isNull,
      );
    });
  });

  group('R20 formatAgeAwareDate (yearless MM/dd hides old dates)', () {
    final now = DateTime(2026, 7, 10);
    test('recent same-year → MM/dd', () {
      expect(formatAgeAwareDate('2026-07-05T00:00:00Z', now), '07/05');
    });
    test('same-year but > staleDays → yyyy/MM/dd', () {
      expect(formatAgeAwareDate('2026-04-14T00:00:00Z', now), '2026/04/14');
    });
    test('different year → yyyy/MM/dd', () {
      expect(formatAgeAwareDate('2025-12-20T00:00:00Z', now), '2025/12/20');
    });
    test('unparseable → raw', () {
      expect(formatAgeAwareDate('n/a', now), 'n/a');
    });
  });

  group('R24 xGrowthArchetypeLiftLine', () {
    test('buckets by archetype, sorted by avg desc, JP labels', () {
      final rows = [
        {'archetype': 'data_report', 'score': 8000},
        {'archetype': 'news_summary', 'score': 791},
        {'archetype': 'product_promo', 'score': 31},
        {'archetype': 'product_promo', 'score': 29},
      ];
      final line = xGrowthArchetypeLiftLine(rows);
      expect(line, isNotNull);
      expect(line, contains('データレポート 平均8000 (n=1)'));
      expect(line, contains('ニュース要約 平均791 (n=1)'));
      expect(line, contains('製品プロモ 平均30 (n=2)'));
      expect(line!.indexOf('データレポート'), lessThan(line.indexOf('製品プロモ')));
    });

    test('unknown archetype rows bucket as 不明; empty rows → null', () {
      expect(xGrowthArchetypeLiftLine(null), isNull);
      expect(xGrowthArchetypeLiftLine([]), isNull);
      final line = xGrowthArchetypeLiftLine([
        {'archetype': '', 'score': 10},
      ]);
      expect(line, contains('不明 平均10 (n=1)'));
    });
  });
}

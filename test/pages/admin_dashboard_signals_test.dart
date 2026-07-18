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

    test('R27 staleness warning: 3日以上でのみ警告文を返す', () {
      String? warn(int days) => xGrowthLoopStalenessWarning(
            measuredCount: 12,
            newestMeasuredAt: now.subtract(Duration(days: days)),
            now: now,
          );
      expect(warn(0), isNull);
      expect(warn(2), isNull);
      expect(warn(3), contains('3日間増えていません'));
      expect(warn(7), contains('7日間増えていません'));
      // 断定できないので投稿停止/cron 停止の両論併記であること。
      expect(warn(3), contains('cron'));
    });

    test('R27 staleness warning: 計測0件 / 日付不明 / 未来時刻は警告しない', () {
      expect(
        xGrowthLoopStalenessWarning(
          measuredCount: 0,
          newestMeasuredAt: now.subtract(const Duration(days: 10)),
          now: now,
        ),
        isNull,
      );
      expect(
        xGrowthLoopStalenessWarning(
          measuredCount: 12,
          newestMeasuredAt: null,
          now: now,
        ),
        isNull,
      );
      expect(
        xGrowthLoopStalenessWarning(
          measuredCount: 12,
          newestMeasuredAt: now.add(const Duration(days: 1)),
          now: now,
        ),
        isNull,
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

  group('R25 archetype lift exposure (R23 measured axis to the panel)', () {
    // 初版(#3965)は edge の実バケット値 news_briefing を news_summary と
    // 誤記しニュース要約行が全て「分類前」へ落ちる契約バグがあった。本実装は
    // edge x_post_archetype.ts の ArchetypeBucket と同一キーで固定する。
    List<Map<String, dynamic>> rows() => [
          {
            'archetype': 'data_report',
            'i72h': 3200,
          },
          {
            'archetype': 'data_report',
            'i72h': 2800,
          },
          {
            'archetype': 'news_briefing',
            'i72h': 517,
          },
          {
            'archetype': 'news_briefing',
            'i72h': 28,
          },
          {
            'archetype': 'product_promo',
            'i72h': 10,
          },
          {
            'archetype': 'product_promo',
            'i72h': null,
          },
          // 旧ログ(archetype 欠落)は unknown 保持。
          {'i72h': 99},
          // 累積8Kは学習用ベンチマークだが、I72 liftには混ぜない。
          {
            'archetype': 'data_report',
            'impressions': 8000,
            'i72h': null,
            'learningCohort': 'historical_benchmark',
          },
        ];

    test('groups by archetype, measured first, unknown always last', () {
      final entries = resolveArchetypeLift(rows());
      expect(entries.map((e) => e.archetype).toList(), [
        'data_report',
        'news_briefing',
        'product_promo',
        'unknown',
      ]);
      expect(entries[0].averageImpressions, 3000);
      expect(entries[0].measured, isTrue);
      expect(entries[1].averageImpressions, 273);
      // n=1 は実測扱いしない。
      expect(entries[2].measured, isFalse);
      expect(entries[2].pendingCount, 1);
    });

    test('edge contract: news_briefing rows carry the JP label (not 分類前)', () {
      final line = archetypeLiftSummaryLine(
        resolveArchetypeLift(rows()),
      );
      expect(line, contains('ニュース要約型 平均273 imp (2件)'));
      expect(line, isNot(contains('news_briefing')));
    });

    test('winner needs >=2 mature buckets and a strict lead', () {
      expect(
        archetypeLiftWinner(resolveArchetypeLift(rows()))?.archetype,
        'data_report',
      );
      // 実測バケット1種では勝ち型を主張しない。
      final single = resolveArchetypeLift([
        {
          'archetype': 'news_briefing',
          'i72h': 517,
        },
        {
          'archetype': 'news_briefing',
          'i72h': 28,
        },
        {
          'archetype': 'product_promo',
          'i72h': 10,
        },
      ]);
      expect(archetypeLiftWinner(single), isNull);
      // unknown だけが n>=2 でも勝ち型にしない。
      final unknownOnly = resolveArchetypeLift([
        {'i72h': 1},
        {'i72h': 2},
        {'archetype': 'general', 'i72h': 3},
        {'archetype': 'general', 'i72h': 4},
      ]);
      expect(archetypeLiftWinner(unknownOnly), isNull);

      final tied = resolveArchetypeLift([
        {'archetype': 'data_report', 'i72h': 100},
        {'archetype': 'data_report', 'i72h': 100},
        {'archetype': 'general', 'i72h': 100},
        {'archetype': 'general', 'i72h': 100},
      ]);
      expect(archetypeLiftWinner(tied), isNull);
    });

    test('summary line labels measured vs 実測不足, null when empty', () {
      final line = archetypeLiftSummaryLine(
        resolveArchetypeLift(rows()),
      );
      expect(line, contains('投稿72時間後・imp'));
      expect(line, contains('データレポート型 平均3000 imp (2件)'));
      expect(line, contains('製品紹介型 実測不足 (1件・計測中1件)'));
      expect(line, contains('分類前(旧ログ)'));
      expect(
        archetypeLiftSummaryLine(resolveArchetypeLift(null)),
        isNull,
      );
      expect(
        archetypeLiftSummaryLine(resolveArchetypeLift(const [])),
        isNull,
      );
    });
  });

  group('R28 foldVariantsForDisplay + 勝ち型/ランキングの畳み込み', () {
    // 本番観測: fallback(平均89 n=1) が本命(平均76 n=7)を抑えて勝ち型昇格。
    final observed = [
      {'variant': 'unknown', 'averageScore': 122, 'count': 16},
      {'variant': 'daily_briefing_fallback', 'averageScore': 89, 'count': 1},
      {'variant': 'daily_briefing', 'averageScore': 76, 'count': 7},
      {'variant': 'daily_briefing_v2_numbers', 'averageScore': 27, 'count': 1},
    ];

    test('foldVariants: _fallback を base へ畳み unknown を除外', () {
      final folded = foldVariantsForDisplay(observed);
      expect(folded.map((e) => e.variant), [
        'daily_briefing',
        'daily_briefing_v2_numbers',
      ]);
      // (89*1 + 76*7)/8 = 77.6 → 78, n=8
      expect(folded.first.averageScore, 78);
      expect(folded.first.count, 8);
    });

    test('勝ち型は畳み込み後 n>=2 の最上位 (fallback 単独 n=1 は昇格させない)', () {
      // 旧バグは daily_briefing_fallback を返していた。
      expect(resolveDisplayBestVariant('unknown', observed), 'daily_briefing');
    });

    test('全 variant が n=1 → 勝ち型 null (断定しない)', () {
      final allSingle = [
        {'variant': 'daily_briefing', 'averageScore': 90, 'count': 1},
        {'variant': 'question_post', 'averageScore': 10, 'count': 1},
      ];
      expect(resolveDisplayBestVariant('daily_briefing', allSingle), isNull);
    });

    test('サーバ bestVariant が名前でも実測が薄ければ信用しない', () {
      // bestVariant='daily_briefing' でも variants 空 → 実測無し → null。
      expect(resolveDisplayBestVariant('daily_briefing', const []), isNull);
      expect(resolveDisplayBestVariant('daily_briefing', null), isNull);
    });

    test('不正要素は無視', () {
      expect(
        resolveDisplayBestVariant('unknown', [
          {'variant': 'unknown', 'count': 9},
          {'variant': ''},
          'not-a-map',
        ]),
        isNull,
      );
    });
  });

  group('R28 archetypeLiftSummaryLine: 実測0件バケットは計測中のみ表示', () {
    test('count=0 & pending>0 → 「実測不足 (0件…)」でなく「計測中N件」', () {
      final line = archetypeLiftSummaryLine(
        resolveArchetypeLift([
          {'archetype': 'product_promo', 'i72h': 119},
          {'archetype': 'product_promo', 'i72h': 118},
          {'archetype': 'data_report', 'i72h': null},
        ]),
      );
      expect(line, contains('データレポート型 計測中1件'));
      expect(line, isNot(contains('データレポート型 実測不足')));
      expect(line, isNot(contains('0件')));
    });

    test('count>=1 だが n<2 は従来どおり「実測不足 (N件…)」', () {
      final line = archetypeLiftSummaryLine(
        resolveArchetypeLift([
          {'archetype': 'news_briefing', 'i72h': 100},
          {'archetype': 'news_briefing', 'i72h': 90},
          {'archetype': 'product_promo', 'i72h': 10},
          {'archetype': 'product_promo', 'i72h': null},
        ]),
      );
      expect(line, contains('製品紹介型 実測不足 (1件・計測中1件)'));
    });
  });
}

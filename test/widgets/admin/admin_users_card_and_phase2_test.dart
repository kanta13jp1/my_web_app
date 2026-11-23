import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin/admin_daily_stats_aggregate.dart';
import 'package:my_web_app/widgets/admin/admin_users_card.dart';

void main() {
  group('AdminUsersCard', () {
    testWidgets(
      'filters locally without rebuilding parent and supports profile edit dialog',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var parentBuildCount = 0;
        var refreshCount = 0;
        final savedUpdates =
            <({String userId, Map<String, dynamic> updates})>[];

        final users = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u1',
            'email': 'alice@example.com',
            'displayName': 'Alice Tanaka',
            'bio': 'Engineer',
            'location': 'Tokyo',
            'created_at': '2026-11-01T10:00:00Z',
            'hasProfile': true,
            'completionPct': 80,
          },
          <String, dynamic>{
            'id': 'u2',
            'email': '',
            'displayName': '',
            'created_at': '2026-11-20T10:00:00Z',
            'hasProfile': false,
            'completionPct': 0,
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) {
                    parentBuildCount += 1;
                    return AdminUsersCard(
                      users: users,
                      totalUsers: 2,
                      loading: false,
                      onRefresh: () => refreshCount += 1,
                      onUpdateUserProfile: (userId, updates) async {
                        savedUpdates.add((userId: userId, updates: updates));
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(parentBuildCount, 1);
        expect(find.text('登録ユーザー管理 (合計 2 人 / 実 1・匿名 1)'), findsOneWidget);
        expect(find.text('実ユーザー 1人'), findsOneWidget);
        expect(find.text('匿名テスト 1人'), findsOneWidget);
        expect(find.text('Alice Tanaka'), findsOneWidget);
        expect(find.text('匿名ユーザー'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('admin_users_search_field')),
          'alice',
        );
        await tester.pump();

        expect(parentBuildCount, 1);
        expect(find.text('Alice Tanaka'), findsOneWidget);
        expect(find.text('匿名ユーザー'), findsNothing);

        await tester.tap(find.byKey(const Key('admin_users_search_clear')));
        await tester.pump();

        expect(parentBuildCount, 1);
        expect(find.text('匿名ユーザー'), findsOneWidget);

        await tester.tap(find.text('プロフィール詳細').first);
        await tester.pumpAndSettle();

        expect(find.text('編集'), findsOneWidget);
        await tester.tap(find.text('編集'));
        await tester.pump();

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(savedUpdates.length, 1);
        expect(savedUpdates.single.userId, 'u1');
        expect(savedUpdates.single.updates['display_name'], 'Alice Tanaka');
        expect(refreshCount, 1);

        await tester.tap(find.text('閉じる'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('computeAdminDailyStatsAggregate', () {
    test('returns empty defaults when dailyStats is empty', () {
      final agg = computeAdminDailyStatsAggregate(
        dailyStats: const <Map<String, dynamic>>[],
        lpTodayViews: 0,
        lpTotalViews: 0,
        hasLpViewStats: false,
        now: DateTime(2026, 11, 23, 10, 0),
      );

      expect(agg.effectiveTodayViews, 0);
      expect(agg.effectiveTotalLpViews, 0);
      expect(agg.todaySummaryCvr, 0);
      expect(agg.zeroRegistrationStreakDays, 0);
      expect(agg.zeroStreakAtCap, isFalse);
      expect(agg.averageViewsLast7Days, 0);
      expect(agg.chartData, isEmpty);
    });

    test('aggregates funnels, shares, sources, LP overrides, and streak cap',
        () {
      final agg = computeAdminDailyStatsAggregate(
        dailyStats: <Map<String, dynamic>>[
          <String, dynamic>{
            'date': '2026-11-23',
            'landing_views': 20,
            'conversions': 0,
            'share_count': 2,
            'source_details': <String, int>{
              'funnel_trial_run': 5,
              'funnel_save_cta': 3,
              'funnel_billing_view': 2,
              'share_x': 2,
              'x_profile': 4,
            },
          },
          <String, dynamic>{
            'date': '2026-11-22',
            'landing_views': 40,
            'conversions': 0,
            'share_count': 1,
            'source_details': <String, int>{
              'funnel_trial_run': 4,
              'funnel_upgrade_click': 1,
              'share_copy': 1,
              'direct': 10,
            },
          },
        ],
        lpTodayViews: 50,
        lpTotalViews: 100,
        hasLpViewStats: true,
        now: DateTime(2026, 11, 23, 10, 0),
      );

      expect(agg.effectiveTodayViews, 50);
      expect(agg.effectiveTotalLpViews, 100);
      expect(agg.maxDailyViews, 40);
      expect(agg.totalShares, 3);
      expect(agg.todayRegistrations, 0);
      expect(agg.todaySummaryCvr, 0);
      expect(agg.todayFunnel.trialRuns, 5);
      expect(agg.todayFunnel.saveClicks, 3);
      expect(agg.totalFunnel.trialRuns, 9);
      expect(agg.totalBillingFunnel.billingViews, 2);
      expect(agg.totalBillingFunnel.upgradeClicks, 1);
      expect(agg.sourceBreakdown, <String, int>{'x_profile': 4, 'direct': 10});
      expect(
        agg.shareChannelBreakdown,
        <String, int>{'share_x': 2, 'share_copy': 1},
      );
      expect(agg.todayDropBeforeTrial, 45);
      expect(agg.totalDropBeforeTrial, 91);
      expect(agg.zeroRegistrationStreakDays, 2);
      expect(agg.zeroStreakAtCap, isTrue);
      expect(agg.averageViewsLast7Days, 30);
      expect(agg.chartData.first['date'], '2026-11-22');
      expect(agg.chartData.last['date'], '2026-11-23');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin/admin_blog_posts_card.dart';
import 'package:my_web_app/widgets/admin/admin_comparison_cvr_card.dart';
import 'package:my_web_app/widgets/admin/admin_growth_achievement_summary_card.dart';

void main() {
  group('AdminBlogPostsCard', () {
    testWidgets('renders loading, empty, posts, URL tap, and status callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var refreshCount = 0;
      final statusChanges = <(String, String)>[];
      final openedUris = <Uri>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminBlogPostsCard(
                posts: const <Map<String, dynamic>>[],
                loading: true,
                onRefresh: () => refreshCount++,
                onUpdateStatus: (id, status) => statusChanges.add((id, status)),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminBlogPostsCard(
                posts: const <Map<String, dynamic>>[],
                loading: false,
                onRefresh: () => refreshCount++,
                onUpdateStatus: (id, status) => statusChanges.add((id, status)),
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('まだブログ下書きがありません。'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminBlogPostsCard(
                posts: const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'post-1',
                    'status': 'draft',
                    'title': '技術記事下書きタイトル',
                    'target_platforms': <String>['zenn', 'qiita'],
                    'url': 'https://zenn.dev/example/articles/test',
                    'created_at': '2026-11-22T09:00:00Z',
                  },
                ],
                loading: false,
                onRefresh: () => refreshCount++,
                onUpdateStatus: (id, status) => statusChanges.add((id, status)),
                onOpenUrl: (uri) async => openedUris.add(uri),
              ),
            ),
          ),
        ),
      );
      expect(find.text('技術記事下書きタイトル'), findsOneWidget);
      expect(find.text('下書き'), findsOneWidget);

      await tester.tap(find.text('https://zenn.dev/example/articles/test'));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(openedUris.single.toString(),
          'https://zenn.dev/example/articles/test');
      expect(refreshCount, 1);

      await tester.tap(find.text('下書き'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('投稿済にする'));
      await tester.pumpAndSettle();
      expect(statusChanges, <(String, String)>[('post-1', 'posted')]);
    });
  });

  group('AdminComparisonCvrCard', () {
    testWidgets('shows honest dash when touches=0 and renders sorted bars', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminComparisonCvrCard(
                comparisonTouches: const <String, int>{},
                comparisonSignups: 0,
                loading: false,
                onRefresh: () => refreshCount++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('比較ページへの到達データがまだありません'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminComparisonCvrCard(
                comparisonTouches: const <String, int>{
                  'notion': 80,
                  'evernote': 20,
                },
                comparisonSignups: 5,
                loading: false,
                onRefresh: () => refreshCount++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('100'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('5.0%'), findsOneWidget);
      expect(find.text('notion'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(refreshCount, 1);
    });
  });

  group('AdminGrowthAchievementSummaryCard', () {
    testWidgets('distinguishes empty/unconnected metrics and period taps', (
      tester,
    ) async {
      var refreshCount = 0;
      final selectedPeriods = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminGrowthAchievementSummaryCard(
                summary: const <String, dynamic>{
                  'success': true,
                  'items': <dynamic>[],
                },
                loading: false,
                onRefresh: () => refreshCount++,
                onSelectPeriod: (_, label) => selectedPeriods.add(label),
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('成長サマリーの集計はまだ接続されていません。'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminGrowthAchievementSummaryCard(
                summary: const <String, dynamic>{
                  'label': '今週',
                  'newUsers': 4,
                  'totalUsersEver': 120,
                  'acquisitionSignals': 15,
                  'referralsCompleted': 2,
                  'importPreviews': 6,
                },
                loading: false,
                onRefresh: () => refreshCount++,
                onSelectPeriod: (_, label) => selectedPeriods.add(label),
              ),
            ),
          ),
        ),
      );
      expect(find.text('期間: 今週'), findsOneWidget);
      expect(find.text('4人'), findsOneWidget);
      expect(find.text('120人'), findsOneWidget);
      expect(find.text('15件'), findsOneWidget);

      await tester.tap(find.text('今週'));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(selectedPeriods, <String>['今週']);
      expect(refreshCount, 1);
    });
  });
}

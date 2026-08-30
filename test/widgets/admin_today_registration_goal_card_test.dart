import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin_today_registration_goal_card.dart';

void main() {
  Widget testApp({
    int todayViews = 0,
    int todayRegistrations = 0,
    String? actionButtonLabel,
    VoidCallback? onActionPressed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AdminTodayRegistrationGoalCard(
          todayViews: todayViews,
          todayRegistrations: todayRegistrations,
          trialRuns: 2,
          magicLinkSends: 1,
          cvrText: todayViews == 0 ? '—' : '50.0%',
          diagnosisLabel: todayViews == 0 ? '流入不足' : '体験未実行',
          diagnosisColor: const Color(0xFFFF6B35),
          priorityChannelLabel: todayViews == 0 ? 'Google検索' : null,
          statusText: todayRegistrations >= 1
              ? '今日の登録目標は達成済みです。次は流入改善で上振れを狙う。'
              : '診断テキスト',
          actionTitle: actionButtonLabel == null ? null : '次の一手',
          actionDetail: actionButtonLabel == null ? null : '実行詳細',
          actionIcon: actionButtonLabel == null ? null : Icons.arrow_forward,
          actionButtonLabel: actionButtonLabel,
          onActionPressed: onActionPressed,
        ),
      ),
    );
  }

  testWidgets('renders the zero-traffic diagnosis without fabricated CVR', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(find.text('今日の登録目標'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('未達'), findsOneWidget);
    expect(find.text('今日のCVR —', findRichText: true), findsOneWidget);
    expect(find.text('今日の診断 流入不足', findRichText: true), findsOneWidget);
    expect(
      find.text('最優先チャネル Google検索', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('診断テキスト あと1人の登録が必要です。'), findsOneWidget);
    expect(find.text('今日体験 2', findRichText: true), findsNothing);
  });

  testWidgets('renders and invokes the supplied action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      testApp(
        todayViews: 4,
        actionButtonLabel: 'X投稿を作る',
        onActionPressed: () => tapped = true,
      ),
    );

    expect(find.text('今日体験 2', findRichText: true), findsOneWidget);
    expect(find.text('今日送信 1', findRichText: true), findsOneWidget);
    expect(
      find.text('最優先チャネル Google検索', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('X投稿を作る'));
    expect(tapped, isTrue);
  });

  testWidgets('shows the achieved state without an action card', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(todayViews: 3, todayRegistrations: 1));

    expect(find.text('達成'), findsOneWidget);
    expect(find.text('今日の登録目標は達成済みです。次は流入改善で上振れを狙う。'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}

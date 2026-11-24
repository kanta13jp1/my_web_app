import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_mission_service.dart';
import 'package:my_web_app/widgets/admin/admin_user_feedback_card.dart';
import 'package:my_web_app/widgets/admin/admin_waitlist_card.dart';
import 'package:my_web_app/widgets/admin/admin_weekly_digest_card.dart';

void main() {
  group('AdminWeeklyDigestCard', () {
    testWidgets('renders loading, empty, and loaded states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminWeeklyDigestCard(
                digest: WeeklyDigestSnapshot.empty(),
                loaded: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('読み込み中...'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminWeeklyDigestCard(
                digest: WeeklyDigestSnapshot.empty(),
                loaded: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('今週はまだ計測データがありません（計測待ち）'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminWeeklyDigestCard(
                digest: WeeklyDigestSnapshot(
                  currentWeekStart: '2026-11-16',
                  currentWeekEnd: '2026-11-22',
                  channels: <WeeklyDigestChannelMetrics>[
                    WeeklyDigestChannelMetrics(
                      id: 'zenn',
                      label: 'Zenn',
                      touches: 42,
                      signupSubmits: 5,
                      cvr: 12,
                      touchesDelta: 3,
                      signupSubmitsDelta: 2,
                    ),
                  ],
                  signupSubmitTotal: 12,
                  signupSubmitDelta: 4,
                  referralsCompleted: 3,
                  referralsDelta: -1,
                  importCtaClicks: 7,
                  publicMemoCtaClicks: 9,
                  decision: WeeklyDigestDecision.empty(),
                  previousDecisionOutcome: WeeklyDigestDecisionOutcome.empty(),
                  brief: 'Zenn導線の登録が前週比で増加しました。',
                ),
                loaded: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('2026-11-16 〜 2026-11-22'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('Zenn'), findsOneWidget);
      expect(find.text('タッチ 42'), findsOneWidget);
      expect(find.text('登録 5'), findsOneWidget);
      expect(find.text('Zenn導線の登録が前週比で増加しました。'), findsOneWidget);
    });
  });

  group('AdminWaitlistCard', () {
    testWidgets('handles loading, empty, and callback states', (tester) async {
      var sendCount = 0;
      var refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminWaitlistCard(
                waitlistEmails: const <Map<String, dynamic>>[],
                loading: true,
                sendingNotification: false,
                onSendNotification: () => sendCount++,
                onRefresh: () => refreshCount++,
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
              child: AdminWaitlistCard(
                waitlistEmails: const <Map<String, dynamic>>[],
                loading: false,
                sendingNotification: false,
                onSendNotification: () => sendCount++,
                onRefresh: () => refreshCount++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('メールウェイトリスト (0件)'), findsOneWidget);
      expect(find.text('登録者はまだいません'), findsOneWidget);
      await tester.tap(find.text('通知送信'));
      await tester.pump();
      expect(sendCount, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminWaitlistCard(
                waitlistEmails: const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'email': 'test@example.com',
                    'source': 'lp',
                    'created_at': '2026-11-22T12:30:00Z',
                  },
                ],
                loading: false,
                sendingNotification: false,
                onSendNotification: () => sendCount++,
                onRefresh: () => refreshCount++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('メールウェイトリスト (1件)'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      await tester.tap(find.text('通知送信'));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(sendCount, 1);
      expect(refreshCount, 1);
    });
  });

  group('AdminUserFeedbackCard', () {
    testWidgets('renders counts and invokes status/manage callbacks', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var refreshCount = 0;
      var manageAllCount = 0;
      final statusUpdates = <(int, String)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminUserFeedbackCard(
                feedbacks: const <Map<String, dynamic>>[],
                loading: false,
                onRefresh: () => refreshCount++,
                onUpdateStatus: (id, status) => statusUpdates.add((id, status)),
                onOpenManageAll: () => manageAllCount++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('フィードバックはまだありません'), findsOneWidget);
      expect(find.text('全0件を管理する'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminUserFeedbackCard(
                feedbacks: const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 101,
                    'status': 'new',
                    'category': 'feature',
                    'content': '月次表示にフィルタを追加してほしい',
                  },
                  <String, dynamic>{
                    'id': 102,
                    'status': 'reviewed',
                    'category': 'bug',
                    'content': '一部ラベルの余白を調整したい',
                  },
                  <String, dynamic>{
                    'id': 103,
                    'status': 'implemented',
                    'category': 'other',
                    'content': 'CSV出力を追加した',
                  },
                ],
                loading: false,
                onRefresh: () => refreshCount++,
                onUpdateStatus: (id, status) => statusUpdates.add((id, status)),
                onOpenManageAll: () => manageAllCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('未対応 1'), findsWidgets);
      expect(find.text('確認済 1'), findsOneWidget);
      expect(find.text('対応完 1'), findsOneWidget);
      expect(find.text('全3件を管理する'), findsOneWidget);

      await tester.tap(find.text('確認済にする'));
      await tester.tap(find.text('対応完了'));
      await tester.tap(find.text('全3件を管理する'));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(statusUpdates, <(int, String)>[
        (101, 'reviewed'),
        (101, 'implemented'),
      ]);
      expect(manageAllCount, 1);
      expect(refreshCount, 1);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin/admin_automation_ops_card.dart';
import 'package:my_web_app/widgets/admin/admin_feature_requests_card.dart';

void main() {
  group('AdminFeatureRequestsCard', () {
    testWidgets(
      'renders loading, empty, populated requests, AI reply badge, and action callbacks',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var refreshCount = 0;
        final repliedIds = <String>[];
        final editedFieldIds = <String>[];
        final statusUpdates = <(String, String, String, String?)>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminFeatureRequestsCard(
                  requests: const <Map<String, dynamic>>[],
                  loading: true,
                  onRefresh: () => refreshCount++,
                  onReply: (req) => repliedIds.add(req['id']?.toString() ?? ''),
                  onEditFields: (req) =>
                      editedFieldIds.add(req['id']?.toString() ?? ''),
                  onUpdateStatus: (id, status, title, email) =>
                      statusUpdates.add((id, status, title, email)),
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
                child: AdminFeatureRequestsCard(
                  requests: const <Map<String, dynamic>>[],
                  loading: false,
                  onRefresh: () => refreshCount++,
                  onReply: (req) => repliedIds.add(req['id']?.toString() ?? ''),
                  onEditFields: (req) =>
                      editedFieldIds.add(req['id']?.toString() ?? ''),
                  onUpdateStatus: (id, status, title, email) =>
                      statusUpdates.add((id, status, title, email)),
                ),
              ),
            ),
          ),
        );
        expect(find.text('0件'), findsOneWidget);
        expect(find.text('リクエストはまだありません'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminFeatureRequestsCard(
                  requests: <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'req-1',
                      'title': 'キーボードショートカット改善',
                      'email': 'user@example.com',
                      'votes': 7,
                      'status': 'open',
                      'created_at': DateTime.now().toIso8601String(),
                      'admin_reply': '対応を検討します',
                      'admin_replied_at': '2026-11-22T09:15:00Z',
                    },
                  ],
                  loading: false,
                  onRefresh: () => refreshCount++,
                  onReply: (req) => repliedIds.add(req['id']?.toString() ?? ''),
                  onEditFields: (req) =>
                      editedFieldIds.add(req['id']?.toString() ?? ''),
                  onUpdateStatus: (id, status, title, email) =>
                      statusUpdates.add((id, status, title, email)),
                ),
              ),
            ),
          ),
        );

        expect(find.text('1件'), findsOneWidget);
        expect(find.text('キーボードショートカット改善'), findsOneWidget);
        expect(find.textContaining('AI返信済'), findsOneWidget);
        expect(find.text('AI: 対応を検討します'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        await tester.tap(find.byIcon(Icons.edit_note_outlined));
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pump();

        expect(refreshCount, 1);
        expect(repliedIds, <String>['req-1']);
        expect(editedFieldIds, <String>['req-1']);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('done').last);
        await tester.pumpAndSettle();

        expect(statusUpdates, <(String, String, String, String?)>[
          ('req-1', 'done', 'キーボードショートカット改善', 'user@example.com'),
        ]);
      },
    );
  });

  group('AdminAutomationOpsCard', () {
    testWidgets(
      'renders error, metrics, capped CS queue, posting state, and callbacks',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var refreshCount = 0;
        var postXCount = 0;
        final repliedTicketIds = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminAutomationOpsCard(
                  digest: null,
                  supportTickets: const <Map<String, dynamic>>[],
                  loading: false,
                  postingX: false,
                  error: '接続タイムアウト',
                  onRefresh: () => refreshCount++,
                  onPostX: () => postXCount++,
                  onReplyTicket: (t) =>
                      repliedTicketIds.add(t['id']?.toString() ?? ''),
                ),
              ),
            ),
          ),
        );
        expect(find.text('接続タイムアウト'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminAutomationOpsCard(
                  digest: const <String, dynamic>{
                    'users': <String, dynamic>{'total': 42},
                    'featureRequests': <String, dynamic>{
                      'newToday': 3,
                      'openCount': 9,
                    },
                    'recentAchievements': <String>['a', 'b'],
                  },
                  supportTickets: const <Map<String, dynamic>>[],
                  loading: false,
                  postingX: true,
                  error: null,
                  onRefresh: () => refreshCount++,
                  onPostX: () => postXCount++,
                  onReplyTicket: (t) =>
                      repliedTicketIds.add(t['id']?.toString() ?? ''),
                ),
              ),
            ),
          ),
        );
        expect(find.text('42人'), findsOneWidget);
        expect(find.text('3件'), findsOneWidget);
        expect(find.text('9件'), findsOneWidget);
        expect(find.text('2件'), findsOneWidget);
        expect(find.text('CSキュー (0件)'), findsOneWidget);
        expect(find.text('未返信チケットはありません'), findsOneWidget);
        expect(find.text('投稿中...'), findsOneWidget);

        await tester.tap(find.text('投稿中...'));
        await tester.pump();
        expect(postXCount, 0);

        final sixTickets = List<Map<String, dynamic>>.generate(
          6,
          (i) => <String, dynamic>{
            'id': 'ticket-${i + 1}',
            'title': 'チケット${i + 1}',
            'votes': i + 1,
            'email': i == 0 ? '' : 'user${i + 1}@example.com',
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminAutomationOpsCard(
                  digest: const <String, dynamic>{
                    'users': <String, dynamic>{'total': 42},
                    'featureRequests': <String, dynamic>{
                      'newToday': 3,
                      'openCount': 9,
                    },
                    'recentAchievements': <String>['a', 'b'],
                  },
                  supportTickets: sixTickets,
                  loading: false,
                  postingX: false,
                  error: null,
                  onRefresh: () => refreshCount++,
                  onPostX: () => postXCount++,
                  onReplyTicket: (t) =>
                      repliedTicketIds.add(t['id']?.toString() ?? ''),
                ),
              ),
            ),
          ),
        );
        expect(find.text('CSキュー (6件)'), findsOneWidget);
        expect(find.text('チケット1'), findsOneWidget);
        expect(find.text('メール未登録'), findsOneWidget);
        expect(find.text('チケット5'), findsOneWidget);
        expect(find.text('チケット6'), findsNothing);

        await tester.tap(find.text('X投稿テスト'));
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.tap(find.text('返信').first);
        await tester.pump();

        expect(postXCount, 1);
        expect(refreshCount, 1);
        expect(repliedTicketIds, <String>['ticket-1']);
      },
    );
  });
}

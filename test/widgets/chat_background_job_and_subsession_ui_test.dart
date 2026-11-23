import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/chat_subsession.dart';
import 'package:my_web_app/pages/ai_assistant_chat_page.dart';
import 'package:my_web_app/services/chat_background_job_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(
      'AiAssistantChatPage Background Notifications & Subsessions (#2800 / #2801)',
      () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    testWidgets(
        'shows real-time background job status changes, detail dialog, and parent/child subsession switching',
        (tester) async {
      final handle = tester.ensureSemantics();
      final jobCenter = ChatBackgroundJobCenter();
      addTearDown(jobCenter.dispose);

      try {
        tester.view.physicalSize = const Size(1280, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final rootSeed = ChatSubsession(
          id: 'root',
          title: 'メインセッション',
          inheritedContextIds: const <String>['note_1'],
          inheritedContextTitles: const <String>['議事録コンテキスト'],
          messages: const <ChatSubsessionMessage>[
            ChatSubsessionMessage(
              role: 'assistant',
              content: 'メインセッションの親コンテキストメッセージ',
            ),
          ],
          createdAt: DateTime.utc(2026, 11, 23, 14, 0),
          updatedAt: DateTime.utc(2026, 11, 23, 14, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AiAssistantChatPage(
              debugJobCenter: jobCenter,
              debugInitialSubsessions: <ChatSubsession>[rootSeed],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('メインセッションの親コンテキストメッセージ'), findsOneWidget);

        // Start background job -> notification banner appears immediately
        jobCenter.startJob(
          id: 'job_sync_1',
          title: 'Edge調査タスク',
          summary: 'バックグラウンド集計を実行中',
        );
        // Indeterminate progress indicator animates continuously while running.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('bg_job_item_job_sync_1')), findsOneWidget);
        expect(find.textContaining('実行中'), findsOneWidget);

        // Live transition to completed -> detail dialog accessible
        jobCenter.completeJob(
          'job_sync_1',
          summary: '集計が完了しました',
          resultDetail: '対象5件の集計結果が確定しました。',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('完了'), findsWidgets);

        final detailBtn =
            find.byKey(const Key('bg_job_detail_button_job_sync_1'));
        await tester.ensureVisible(detailBtn);
        await tester.tap(detailBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('bg_job_detail_dialog_job_sync_1')),
          findsOneWidget,
        );
        expect(find.text('対象5件の集計結果が確定しました。'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('閉じる'),
          ),
        );
        await tester.pumpAndSettle();

        // Failed job displays failure state and can be dismissed
        jobCenter.startJob(
          id: 'job_fail_1',
          title: '外部連携同期',
          summary: '同期を開始しました',
        );
        jobCenter.failJob(
          'job_fail_1',
          summary: '同期に失敗しました',
          errorMessage: '503 Service Unavailable',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('失敗'), findsWidgets);

        final dismissBtn =
            find.byKey(const Key('bg_job_dismiss_button_job_fail_1'));
        await tester.ensureVisible(dismissBtn);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('bg_job_item_job_fail_1')),
          findsNothing,
        );

        // Create child subsession -> inherits parent messages and allows bidirectional switching
        final createBtn =
            find.byKey(const Key('ai_chat_create_subsession_button'));
        await tester.ensureVisible(createBtn);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('サブセッション #1'), findsOneWidget);
        expect(find.text('メインセッションの親コンテキストメッセージ'), findsOneWidget);

        final rootTab = find.byKey(const Key('ai_chat_subsession_tab_root'));
        await tester.ensureVisible(rootTab);
        await tester.tap(rootTab);
        await tester.pumpAndSettle();
        expect(find.text('メインセッションの親コンテキストメッセージ'), findsOneWidget);

        final childTab = find.textContaining('サブセッション #1');
        await tester.ensureVisible(childTab);
        await tester.tap(childTab);
        await tester.pumpAndSettle();
        expect(find.text('メインセッションの親コンテキストメッセージ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}

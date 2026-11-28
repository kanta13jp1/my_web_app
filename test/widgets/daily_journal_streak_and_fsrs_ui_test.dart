import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_university_streaks_page.dart';
import 'package:my_web_app/services/fsrs_scheduler.dart';
import 'package:my_web_app/widgets/fsrs_practice_queue_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DailyJournalStreak UI & FsrsPracticeQueueCard UI (#2778 / #1386)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    testWidgets(
        'AiUniversityStreaksPage records task completion, increments streak, and shows journal history',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1280, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: AiUniversityStreaksPage(skipRemoteFetch: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('journal_current_streak_box')),
          findsOneWidget,
        );

        final titleField = find.byKey(const Key('journal_task_title_input'));
        await tester.ensureVisible(titleField);
        await tester.enterText(titleField, 'FSRS暗記テストを1セット完了');

        final recordBtn = find.byKey(const Key('journal_record_task_button'));
        await tester.ensureVisible(recordBtn);
        await tester.tap(recordBtn);
        await tester.pumpAndSettle();

        expect(find.text('1日'), findsWidgets);
        expect(find.byKey(const Key('journal_entry_0')), findsOneWidget);
        expect(find.text('FSRS暗記テストを1セット完了'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        'FsrsPracticeQueueCard prioritizes overdue items first and reschedules after grading',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1280, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.utc(2026, 11, 24, 12, 0);
        final cards = <FsrsCardState>[
          FsrsCardState(
            questionId: 'q_future',
            provider: 'gemini',
            dueDate: now.add(const Duration(hours: 12)),
          ),
          FsrsCardState(
            questionId: 'q_due',
            provider: 'gemini',
            dueDate: now.subtract(const Duration(hours: 6)),
            stability: 2.0,
          ),
        ];

        FsrsReviewOutcome? capturedOutcome;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FsrsPracticeQueueCard(
                  initialCards: cards,
                  promptLabels: const <String, String>{
                    'q_future': '未来の復習カード',
                    'q_due': '期限切れの重要カード',
                  },
                  debugNow: now,
                  onGraded: (outcome) => capturedOutcome = outcome,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('期限超過 1件'), findsOneWidget);
        expect(find.text('優先対象: 期限切れの重要カード'), findsOneWidget);

        final goodBtn = find.byKey(const Key('fsrs_grade_btn_3'));
        await tester.ensureVisible(goodBtn);
        await tester.tap(goodBtn);
        await tester.pumpAndSettle();

        expect(capturedOutcome?.nextDue.isAfter(now), isTrue);
        expect(find.text('期限超過 0件'), findsOneWidget);
        expect(find.text('優先対象: 未来の復習カード'), findsOneWidget);
        expect(
          find.byKey(const Key('fsrs_last_outcome_banner')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}

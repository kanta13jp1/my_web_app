import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_latest_info_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('requires the task, all checks, and self-rating before submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityLatestInfoTaskCard(
              onSubmit: ({required correctAnswers, required selfRating}) async {
                return true;
              },
            ),
          ),
        ),
      ),
    );

    final submit = find.byKey(const Key('latest-info-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    for (var question = 0; question < 3; question += 1) {
      await tapVisible(tester, find.byKey(Key('latest-info-q$question-o0')));
    }
    await tapVisible(
      tester,
      find.byKey(const Key('latest-info-summary-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('latest-info-rating-4')));

    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('submits only aggregate correctness and self-rating', (
    tester,
  ) async {
    int? submittedCorrectAnswers;
    int? submittedSelfRating;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityLatestInfoTaskCard(
              onSubmit: ({required correctAnswers, required selfRating}) async {
                submittedCorrectAnswers = correctAnswers;
                submittedSelfRating = selfRating;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tapVisible(tester, find.byKey(const Key('latest-info-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('latest-info-q1-o1')));
    await tapVisible(tester, find.byKey(const Key('latest-info-q2-o0')));
    await tapVisible(
      tester,
      find.byKey(const Key('latest-info-summary-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('latest-info-rating-5')));
    await tapVisible(tester, find.byKey(const Key('latest-info-submit')));
    await tester.pumpAndSettle();

    expect(submittedCorrectAnswers, 2);
    expect(submittedSelfRating, 5);
    expect(
      find.byKey(const Key('latest-info-submitted-result')),
      findsOneWidget,
    );
    expect(find.text('送信済み: 2 / 3 問正解'), findsOneWidget);
  });
}

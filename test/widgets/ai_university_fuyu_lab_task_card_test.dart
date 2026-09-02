import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_fuyu_lab_analytics.dart';
import 'package:my_web_app/widgets/ai_university_fuyu_lab_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('records nothing before an explicit start', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityFuyuLabTaskCard(
              onStart: () async {
                starts += 1;
                return true;
              },
              onSubmit: (_) async => true,
            ),
          ),
        ),
      ),
    );

    expect(starts, 0);
    expect(find.byKey(const Key('fuyu-lab-submit')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('fuyu-lab-start')));

    expect(starts, 1);
    expect(find.byKey(const Key('fuyu-lab-submit')), findsOneWidget);
  });

  testWidgets('submits finite outcome, elapsed time, and rubric only', (
    tester,
  ) async {
    AiUniversityFuyuLabCompletion? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityFuyuLabTaskCard(
              onStart: () async => true,
              onSubmit: (completion) async {
                submitted = completion;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tapVisible(tester, find.byKey(const Key('fuyu-lab-start')));
    await tapVisible(
      tester,
      find.byKey(const Key('fuyu-lab-outcome-success_after_error')),
    );
    for (var index = 0; index < 4; index++) {
      await tapVisible(tester, find.byKey(Key('fuyu-lab-rubric-$index')));
    }
    await tapVisible(tester, find.byKey(const Key('fuyu-lab-submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.attemptOutcome, 'success_after_error');
    expect(submitted!.completionSeconds, greaterThanOrEqualTo(1));
    expect(submitted!.rubricScore, 4);
    expect(find.byKey(const Key('fuyu-lab-submitted')), findsOneWidget);
    expect(find.textContaining('個人情報は送信しません'), findsOneWidget);
  });
}

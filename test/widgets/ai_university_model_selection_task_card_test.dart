import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_model_selection_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('requires comparison, all answers, and self-rating', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityModelSelectionTaskCard(
              onSubmit: ({required correctAnswers, required selfRating}) async {
                return true;
              },
            ),
          ),
        ),
      ),
    );

    final submit = find.byKey(const Key('model-selection-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapVisible(tester, find.byKey(const Key('model-selection-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('model-selection-q1-o1')));
    await tapVisible(tester, find.byKey(const Key('model-selection-q2-o2')));
    await tapVisible(
      tester,
      find.byKey(const Key('model-selection-comparison-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('model-selection-rating-4')));

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
            child: AiUniversityModelSelectionTaskCard(
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

    await tapVisible(tester, find.byKey(const Key('model-selection-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('model-selection-q1-o0')));
    await tapVisible(tester, find.byKey(const Key('model-selection-q2-o2')));
    await tapVisible(
      tester,
      find.byKey(const Key('model-selection-comparison-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('model-selection-rating-5')));
    await tapVisible(tester, find.byKey(const Key('model-selection-submit')));
    await tester.pumpAndSettle();

    expect(submittedCorrectAnswers, 2);
    expect(submittedSelfRating, 5);
    expect(
      find.byKey(const Key('model-selection-submitted-result')),
      findsOneWidget,
    );
    expect(find.text('送信済み: 2 / 3 問正解'), findsOneWidget);
  });
}

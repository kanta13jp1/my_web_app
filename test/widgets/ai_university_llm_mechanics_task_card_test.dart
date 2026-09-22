import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_llm_mechanics_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Widget subject(AiUniversityLlmMechanicsTaskSubmit onSubmit) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityLlmMechanicsTaskCard(onSubmit: onSubmit),
          ),
        ),
      );

  testWidgets('requires the map, three answers, and self-rating', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(({required correctAnswers, required selfRating}) async => true),
    );
    final submit = find.byKey(const Key('llm-mechanics-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapVisible(tester, find.byKey(const Key('llm-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('llm-q1-o0')));
    await tapVisible(tester, find.byKey(const Key('llm-q2-o0')));
    await tapVisible(
      tester,
      find.byKey(const Key('llm-mechanics-map-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('llm-mechanics-rating-4')));

    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('submits only aggregate correctness and self-rating', (
    tester,
  ) async {
    int? correct;
    int? rating;
    await tester.pumpWidget(
      subject(({required correctAnswers, required selfRating}) async {
        correct = correctAnswers;
        rating = selfRating;
        return true;
      }),
    );

    await tapVisible(tester, find.byKey(const Key('llm-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('llm-q1-o1')));
    await tapVisible(tester, find.byKey(const Key('llm-q2-o0')));
    await tapVisible(
      tester,
      find.byKey(const Key('llm-mechanics-map-completed')),
    );
    await tapVisible(tester, find.byKey(const Key('llm-mechanics-rating-5')));
    await tapVisible(tester, find.byKey(const Key('llm-mechanics-submit')));
    await tester.pumpAndSettle();

    expect(correct, 2);
    expect(rating, 5);
    expect(find.text('送信済み: 2 / 3 問正解'), findsOneWidget);
  });
}
